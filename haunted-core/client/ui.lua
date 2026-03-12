HauntedCore = HauntedCore or {}
HauntedCore.UI = HauntedCore.UI or {}

local HC = HauntedCore
local UI = HC.UI

local resourceName = GetCurrentResourceName()
local uiEnabled = (Config.UI and Config.UI.Enabled) ~= false
local nuiReady = false
local focused = false
local messageQueue = {}
local queueLimit = 256
local callbackNonce = 0
local menuCallbacks = {}
local radialCallbacks = {}

local function debugLog(message, ...)
    if not (Config.UI and Config.UI.Developer and Config.UI.Developer.DebugNuiMessages) then
        return
    end

    local text = "[HauntedCore:UI] " .. tostring(message)
    if select("#", ...) > 0 then
        text = text:format(...)
    end
    print(text)
end

local function nextNonce()
    callbackNonce = callbackNonce + 1
    if callbackNonce > 2147480000 then
        callbackNonce = 1
    end
    return tostring(callbackNonce)
end

local function pushQueuedMessage(message)
    if #messageQueue >= queueLimit then
        table.remove(messageQueue, 1)
    end
    messageQueue[#messageQueue + 1] = message
end

local function flushQueue()
    if not nuiReady then
        return
    end

    for i = 1, #messageQueue do
        SendNUIMessage(messageQueue[i])
    end

    messageQueue = {}
end

local function sendRaw(message)
    if not uiEnabled then
        return false
    end

    if not nuiReady then
        pushQueuedMessage(message)
        return false
    end

    SendNUIMessage(message)
    return true
end

function UI.Send(messageType, payload)
    if type(messageType) ~= "string" or messageType == "" then
        return false
    end

    local packet = {
        type = messageType,
        payload = payload or {}
    }

    debugLog("send %s", messageType)
    return sendRaw(packet)
end

function UI.SetFocus(enabled, hasCursor)
    enabled = enabled == true
    hasCursor = hasCursor == true

    if focused == enabled then
        SetNuiFocusKeepInput(enabled)
        SetNuiFocus(enabled, hasCursor)
        return
    end

    focused = enabled
    SetNuiFocusKeepInput(enabled)
    SetNuiFocus(enabled, hasCursor)

    if not enabled then
        UI.Send("haunted:ui:blur", {})
    end
end

function UI.IsFocused()
    return focused
end

function UI.Notify(data)
    data = data or {}
    UI.Send("haunted:notify:push", data)
end

function UI.ToggleHud(enabled)
    UI.Send("haunted:hud:toggle", {
        enabled = enabled == true
    })
end

function UI.UpdateHud(data)
    UI.Send("haunted:hud:update", data)
end

function UI.ShowOverlay(name, data)
    if type(name) ~= "string" or name == "" then
        return
    end

    UI.Send("haunted:overlay:show", {
        name = name,
        data = data or {}
    })
end

function UI.HideOverlay(name)
    if type(name) ~= "string" or name == "" then
        return
    end

    UI.Send("haunted:overlay:hide", {
        name = name
    })
end

function UI.OpenMenu(menuData, callback)
    local callbackId
    if type(callback) == "function" then
        callbackId = nextNonce()
        menuCallbacks[callbackId] = callback
    end

    UI.SetFocus(true, true)
    UI.Send("haunted:menu:open", {
        menu = menuData or {},
        callbackId = callbackId
    })
end

function UI.CloseMenu()
    UI.Send("haunted:menu:close", {})
    UI.SetFocus(false, false)
end

function UI.OpenRadial(data, callback)
    local callbackId
    if type(callback) == "function" then
        callbackId = nextNonce()
        radialCallbacks[callbackId] = callback
    end

    local useCursor = Config.UI and Config.UI.Radial and Config.UI.Radial.CursorOnOpen ~= false
    UI.SetFocus(true, useCursor)
    UI.Send("haunted:radial:open", {
        radial = data or {},
        callbackId = callbackId
    })
end

function UI.CloseRadial()
    UI.Send("haunted:radial:close", {})
    UI.SetFocus(false, false)
end

function UI.OpenInventory(data)
    UI.SetFocus(true, true)
    UI.Send("haunted:inventory:open", data or {})
end

function UI.UpdateInventory(data)
    UI.Send("haunted:inventory:update", data or {})
end

function UI.CloseInventory()
    UI.Send("haunted:inventory:close", {})
    UI.SetFocus(false, false)
end

function UI.OpenAdmin(data)
    UI.SetFocus(true, true)
    UI.Send("haunted:admin:open", data or {})
end

function UI.UpdateAdmin(data)
    UI.Send("haunted:admin:update", data or {})
end

function UI.CloseAdmin()
    UI.Send("haunted:admin:close", {})
    UI.SetFocus(false, false)
end

function UI.ShowLoading(data)
    UI.Send("haunted:loading:show", data or {})
end

function UI.HideLoading()
    UI.Send("haunted:loading:hide", {})
end

function UI.OpenCharacter(data)
    UI.SetFocus(true, true)
    UI.Send("haunted:character:open", data or {})
end

function UI.CloseCharacter()
    UI.Send("haunted:character:close", {})
    UI.SetFocus(false, false)
end

local function runMenuCallback(payload)
    if type(payload) ~= "table" then
        return
    end

    local callbackId = payload.callbackId
    local callback = callbackId and menuCallbacks[callbackId]
    if not callback then
        return
    end

    local ok, err = xpcall(function()
        callback(payload.action, payload.item, payload.meta)
    end, debug.traceback)

    if not ok then
        print(("[HauntedCore] menu callback error: %s"):format(err))
    end

    if payload.action == "select" or payload.action == "close" then
        menuCallbacks[callbackId] = nil
    end
end

local function runRadialCallback(payload)
    if type(payload) ~= "table" then
        return
    end

    local callbackId = payload.callbackId
    local callback = callbackId and radialCallbacks[callbackId]
    if not callback then
        return
    end

    local ok, err = xpcall(function()
        callback(payload.action, payload.slice, payload.meta)
    end, debug.traceback)

    if not ok then
        print(("[HauntedCore] radial callback error: %s"):format(err))
    end

    if payload.action == "select" or payload.action == "close" then
        radialCallbacks[callbackId] = nil
    end
end

RegisterNUICallback("haunted:ui:ready", function(_, cb)
    nuiReady = true
    flushQueue()

    UI.Send("haunted:theme:apply", {
        config = Config.UI or {}
    })

    UI.Send("haunted:ui:bootstrap", {
        resource = resourceName,
        config = Config.UI or {}
    })

    cb({ ok = true })
end)

RegisterNUICallback("haunted:ui:menuAction", function(payload, cb)
    runMenuCallback(payload)
    cb({ ok = true })
end)

RegisterNUICallback("haunted:ui:radialAction", function(payload, cb)
    runRadialCallback(payload)
    cb({ ok = true })
end)

RegisterNUICallback("haunted:ui:close", function(_, cb)
    UI.Send("haunted:menu:close", {})
    UI.Send("haunted:radial:close", {})
    UI.Send("haunted:inventory:close", {})
    UI.Send("haunted:admin:close", {})
    UI.Send("haunted:character:close", {})
    UI.SetFocus(false, false)
    cb({ ok = true })
end)

RegisterNetEvent("haunted:overlay:show", function(name, data)
    UI.ShowOverlay(name, data)
end)

RegisterNetEvent("haunted:overlay:hide", function(name)
    UI.HideOverlay(name)
end)

RegisterNetEvent("haunted:inventory:open", function(data)
    UI.OpenInventory(data)
end)

RegisterNetEvent("haunted:inventory:update", function(data)
    UI.UpdateInventory(data)
end)

RegisterNetEvent("haunted:inventory:close", function()
    UI.CloseInventory()
end)

RegisterNetEvent("haunted:admin:open", function(data)
    UI.OpenAdmin(data)
end)

RegisterNetEvent("haunted:admin:update", function(data)
    UI.UpdateAdmin(data)
end)

RegisterNetEvent("haunted:admin:close", function()
    UI.CloseAdmin()
end)

RegisterNetEvent("haunted:loading:show", function(data)
    UI.ShowLoading(data)
end)

RegisterNetEvent("haunted:loading:hide", function()
    UI.HideLoading()
end)

RegisterNetEvent("haunted:character:open", function(data)
    UI.OpenCharacter(data)
end)

RegisterNetEvent("haunted:character:close", function()
    UI.CloseCharacter()
end)

RegisterCommand("hc_inventory", function()
    if not (Config.UI and Config.UI.Developer and Config.UI.Developer.PreviewCommands) then
        return
    end

    UI.OpenInventory({
        title = "Haunted Inventory",
        weight = 28.4,
        maxWeight = 60,
        quickSlots = {
            { label = "Lantern" },
            { label = "Ritual Dagger" },
            { label = "Spirit Shard" }
        },
        items = {
            {
                name = "spirit_shard",
                label = "Spirit Shard",
                count = 14,
                metadata = { rarity = "ghost", description = "Condensed essence from a wandering echo." }
            },
            {
                name = "cursed_relic",
                label = "Cursed Relic",
                count = 1,
                metadata = { rarity = "cursed", description = "A relic that murmurs to its owner." }
            },
            {
                name = "ritual_candle",
                label = "Ritual Candle",
                count = 5,
                metadata = { rarity = "common", description = "Used for ward circles and offerings." }
            }
        },
        tooltip = {
            title = "Spirit Shard",
            description = "Used as catalyst fuel for high-tier ghost manifestations."
        }
    })
end, false)

RegisterCommand("hc_adminpanel", function()
    if not (Config.UI and Config.UI.Developer and Config.UI.Developer.PreviewCommands) then
        return
    end

    UI.OpenAdmin({
        title = "Forbidden Control Console",
        subtitle = "Staff operations",
        players = {
            { id = 11, name = "Mora Voss", citizenid = "HC89A11A2", permission = "admin", ghostState = "GHOST" },
            { id = 24, name = "Luca Vale", citizenid = "HC0BF341D", permission = "helper", ghostState = "ALIVE" }
        },
        logs = {
            { action = "ghost_state_changed", time = "02:12:18" },
            { action = "event_spam_attempt", time = "02:11:53" },
            { action = "money_transfer", time = "02:10:02" }
        }
    })
end, false)

AddEventHandler("onClientResourceStart", function(resource)
    if resource ~= resourceName then
        return
    end

    nuiReady = false
    focused = false
    messageQueue = {}

    Wait(200)

    UI.Send("haunted:theme:apply", {
        config = Config.UI or {}
    })
end)
