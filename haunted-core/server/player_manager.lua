HauntedCore = HauntedCore or {}
HauntedCore.PlayerManager = HauntedCore.PlayerManager or {}

local HC = HauntedCore
local PlayerManager = HC.PlayerManager
local Utils = HC.Utils
local Constants = HC.Constants

local playersBySource = {}
local playersByCitizenId = {}
local playersByLicense = {}

local function storageKey(identifier)
    return ("haunted:player:%s"):format(identifier)
end

local function normalizePermissions(permissions)
    local perms = permissions or {}
    perms.primary = perms.primary or Constants.PERMISSIONS.PLAYER
    perms.list = perms.list or {}
    perms.list[Constants.PERMISSIONS.PLAYER] = true
    perms.list[perms.primary] = true
    return perms
end

local function hydratePlayerMethods(player)
    if player.__hydrated then
        return player
    end

    player.__hydrated = true

    function player:GetData()
        return self
    end

    function player:SetMetaData(key, value)
        self.metadata[key] = value
    end

    function player:GetMetaData(key)
        return self.metadata[key]
    end

    function player:SetJob(jobName, grade, label)
        self.job = {
            name = tostring(jobName or "unemployed"),
            grade = tonumber(grade) or 0,
            label = tostring(label or jobName or "Unemployed")
        }
    end

    function player:AddMoney(account, amount, reason)
        return HC.Economy.AddMoney(self.source, account, amount, reason)
    end

    function player:RemoveMoney(account, amount, reason)
        return HC.Economy.RemoveMoney(self.source, account, amount, reason)
    end

    function player:GetMoney(account)
        return HC.Economy.GetMoney(self.source, account)
    end

    function player:AddItem(name, count, metadata)
        return HC.Inventory.AddItem(self.source, name, count, metadata)
    end

    function player:RemoveItem(name, count, metadata)
        return HC.Inventory.RemoveItem(self.source, name, count, metadata)
    end

    function player:HasItem(name, count, metadata)
        return HC.Inventory.HasItem(self.source, name, count, metadata)
    end

    function player:HasPermission(permission)
        return HC.Permissions.HasPermission(self.source, permission)
    end

    return player
end

local function buildSnapshot(player)
    return {
        identifier = player.identifier,
        citizenid = player.citizenid,
        license = player.license,
        name = player.name,
        job = Utils.DeepCopy(player.job),
        inventory = Utils.DeepCopy(player.inventory),
        permissions = Utils.DeepCopy(player.permissions),
        ghost_state = player.ghost_state,
        metadata = Utils.DeepCopy(player.metadata),
        accounts = Utils.DeepCopy(player.accounts)
    }
end

local function persistPlayer(player)
    local snapshot = buildSnapshot(player)
    SetResourceKvp(storageKey(player.identifier), json.encode(snapshot))
end

local function loadStoredPlayer(identifier)
    local raw = GetResourceKvpString(storageKey(identifier))
    return Utils.SafeJsonDecode(raw, nil)
end

local function applyStateBags(player)
    local playerRef = Player(player.source)
    if not playerRef then
        return
    end

    playerRef.state:set("citizenid", player.citizenid, true)
    playerRef.state:set("ghostState", player.ghost_state, true)
    playerRef.state:set("permission", player.permissions.primary, true)
end

function PlayerManager.GetPlayer(source)
    return playersBySource[tonumber(source or 0)]
end

function PlayerManager.GetPlayerByCitizenId(citizenId)
    return playersByCitizenId[tostring(citizenId or "")]
end

function PlayerManager.GetPlayerByLicense(license)
    return playersByLicense[tostring(license or "")]
end

function PlayerManager.GetAllPlayers()
    return playersBySource
end

function PlayerManager.CreatePlayer(source)
    source = tonumber(source or 0)
    if source <= 0 then
        return nil, "invalid_source"
    end

    local existing = playersBySource[source]
    if existing then
        return existing
    end

    local identifier = Utils.GetPrimaryIdentifier(source)
    local license = Utils.GetIdentifierByType(source, "license") or identifier
    local stored = loadStoredPlayer(identifier)
    local state = Constants.GHOST_STATES.ALIVE

    if stored and stored.ghost_state == Constants.GHOST_STATES.GHOST then
        state = Constants.GHOST_STATES.GHOST
    elseif Config.Ghost and Config.Ghost.defaultState == Constants.GHOST_STATES.GHOST then
        state = Constants.GHOST_STATES.GHOST
    end

    local player = {
        source = source,
        identifier = identifier,
        citizenid = stored and stored.citizenid or Utils.CreateCitizenId(identifier),
        license = stored and stored.license or license,
        name = stored and stored.name or (GetPlayerName(source) or ("Player %s"):format(source)),
        job = stored and stored.job or {
            name = "unemployed",
            grade = 0,
            label = "Unemployed"
        },
        inventory = stored and stored.inventory or {},
        permissions = normalizePermissions(stored and stored.permissions or nil),
        ghost_state = state,
        metadata = stored and stored.metadata or {},
        accounts = stored and stored.accounts or Utils.DeepCopy(Config.Economy.startingAccounts)
    }

    player.metadata.lastJoin = os.time()
    player.metadata.lastSeen = os.time()

    hydratePlayerMethods(player)

    playersBySource[source] = player
    playersByCitizenId[player.citizenid] = player
    playersByLicense[player.license] = player

    applyStateBags(player)
    HC.Events.Emit("player:created", source, player)

    return player
end

function PlayerManager.SavePlayer(source)
    local player = PlayerManager.GetPlayer(source)
    if not player then
        return false, "not_found"
    end

    player.metadata.lastSeen = os.time()
    persistPlayer(player)
    return true
end

function PlayerManager.DropPlayer(source, reason)
    source = tonumber(source or 0)
    if source <= 0 then
        return false, "invalid_source"
    end

    local player = PlayerManager.GetPlayer(source)
    if player then
        PlayerManager.SavePlayer(source)
        playersBySource[source] = nil
        playersByCitizenId[player.citizenid] = nil
        playersByLicense[player.license] = nil
    end

    if HC.EventSecurity and HC.EventSecurity.InvalidateToken then
        HC.EventSecurity.InvalidateToken(source)
    end

    HC.Events.Emit("player:dropped", source, player, reason)

    if reason and GetPlayerPing(source) > 0 then
        _G.DropPlayer(source, tostring(reason))
    end

    return true
end
