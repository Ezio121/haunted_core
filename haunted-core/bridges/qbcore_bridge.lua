if not (Config.Bridges and Config.Bridges.qbcore) then
    return
end

HauntedCore = HauntedCore or {}
local HC = HauntedCore

QBCore = QBCore or {}
QBCore.Config = QBCore.Config or {}
QBCore.Shared = QBCore.Shared or {}
QBCore.Functions = QBCore.Functions or {}
QBCore.Commands = QBCore.Commands or {}
QBCore.Players = QBCore.Players or {}

local serverCallbacks = {}
local usableItems = {}

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

local function findFirstItem(items, itemName)
    if type(items) ~= "table" then
        return nil
    end
    for i = 1, #items do
        if items[i].name == itemName then
            return items[i]
        end
    end
    return nil
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

    function wrapped.Functions.SetMoney(account, amount, reason)
        return HC.Economy.SetMoney(player.source, account, amount, reason)
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
        return findFirstItem(HC.Inventory.GetInventory(player.source), name)
    end

    function wrapped.Functions.SetMetaData(key, value)
        player:SetMetaData(key, value)
        return true
    end

    function wrapped.Functions.GetMetaData(key)
        return player:GetMetaData(key)
    end

    function wrapped.Functions.SetJob(name, grade)
        player:SetJob(name, grade)
        return true
    end

    function wrapped.Functions.Notify(message, messageType, duration)
        TriggerClientEvent("chat:addMessage", player.source, {
            color = { 255, 255, 255 },
            args = { "[QBCore]", tostring(message) }
        })
        return true
    end

    return wrapped
end

function QBCore.Functions.GetPlayer(source)
    return wrapPlayer(HC.PlayerManager.GetPlayer(source))
end

function QBCore.Functions.GetPlayerByCitizenId(citizenId)
    return wrapPlayer(HC.PlayerManager.GetPlayerByCitizenId(citizenId))
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

function QBCore.Functions.CreateCallback(name, callback)
    serverCallbacks[name] = callback
end

function QBCore.Functions.TriggerCallback(name, source, callback, ...)
    local handler = serverCallbacks[name]
    if not handler then
        return
    end
    handler(source, callback, ...)
end

function QBCore.Functions.CreateUseableItem(itemName, callback)
    usableItems[itemName] = callback
end

function QBCore.Functions.CanUseItem(itemName)
    return usableItems[itemName] ~= nil
end

function QBCore.Functions.UseItem(source, itemName, ...)
    local callback = usableItems[itemName]
    if type(callback) == "function" then
        callback(source, itemName, ...)
        return true
    end
    return false
end

RegisterNetEvent("QBCore:Server:TriggerCallback", function(name, requestId, ...)
    local source = source
    local callback = serverCallbacks[name]
    if not callback then
        TriggerClientEvent("QBCore:Client:TriggerCallback", source, requestId, nil)
        return
    end

    callback(source, function(...)
        TriggerClientEvent("QBCore:Client:TriggerCallback", source, requestId, ...)
    end, ...)
end)

exports("GetCoreObject", function()
    if QBox then
        QBCore.QBox = QBox
        QBCore.Player = QBox.Player
    end
    return QBCore
end)
