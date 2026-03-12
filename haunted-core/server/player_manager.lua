HauntedCore = HauntedCore or {}
HauntedCore.PlayerManager = HauntedCore.PlayerManager or {}

local HC = HauntedCore
local PlayerManager = HC.PlayerManager
local Utils = HC.Utils
local Constants = HC.Constants

local playersBySource = {}
local playersByCitizenId = {}
local playersByIdentifier = {}

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
        if type(key) ~= "string" or key == "" then
            return
        end
        self:EnsureMetadataLoaded()
        self.metadata[key] = value
        self._dirty.metadata = true
    end

    function player:GetMetaData(key)
        self:EnsureMetadataLoaded()
        return self.metadata[key]
    end

    function player:EnsureMetadataLoaded()
        if self._extendedMetadataLoaded then
            return
        end

        local row = HC.DB.single("SELECT metadata FROM player_metadata WHERE citizenid = ? LIMIT 1", { self.citizenid })
        if row and row.metadata then
            local decoded = Utils.SafeJsonDecode(row.metadata, {})
            for k, v in pairs(decoded) do
                if self.metadata[k] == nil then
                    self.metadata[k] = v
                end
            end
        end

        self._extendedMetadataLoaded = true
    end

    function player:SetJob(jobName, grade, label)
        self.job = {
            name = tostring(jobName or "unemployed"),
            grade = tonumber(grade) or 0,
            label = tostring(label or jobName or "Unemployed")
        }
        self._dirty.user = true
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

local function splitName(fullName)
    local safe = tostring(fullName or "Unknown Person")
    local first, last = safe:match("^(%S+)%s+(.+)$")
    if not first then
        return safe, "Unknown"
    end
    return first, last
end

local function sanitizePosition(position)
    if type(position) ~= "table" then
        return nil
    end
    return {
        x = tonumber(position.x) or 0.0,
        y = tonumber(position.y) or 0.0,
        z = tonumber(position.z) or 0.0,
        heading = tonumber(position.heading) or 0.0
    }
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

local function ensureDefaultsInDatabase(citizenId, identifier, defaults)
    HC.DB.execute(
        "INSERT INTO player_accounts (citizenid, cash, bank, spirit_energy) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP",
        {
            citizenId,
            defaults.accounts.cash,
            defaults.accounts.bank,
            defaults.accounts.spirit_energy
        }
    )

    HC.DB.execute(
        "INSERT INTO player_inventory (citizenid, inventory) VALUES (?, ?) ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP",
        { citizenId, Utils.SafeJsonEncode(defaults.inventory, "[]") }
    )

    HC.DB.execute(
        "INSERT INTO player_metadata (citizenid, metadata) VALUES (?, ?) ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP",
        { citizenId, Utils.SafeJsonEncode(defaults.metadata, "{}") }
    )

    HC.DB.execute(
        "INSERT INTO ghost_states (citizenid, state, spirit_energy, haunt_level, possession_state) VALUES (?, ?, ?, 0, '{}') ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP",
        { citizenId, defaults.ghostState, defaults.accounts.spirit_energy }
    )

    HC.DB.execute(
        "INSERT IGNORE INTO player_permissions (identifier, permission, granted_by) VALUES (?, 'player', 'system')",
        { identifier }
    )
end

