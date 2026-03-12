HauntedCore = HauntedCore or {}
HauntedCore.Inventory = HauntedCore.Inventory or {}

local HC = HauntedCore
local Inventory = HC.Inventory
local Utils = HC.Utils
local Constants = HC.Constants

local maxStack = tonumber(Config.Inventory.maxStack) or 9999
local maxUniqueItems = tonumber(Config.Inventory.maxUniqueItems) or 150
local transactionLock = {}

local function normalizeItemName(itemName)
    if type(itemName) ~= "string" then
        return nil
    end
    local clean = itemName:gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if clean == "" then
        return nil
    end
    return clean
end

local function metadataMatches(a, b)
    return Utils.DeepEqual(a or {}, b or {})
end

local function getInventory(source)
    local player = HC.PlayerManager.GetPlayer(source)
    if not player then
        return nil, "player_not_found"
    end

    player.inventory = player.inventory or {}
    return player.inventory, nil, player
end

local function persistInventory(player)
    local payload = Utils.SafeJsonEncode(player.inventory or {}, "[]")
    return HC.DB.execute(
        [[
            INSERT INTO player_inventory (citizenid, inventory)
            VALUES (?, ?)
            ON DUPLICATE KEY UPDATE inventory = VALUES(inventory), updated_at = CURRENT_TIMESTAMP
        ]],
        { player.citizenid, payload }
    )
end

local function findItemSlot(items, itemName, metadata)
    for i = 1, #items do
        local item = items[i]
        if item.name == itemName and metadataMatches(item.metadata, metadata) then
            return i, item
        end
    end
    return nil, nil
end

local function syncInventory(source, items)
    TriggerClientEvent(Constants.EVENTS.INVENTORY_SYNC, source, items)
    local playerRef = Player(source)
    if playerRef then
        local version = (playerRef.state.inventoryVersion or 0) + 1
        playerRef.state:set("inventoryVersion", version, true)
    end
end

local function acquireLock(source)
    if transactionLock[source] then
        return false
    end
    transactionLock[source] = true
    return true
end

local function releaseLock(source)
    transactionLock[source] = nil
end

function Inventory.Init()
    return true
end

function Inventory.GetItems(source)
    local items = getInventory(source)
    return items
end

function Inventory.GetInventory(source)
    local items = getInventory(source)
    if not items then
        return {}
    end
    return items
end

function Inventory.AddItem(source, itemName, count, metadata)
    source = tonumber(source or 0)
    local cleanName = normalizeItemName(itemName)
    local normalizedCount = Utils.NormalizeCount(count)
    metadata = metadata or {}

    if not cleanName then
        return false, "invalid_item"
    end

    if normalizedCount <= 0 then
        HC.LogAudit("invalid_inventory_mutation", source, nil, {
            action = "add",
            item = cleanName,
            amount = count
        })
        return false, "invalid_count"
    end

    if normalizedCount > maxStack then
        return false, "stack_limit_exceeded"
    end

    if not acquireLock(source) then
        return false, "inventory_busy"
    end

    local items, err = getInventory(source)
    if not items then
        releaseLock(source)
        return false, err
    end

    if HC.AntiExploit and HC.AntiExploit.IsDuplicateAction(source, ("inv_add:%s:%s"):format(cleanName, normalizedCount)) then
        releaseLock(source)
        HC.LogAudit("duplicate_item_anomaly", source, nil, {
            action = "add",
            item = cleanName,
            amount = normalizedCount
        })
        return false, "duplicate_action"
    end

    local idx, existing = findItemSlot(items, cleanName, metadata)
    if existing then
        local newCount = existing.count + normalizedCount
        if newCount > maxStack then
            releaseLock(source)
            return false, "stack_limit_exceeded"
        end
        existing.count = newCount
    else
        if #items >= maxUniqueItems then
            releaseLock(source)
            return false, "inventory_full"
        end
        items[#items + 1] = {
            name = cleanName,
            count = normalizedCount,
            metadata = metadata
        }
    end

    local player = HC.PlayerManager.GetPlayer(source)
    if player then
        player._dirty.inventory = true
        local persisted = persistInventory(player)
        if persisted == nil then
            releaseLock(source)
            return false, "persist_failed"
        end
    end

    syncInventory(source, items)
    releaseLock(source)
    HC.Events.Emit("inventory:changed", source, cleanName, normalizedCount, "add")
    return true
end

