if not (Config.Bridges and Config.Bridges.qbcore) then
    return
end

HauntedCore = HauntedCore or {}
local HC = HauntedCore

QBCore = QBCore or {}
QBCore.Config = QBCore.Config or {}
QBCore.Functions = QBCore.Functions or {}
QBCore.Players = QBCore.Players or {}

local callbacks = {}

local function buildPlayerData(player)
    return {
        source = player.source,
        citizenid = player.citizenid,
        license = player.license,
        name = player.name,
        job = player.job,
        metadata = player.metadata,
        money = player.accounts,
        items = player.inventory
    }
end

local function wrapPlayer(player)
    if not player then
        return nil
    end

    local wrapped = {}
    wrapped.PlayerData = buildPlayerData(player)
    wrapped.Functions = {}

    function wrapped.Functions.UpdatePlayerData()
        wrapped.PlayerData = buildPlayerData(player)
        return wrapped.PlayerData
    end

    function wrapped.Functions.AddMoney(account, amount, reason)
        return HC.Economy.AddMoney(player.source, account, amount, reason)
    end

    function wrapped.Functions.RemoveMoney(account, amount, reason)
        return HC.Economy.RemoveMoney(player.source, account, amount, reason)
    end

    function wrapped.Functions.GetMoney(account)
        return HC.Economy.GetMoney(player.source, account)
    end

    function wrapped.Functions.AddItem(name, count, slot, metadata)
        return HC.Inventory.AddItem(player.source, name, count, metadata or {})
    end

    function wrapped.Functions.RemoveItem(name, count, slot, metadata)
        return HC.Inventory.RemoveItem(player.source, name, count, metadata or {})
    end

    function wrapped.Functions.GetItemByName(name)
        local items = HC.Inventory.GetItems(player.source) or {}
        for i = 1, #items do
            if items[i].name == name then
                return items[i]
            end
        end
        return nil
    end

    function wrapped.Functions.SetMetaData(key, value)
        player.metadata[key] = value
        return true
    end

    function wrapped.Functions.GetMetaData(key)
        return player.metadata[key]
    end

    function wrapped.Functions.SetJob(name, grade)
        player:SetJob(name, grade)
        wrapped.Functions.UpdatePlayerData()
        return true
    end

    return wrapped
end

function QBCore.Functions.GetPlayer(source)
    local player = HC.PlayerManager.GetPlayer(source)
    return wrapPlayer(player)
end

function QBCore.Functions.GetPlayerByCitizenId(citizenId)
    local player = HC.PlayerManager.GetPlayerByCitizenId(citizenId)
    return wrapPlayer(player)
end

function QBCore.Functions.GetPlayers()
    local players = GetPlayers()
    local out = {}
    for i = 1, #players do
        out[i] = tonumber(players[i])
    end
    return out
end

function QBCore.Functions.HasPermission(source, permission)
    return HC.Permissions.HasPermission(source, permission)
end

function QBCore.Functions.GetPermission(source)
    return HC.Permissions.GetPrimary(source)
end

function QBCore.Functions.CreateCallback(name, cb)
    callbacks[name] = cb
end

function QBCore.Functions.TriggerCallback(name, source, cb, ...)
    local callback = callbacks[name]
    if not callback then
        return
    end
    callback(source, cb, ...)
end

RegisterNetEvent("QBCore:Server:TriggerCallback", function(name, requestId, ...)
    local src = source
    local callback = callbacks[name]
    if not callback then
        TriggerClientEvent("QBCore:Client:TriggerCallback", src, requestId, nil)
        return
    end

    callback(src, function(...)
        TriggerClientEvent("QBCore:Client:TriggerCallback", src, requestId, ...)
    end, ...)
end)

exports("GetCoreObject", function()
    return QBCore
end)

AddEventHandler("QBCore:GetObject", function(cb)
    if type(cb) == "function" then
        cb(QBCore)
    end
end)