local function loadPlayerFromDatabase(source, identifier, license)
    if not HC.DB.BackendAvailable() then
        local playerName = GetPlayerName(source) or ("Player %s"):format(source)
        return {
            source = source,
            identifier = identifier,
            citizenid = Utils.CreateCitizenId(identifier),
            license = license,
            name = playerName,
            job = {
                name = "unemployed",
                grade = 0,
                label = "Unemployed"
            },
            inventory = {},
            permissions = normalizePermissions(),
            ghost_state = Constants.GHOST_STATES.ALIVE,
            metadata = {},
            accounts = Utils.DeepCopy(Config.Economy.startingAccounts),
            position = nil,
            _extendedMetadataLoaded = true,
            _dirty = {
                user = false,
                inventory = false,
                accounts = false,
                metadata = false,
                permissions = false,
                ghost = false
            }
        }, nil
    end

    local user = HC.DB.single("SELECT * FROM users WHERE license = ? LIMIT 1", { license })
    local playerName = GetPlayerName(source) or ("Player %s"):format(source)
    local firstName, lastName = splitName(playerName)

    if not user then
        local citizenId = Utils.CreateCitizenId(license)
        local defaultPosition = Utils.SafeJsonEncode({ x = 0.0, y = 0.0, z = 71.0, heading = 0.0 }, "{}")
        local defaultMeta = Utils.SafeJsonEncode({}, "{}")
        HC.DB.insert([[
            INSERT INTO users (
                license, citizenid, charname, firstname, lastname, dateofbirth, sex, nationality, phone,
                job, job_grade, `group`, position, metadata, last_seen
            ) VALUES (?, ?, ?, ?, ?, '1970-01-01', 'U', 'Unknown', '', ?, ?, ?, ?, ?, NOW())
        ]], {
            license,
            citizenId,
            playerName,
            firstName,
            lastName,
            "unemployed",
            0,
            "none",
            defaultPosition,
            defaultMeta
        })
        user = HC.DB.single("SELECT * FROM users WHERE license = ? LIMIT 1", { license })
    end

    if not user then
        return nil, "failed_to_load_user"
    end

    local accountsRow = HC.DB.single("SELECT cash, bank, spirit_energy FROM player_accounts WHERE citizenid = ? LIMIT 1", { user.citizenid })
    local inventoryRow = HC.DB.single("SELECT inventory FROM player_inventory WHERE citizenid = ? LIMIT 1", { user.citizenid })
    local metadataRow = HC.DB.single("SELECT metadata FROM player_metadata WHERE citizenid = ? LIMIT 1", { user.citizenid })
    local permissionsRows = HC.DB.query("SELECT permission FROM player_permissions WHERE identifier = ?", { identifier })
    local ghostRow = HC.DB.single("SELECT state, spirit_energy, haunt_level, possession_state FROM ghost_states WHERE citizenid = ? LIMIT 1", { user.citizenid })

    local defaults = {
        accounts = Utils.DeepCopy(Config.Economy.startingAccounts),
        inventory = {},
        metadata = {},
        ghostState = Constants.GHOST_STATES.ALIVE
    }
    ensureDefaultsInDatabase(user.citizenid, identifier, defaults)

    local accounts = {
        cash = tonumber(accountsRow and accountsRow.cash) or defaults.accounts.cash or 0,
        bank = tonumber(accountsRow and accountsRow.bank) or defaults.accounts.bank or 0,
        spirit_energy = tonumber(accountsRow and accountsRow.spirit_energy) or defaults.accounts.spirit_energy or 0
    }

    local inventory = Utils.SafeJsonDecode(inventoryRow and inventoryRow.inventory or "[]", {})
    if type(inventory) ~= "table" then
        inventory = {}
    end

    local metadata = Utils.SafeJsonDecode(user.metadata or "{}", {})
    if metadataRow and metadataRow.metadata then
        local extended = Utils.SafeJsonDecode(metadataRow.metadata, {})
        for k, v in pairs(extended) do
            metadata[k] = v
        end
    end

    local permissions = normalizePermissions({
        primary = Constants.PERMISSIONS.PLAYER,
        list = { [Constants.PERMISSIONS.PLAYER] = true }
    })
    for i = 1, #(permissionsRows or {}) do
        local perm = tostring(permissionsRows[i].permission or ""):lower()
        if perm ~= "" then
            permissions.list[perm] = true
            if (Config.Permissions.hierarchy[perm] or 0) > (Config.Permissions.hierarchy[permissions.primary] or 0) then
                permissions.primary = perm
            end
        end
    end

    local ghostState = Constants.GHOST_STATES.ALIVE
    if ghostRow and ghostRow.state == Constants.GHOST_STATES.GHOST then
        ghostState = Constants.GHOST_STATES.GHOST
    end

    local position = Utils.SafeJsonDecode(user.position or "{}", nil)

    return {
        source = source,
        identifier = identifier,
        citizenid = user.citizenid,
        license = user.license,
        name = user.charname or playerName,
        job = {
            name = user.job or "unemployed",
            grade = tonumber(user.job_grade) or 0,
            label = user.job or "Unemployed"
        },
        inventory = inventory,
        permissions = permissions,
        ghost_state = ghostState,
        metadata = metadata,
        accounts = accounts,
        position = sanitizePosition(position),
        _extendedMetadataLoaded = true,
        _dirty = {
            user = false,
            inventory = false,
            accounts = false,
            metadata = false,
            permissions = false,
            ghost = false
        }
    }, nil
end

local function buildPermissionRows(identifier, permissions)
    local rows = {}
    permissions = permissions or {}
    for permission, enabled in pairs(permissions.list or {}) do
        if enabled then
            rows[#rows + 1] = {
                query = "INSERT IGNORE INTO player_permissions (identifier, permission, granted_by) VALUES (?, ?, ?)",
                params = { identifier, permission, "system" }
            }
        end
    end
    return rows
end

function PlayerManager.GetPlayer(source)
    return playersBySource[tonumber(source or 0)]
end

function PlayerManager.GetPlayerByCitizenId(citizenId)
    return playersByCitizenId[tostring(citizenId or "")]
