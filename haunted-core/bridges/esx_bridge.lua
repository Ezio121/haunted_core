if not (Config.Bridges and Config.Bridges.esx) then
    return
end

HauntedCore = HauntedCore or {}
local HC = HauntedCore

ESX = ESX or {}
ESX.Players = ESX.Players or {}
ESX.ServerCallbacks = ESX.ServerCallbacks or {}

local usableItems = {}

local function findInventoryItem(source, itemName)
    local items = HC.Inventory.GetInventory(source)
    for i = 1, #items do
        if items[i].name == itemName then
            return items[i]
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

    function xPlayer.setMoney(amount)
        return HC.Economy.SetMoney(player.source, "cash", amount, "esx_set_money")
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
        return HC.Economy.SetMoney(player.source, accountName, amount, reason)
    end

    function xPlayer.getInventoryItem(itemName)
        local item = findInventoryItem(player.source, itemName)
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
        local has, current = HC.Inventory.HasItem(player.source, itemName, 1)
        local total = (has and current or 0) + (tonumber(count) or 0)
        return total <= (Config.Inventory.maxStack or 9999)
    end

    function xPlayer.setJob(name, grade)
        player:SetJob(name, grade)
        xPlayer.job = player.job
        return true
    end

    function xPlayer.showNotification(message)
        TriggerClientEvent("chat:addMessage", player.source, {
            color = { 255, 255, 255 },
            args = { "[ESX]", tostring(message) }
        })
    end

    return xPlayer
end

function ESX.GetPlayerFromId(source)
    return wrapXPlayer(HC.PlayerManager.GetPlayer(source))
end

function ESX.GetPlayerFromIdentifier(identifier)
    return wrapXPlayer(HC.PlayerManager.GetPlayerByLicense(identifier))
end

function ESX.GetExtendedPlayers()
    local list = {}
    local players = HC.PlayerManager.GetAllPlayers()
    for source, player in pairs(players) do
        list[#list + 1] = wrapXPlayer(player)
    end
    return list
end

function ESX.RegisterServerCallback(name, callback)
    ESX.ServerCallbacks[name] = callback
end

function ESX.TriggerServerCallback(name, source, callback, ...)
    local handler = ESX.ServerCallbacks[name]
    if handler then
        handler(source, callback, ...)
    end
end

function ESX.RegisterUsableItem(itemName, callback)
    usableItems[itemName] = callback
end

function ESX.UseItem(source, itemName, ...)
    local callback = usableItems[itemName]
    if callback then
        callback(source, ...)
        return true
    end
    return false
end

RegisterNetEvent("esx:triggerServerCallback", function(name, requestId, ...)
    local source = source
    local callback = ESX.ServerCallbacks[name]
    if not callback then
        TriggerClientEvent("esx:serverCallback", source, requestId, nil)
        return
    end

    callback(source, function(...)
        TriggerClientEvent("esx:serverCallback", source, requestId, ...)
    end, ...)
end)

exports("getSharedObject", function()
    return ESX
end)
