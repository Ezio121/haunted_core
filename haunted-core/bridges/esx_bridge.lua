if not (Config.Bridges and Config.Bridges.esx) then
    return
end

HauntedCore = HauntedCore or {}
local HC = HauntedCore

ESX = ESX or {}
ESX.Players = ESX.Players or {}
ESX.ServerCallbacks = ESX.ServerCallbacks or {}

local function getInventoryItem(source, itemName)
    local items = HC.Inventory.GetItems(source) or {}
    for i = 1, #items do
        local item = items[i]
        if item.name == itemName then
            return item
        end
    end
    return nil
end

local function wrapXPlayer(player)
    if not player then
        return nil
    end

    local xPlayer = {
        source = player.source,
        identifier = player.license,
        name = player.name,
        job = player.job
    }

    function xPlayer.getIdentifier()
        return player.license
    end

    function xPlayer.getName()
        return player.name
    end

    function xPlayer.getMoney()
        return HC.Economy.GetMoney(player.source, "cash")
    end

    function xPlayer.addMoney(amount, reason)
        return HC.Economy.AddMoney(player.source, "cash", amount, reason)
    end

    function xPlayer.removeMoney(amount, reason)
        return HC.Economy.RemoveMoney(player.source, "cash", amount, reason)
    end

    function xPlayer.getAccount(accountName)
        return {
            name = accountName,
            money = HC.Economy.GetMoney(player.source, accountName)
        }
    end

    function xPlayer.addAccountMoney(accountName, amount, reason)
        return HC.Economy.AddMoney(player.source, accountName, amount, reason)
    end

    function xPlayer.removeAccountMoney(accountName, amount, reason)
        return HC.Economy.RemoveMoney(player.source, accountName, amount, reason)
    end

    function xPlayer.setAccountMoney(accountName, amount, reason)
        local current = HC.Economy.GetMoney(player.source, accountName)
        if amount > current then
            return HC.Economy.AddMoney(player.source, accountName, amount - current, reason)
        elseif amount < current then
            return HC.Economy.RemoveMoney(player.source, accountName, current - amount, reason)
        end
        return true
    end

    function xPlayer.getInventoryItem(itemName)
        local item = getInventoryItem(player.source, itemName)
        return {
            name = itemName,
            count = item and item.count or 0
        }
    end

    function xPlayer.addInventoryItem(itemName, count, metadata)
        return HC.Inventory.AddItem(player.source, itemName, count, metadata or {})
    end

    function xPlayer.removeInventoryItem(itemName, count, metadata)
        return HC.Inventory.RemoveItem(player.source, itemName, count, metadata or {})
    end

    function xPlayer.canCarryItem(itemName, count)
        local hasItem, existingCount = HC.Inventory.HasItem(player.source, itemName, 1, {})
        local maxStack = Config.Inventory.maxStack or 9999
        local total = (hasItem and existingCount or 0) + (tonumber(count) or 0)
        return total <= maxStack
    end

    function xPlayer.setJob(name, grade, onDuty)
        player:SetJob(name, grade)
        xPlayer.job = player.job
        return true
    end

    function xPlayer.setMeta(key, value)
        player.metadata[key] = value
        return true
    end

    function xPlayer.getMeta(key)
        return player.metadata[key]
    end

    function xPlayer.showNotification(text)
        TriggerClientEvent("chat:addMessage", player.source, {
            color = { 255, 255, 255 },
            args = { "[ESX]", tostring(text) }
        })
    end

    return xPlayer
end

function ESX.GetPlayerFromId(source)
    local player = HC.PlayerManager.GetPlayer(source)
    return wrapXPlayer(player)
end

function ESX.GetPlayerFromIdentifier(identifier)
    local player = HC.PlayerManager.GetPlayerByLicense(identifier)
    return wrapXPlayer(player)
end

function ESX.RegisterServerCallback(name, cb)
    ESX.ServerCallbacks[name] = cb
end

function ESX.TriggerServerCallback(name, source, cb, ...)
    local callback = ESX.ServerCallbacks[name]
    if not callback then
        return
    end
    callback(source, cb, ...)
end

RegisterNetEvent("esx:triggerServerCallback", function(name, requestId, ...)
    local src = source
    local cb = ESX.ServerCallbacks[name]
    if not cb then
        TriggerClientEvent("esx:serverCallback", src, requestId, nil)
        return
    end

    cb(src, function(...)
        TriggerClientEvent("esx:serverCallback", src, requestId, ...)
    end, ...)
end)

exports("getSharedObject", function()
    return ESX
end)

AddEventHandler("esx:getSharedObject", function(cb)
    if type(cb) == "function" then
        cb(ESX)
    end
end)
