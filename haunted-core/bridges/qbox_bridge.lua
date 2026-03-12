if not (Config.Bridges and Config.Bridges.qbox) then
    return
end

HauntedCore = HauntedCore or {}
local HC = HauntedCore

QBox = QBox or {}
QBox.Functions = QBox.Functions or {}
QBox.Players = QBox.Players or {}
QBox.ServerCallbacks = QBox.ServerCallbacks or {}
QBX = QBX or QBox

local usableItems = {}

local function wrapPlayer(player)
    if not player then
        return nil
    end

    local wrapped = {
        source = player.source,
        PlayerData = {
            source = player.source,
            citizenid = player.citizenid,
            license = player.license,
            name = player.name,
            job = player.job,
            money = player.accounts,
            metadata = player.metadata,
            items = player.inventory
        }
    }

    function wrapped.GetMoney(account)
        return HC.Economy.GetMoney(player.source, account)
    end

    function wrapped.AddMoney(account, amount, reason)
        return HC.Economy.AddMoney(player.source, account, amount, reason)
    end

    function wrapped.RemoveMoney(account, amount, reason)
        return HC.Economy.RemoveMoney(player.source, account, amount, reason)
    end

    function wrapped.SetMoney(account, amount, reason)
        return HC.Economy.SetMoney(player.source, account, amount, reason)
    end

    function wrapped.AddItem(itemName, count, metadata)
        return HC.Inventory.AddItem(player.source, itemName, count, metadata or {})
    end

    function wrapped.RemoveItem(itemName, count, metadata)
        return HC.Inventory.RemoveItem(player.source, itemName, count, metadata or {})
    end

    function wrapped.HasPermission(permission)
        return HC.Permissions.HasPermission(player.source, permission)
    end

    return wrapped
end

function QBox.Player(source)
    return wrapPlayer(HC.PlayerManager.GetPlayer(source))
end

function QBox.Functions.GetPlayer(source)
    return wrapPlayer(HC.PlayerManager.GetPlayer(source))
end

function QBox.Functions.GetPlayerByCitizenId(citizenId)
    return wrapPlayer(HC.PlayerManager.GetPlayerByCitizenId(citizenId))
end

function QBox.Functions.GetPlayers()
    local players = GetPlayers()
    local out = {}
    for i = 1, #players do
        out[i] = tonumber(players[i])
    end
    return out
end

function QBox.Functions.HasPermission(source, permission)
    return HC.Permissions.HasPermission(source, permission)
end

function QBox.Functions.CreateCallback(name, callback)
    QBox.ServerCallbacks[name] = callback
end

function QBox.Functions.TriggerCallback(name, source, callback, ...)
    local handler = QBox.ServerCallbacks[name]
    if handler then
        handler(source, callback, ...)
    end
end

function QBox.Functions.CreateUseableItem(itemName, callback)
    usableItems[itemName] = callback
end

function QBox.Functions.UseItem(source, itemName, ...)
    local callback = usableItems[itemName]
    if callback then
        callback(source, itemName, ...)
        return true
    end
    return false
end

RegisterNetEvent("qbx_core:server:triggerCallback", function(name, requestId, ...)
    local source = source
    local callback = QBox.ServerCallbacks[name]
    if not callback then
        TriggerClientEvent("qbx_core:client:callback", source, requestId, nil)
        return
    end

    callback(source, function(...)
        TriggerClientEvent("qbx_core:client:callback", source, requestId, ...)
    end, ...)
end)

exports("GetQBoxObject", function()
    return QBox
end)