end

function PlayerManager.GetPlayerByLicense(license)
    return playersByIdentifier[tostring(license or "")]
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

    local identifier = Utils.GetIdentifierByPriority(source)
    local license = Utils.GetIdentifierByType(source, "license") or identifier
    local player, err = loadPlayerFromDatabase(source, identifier, license)
    if not player then
        return nil, err
    end

    hydratePlayerMethods(player)

    playersBySource[source] = player
    playersByCitizenId[player.citizenid] = player
    playersByIdentifier[player.license] = player

    applyStateBags(player)
    HC.DB.update("UPDATE users SET last_seen = NOW() WHERE citizenid = ?", { player.citizenid })
    HC.Events.Emit("player:created", source, player)

    return player
end

local function savePlayerPosition(player)
    local ped = GetPlayerPed(player.source)
    if ped and ped ~= 0 then
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        player.position = {
            x = coords.x,
            y = coords.y,
            z = coords.z,
            heading = heading
        }
    end
end

function PlayerManager.SavePlayer(source)
    local player = PlayerManager.GetPlayer(source)
    if not player then
        return false, "not_found"
    end

    if not HC.DB.BackendAvailable() then
        return true
    end

    savePlayerPosition(player)
    player:EnsureMetadataLoaded()

    local userMetaJson = Utils.SafeJsonEncode(player.metadata, "{}")
    local inventoryJson = Utils.SafeJsonEncode(player.inventory or {}, "[]")
    local positionJson = Utils.SafeJsonEncode(player.position or {}, "{}")
    local metadataJson = Utils.SafeJsonEncode(player.metadata or {}, "{}")
    local ghostPossession = Utils.SafeJsonEncode({}, "{}")

    local queries = {
        {
            query = [[
                UPDATE users
                SET charname = ?, job = ?, job_grade = ?, `group` = ?, position = ?, metadata = ?, last_seen = NOW(), updated_at = NOW()
                WHERE citizenid = ?
            ]],
            params = {
                player.name,
                player.job.name,
                player.job.grade,
                player.metadata.group or "none",
                positionJson,
                userMetaJson,
                player.citizenid
            }
        },
        {
            query = [[
                INSERT INTO player_accounts (citizenid, cash, bank, spirit_energy)
                VALUES (?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE cash = VALUES(cash), bank = VALUES(bank), spirit_energy = VALUES(spirit_energy), updated_at = CURRENT_TIMESTAMP
            ]],
            params = {
                player.citizenid,
                player.accounts.cash or 0,
                player.accounts.bank or 0,
                player.accounts.spirit_energy or 0
            }
        },
        {
            query = [[
                INSERT INTO player_inventory (citizenid, inventory)
                VALUES (?, ?)
                ON DUPLICATE KEY UPDATE inventory = VALUES(inventory), updated_at = CURRENT_TIMESTAMP
            ]],
            params = { player.citizenid, inventoryJson }
        },
        {
            query = [[
                INSERT INTO player_metadata (citizenid, metadata)
                VALUES (?, ?)
                ON DUPLICATE KEY UPDATE metadata = VALUES(metadata), updated_at = CURRENT_TIMESTAMP
            ]],
            params = { player.citizenid, metadataJson }
        },
        {
            query = [[
                INSERT INTO ghost_states (citizenid, state, spirit_energy, haunt_level, possession_state)
                VALUES (?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE state = VALUES(state), spirit_energy = VALUES(spirit_energy), haunt_level = VALUES(haunt_level),
                possession_state = VALUES(possession_state), updated_at = CURRENT_TIMESTAMP
            ]],
            params = {
                player.citizenid,
                player.ghost_state,
                player.accounts.spirit_energy or 0,
                tonumber(player.metadata.haunt_level) or 0,
                ghostPossession
            }
        },
        {
            query = "DELETE FROM player_permissions WHERE identifier = ?",
            params = { player.identifier }
        }
    }

    local permissionRows = buildPermissionRows(player.identifier, player.permissions)
    for i = 1, #permissionRows do
        queries[#queries + 1] = permissionRows[i]
    end

    local success = false
    if Config.Database and Config.Database.UseTransactions then
        success = HC.DB.transaction(queries)
    else
        success = true
        for i = 1, #queries do
            local result = HC.DB.execute(queries[i].query, queries[i].params)
            if result == nil then
                success = false
                break
            end
        end
    end

    if not success then
        return false, "save_failed"
    end

    player._dirty.user = false
    player._dirty.inventory = false
    player._dirty.accounts = false
    player._dirty.metadata = false
    player._dirty.permissions = false
    player._dirty.ghost = false

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
        playersByIdentifier[player.license] = nil
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
