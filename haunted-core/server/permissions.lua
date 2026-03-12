HauntedCore = HauntedCore or {}
HauntedCore.Permissions = HauntedCore.Permissions or {}

local HC = HauntedCore
local Permissions = HC.Permissions

local weight = {}
for rank, value in pairs((Config.Permissions and Config.Permissions.hierarchy) or {}) do
    weight[string.lower(rank)] = tonumber(value) or 0
end

local function normalize(permission)
    if type(permission) ~= "string" then
        return "player"
    end
    return string.lower(permission)
end

local function syncStateBag(source, permission)
    local playerRef = Player(source)
    if playerRef then
        playerRef.state:set("permission", permission, true)
    end
end

local function getPlayerPermissionData(source)
    local player = HC.PlayerManager.GetPlayer(source)
    if not player then
        return nil, nil
    end

    player.permissions = player.permissions or {}
    player.permissions.list = player.permissions.list or {}
    player.permissions.primary = normalize(player.permissions.primary or "player")
    player.permissions.list.player = true

    return player, player.permissions
end

function Permissions.Init()
    return true
end

function Permissions.GetPrimary(source)
    local player = HC.PlayerManager.GetPlayer(source)
    if not player or not player.permissions then
        return "player"
    end
    return normalize(player.permissions.primary)
end

function Permissions.HasPermission(source, requiredPermission)
    local required = normalize(requiredPermission)
    if required == "player" then
        return true
    end

    local player, perms = getPlayerPermissionData(source)
    if not player then
        return false
    end

    if perms.list[required] then
        return true
    end

    local playerWeight = weight[perms.primary] or 0
    local requiredWeight = weight[required] or math.huge
    return playerWeight >= requiredWeight
end

function Permissions.AddPermission(source, permission)
    local normalized = normalize(permission)
    local player, perms = getPlayerPermissionData(source)
    if not player then
        return false, "player_not_found"
    end

    perms.list[normalized] = true

    local currentWeight = weight[perms.primary] or 0
    local newWeight = weight[normalized] or 0
    if newWeight > currentWeight then
        perms.primary = normalized
    end

    syncStateBag(player.source, perms.primary)
    HC.Events.Emit("permission:added", source, normalized)
    return true
end

function Permissions.RemovePermission(source, permission)
    local normalized = normalize(permission)
    if normalized == "player" then
        return false, "base_permission_locked"
    end

    local player, perms = getPlayerPermissionData(source)
    if not player then
        return false, "player_not_found"
    end

    perms.list[normalized] = nil

    if perms.primary == normalized then
        local best = "player"
        local bestWeight = weight[best] or 0
        for rank, enabled in pairs(perms.list) do
            if enabled then
                local rankWeight = weight[rank] or 0
                if rankWeight > bestWeight then
                    best = rank
                    bestWeight = rankWeight
                end
            end
        end
        perms.primary = best
    end

    syncStateBag(player.source, perms.primary)
    HC.Events.Emit("permission:removed", source, normalized)
    return true
end