function Inventory.RemoveItem(source, itemName, count, metadata)
    source = tonumber(source or 0)
    local cleanName = normalizeItemName(itemName)
    local normalizedCount = Utils.NormalizeCount(count)
    metadata = metadata or {}

    if not cleanName then
        return false, "invalid_item"
    end

    if normalizedCount <= 0 then
        HC.LogAudit("invalid_inventory_mutation", source, nil, {
            action = "remove",
            item = cleanName,
            amount = count
        })
        return false, "invalid_count"
    end

    if not acquireLock(source) then
        return false, "inventory_busy"
    end

    local items, err = getInventory(source)
    if not items then
        releaseLock(source)
        return false, err
    end

    if HC.AntiExploit and HC.AntiExploit.IsDuplicateAction(source, ("inv_remove:%s:%s"):format(cleanName, normalizedCount)) then
        releaseLock(source)
        HC.LogAudit("duplicate_item_anomaly", source, nil, {
            action = "remove",
            item = cleanName,
            amount = normalizedCount
        })
        return false, "duplicate_action"
    end

    local idx, existing = findItemSlot(items, cleanName, metadata)
    if not existing then
        releaseLock(source)
        return false, "item_not_found"
    end

    if existing.count < normalizedCount then
        if HC.AntiExploit then
            HC.AntiExploit.Flag(source, "inventory_underflow_attempt", 20)
        end
        HC.LogAudit("duplicate_item_anomaly", source, nil, {
            action = "underflow",
            item = cleanName,
            requested = normalizedCount,
            available = existing.count
        })
        releaseLock(source)
        return false, "insufficient_items"
    end

    existing.count = existing.count - normalizedCount
    if existing.count <= 0 then
        table.remove(items, idx)
    end

    local player = HC.PlayerManager.GetPlayer(source)
    if player then
        player._dirty.inventory = true
        local persisted = persistInventory(player)
        if persisted == nil then
            releaseLock(source)
            return false, "persist_failed"
        end
    end

    syncInventory(source, items)
    releaseLock(source)
    HC.Events.Emit("inventory:changed", source, cleanName, normalizedCount, "remove")
    return true
end

function Inventory.SetItem(source, itemName, count, metadata)
    source = tonumber(source or 0)
    local cleanName = normalizeItemName(itemName)
    local normalizedCount = Utils.NormalizeCount(count)
    metadata = metadata or {}

    if not cleanName then
        return false, "invalid_item"
    end

    if normalizedCount < 0 then
        HC.LogAudit("invalid_inventory_mutation", source, nil, {
            action = "set",
            item = cleanName,
            amount = normalizedCount
        })
        return false, "invalid_count"
    end

    if not acquireLock(source) then
        return false, "inventory_busy"
    end

    local items, err = getInventory(source)
    if not items then
        releaseLock(source)
        return false, err
    end

    local idx, existing = findItemSlot(items, cleanName, metadata)
    if normalizedCount == 0 then
        if idx then
            table.remove(items, idx)
        end
    elseif existing then
        existing.count = normalizedCount
    else
        if #items >= maxUniqueItems then
            releaseLock(source)
            return false, "inventory_full"
        end
        items[#items + 1] = {
            name = cleanName,
            count = normalizedCount,
            metadata = metadata
        }
    end

    local player = HC.PlayerManager.GetPlayer(source)
    if player then
        player._dirty.inventory = true
        local persisted = persistInventory(player)
        if persisted == nil then
            releaseLock(source)
            return false, "persist_failed"
        end
    end

    syncInventory(source, items)
    releaseLock(source)
    return true
end

function Inventory.HasItem(source, itemName, count, metadata)
    local cleanName = normalizeItemName(itemName)
    local needed = Utils.NormalizeCount(count)
    metadata = metadata or nil

    if not cleanName then
        return false, 0
    end

    if needed <= 0 then
        needed = 1
    end

    local items = getInventory(source)
    if not items then
        return false, 0
    end

    local total = 0
    for i = 1, #items do
        local item = items[i]
        if item.name == cleanName then
            if metadata == nil or metadataMatches(item.metadata, metadata) then
                total = total + (item.count or 0)
            end
        end
    end

    return total >= needed, total
end

function Inventory.ClearInventory(source)
    source = tonumber(source or 0)
    if not acquireLock(source) then
        return false, "inventory_busy"
    end

    local items, err, player = getInventory(source)
    if not items then
        releaseLock(source)
        return false, err
    end

    player.inventory = {}
    player._dirty.inventory = true
    local persisted = persistInventory(player)
    if persisted == nil then
        releaseLock(source)
        return false, "persist_failed"
    end

    syncInventory(source, player.inventory)
    releaseLock(source)
    return true
end
