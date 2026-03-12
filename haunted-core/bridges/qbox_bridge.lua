if not (Config.Bridges and Config.Bridges.qbox) then
    return
end

HauntedCore = HauntedCore or {}
local HC = HauntedCore

QBox = QBox or {}
QBox.Functions = QBox.Functions or {}
QBox.Players = QBox.Players or {}
QBX = QBX or QBox

local callbacks = {}

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
            items = player.inventory,
            metadata = player.metadata
        }
    }

    function wrapped.AddMoney(account, amount, reason)
        return HC.Economy.AddMoney(player.source, account, amount, reason)
    end

    function wrapped.RemoveMoney(account, amount, reason)
        return HC.Economy.RemoveMoney(player.source, account, amount, reason)
    end

    function wrapped.GetMoney(account)
        return HC.Economy.GetMoney(player.source, account)
    end

    function wrapped.AddItem(name, count, metadata)
        return HC.Inventory.AddItem(player.source, name, count, metadata or {})
    end

    function wrapped.RemoveItem(name, count, metadata)
        return HC.Inventory.RemoveItem(player.source, name, count, metadata or {})
    end

    function wrapped.HasPermission(permission)
        return HC.Permissions.HasPermission(player.source, permission)
    end

    return wrapped
end

function QBox.Player(source)
    local player = HC.PlayerManager.GetPlayer(source)
    return wrapPlayer(player)
end

function QBox.Functions.GetPlayer(source)
    local player = HC.PlayerManager.GetPlayer(source)
    return wrapPlayer(player)
end

function QBox.Functions.GetPlayerByCitizenId(citizenId)
    local player = HC.PlayerManager.GetPlayerByCitizenId(citizenId)
    return wrapPlayer(player)
end

function QBox.Functions.HasPermission(source, permission)
    return HC.Permissions.HasPermission(source, permission)
end

function QBox.Functions.CreateCallback(name, cb)
    callbacks[name] = cb
end

RegisterNetEvent("qbx_core:server:triggerCallback", function(name, requestId, ...)
    local src = source
    local callback = callbacks[name]
    if not callback then
        TriggerClientEvent("qbx_core:client:callback", src, requestId, nil)
        return
    end

    callback(src, function(...)
        TriggerClientEvent("qbx_core:client:callback", src, requestId, ...)
    end, ...)
end)

exports("GetQBoxObject", function()
    return QBox
end)

AddEventHandler("QBox:GetObject", function(cb)
    if type(cb) == "function" then
        cb(QBox)
    end
end)
