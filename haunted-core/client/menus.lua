HauntedCore = HauntedCore or {}
HauntedCore.Menus = HauntedCore.Menus or {}

local HC = HauntedCore
local Menus = HC.Menus

local activeMenu = nil

local function normalizeMenu(menu)
    local normalized = {
        id = tostring(menu and menu.id or ("menu_%s"):format(GetGameTimer())),
        title = tostring(menu and menu.title or "Haunted Menu"),
        subtitle = tostring(menu and menu.subtitle or ""),
        searchable = (menu and menu.searchable) ~= false,
        breadcrumbs = menu and menu.breadcrumbs or {},
        entries = {},
        context = menu and menu.context or {}
    }

    local entries = menu and menu.entries or {}
    for i = 1, #entries do
        local entry = entries[i]
        normalized.entries[#normalized.entries + 1] = {
            id = tostring(entry.id or i),
            title = tostring(entry.title or "Untitled"),
            description = tostring(entry.description or ""),
            icon = tostring(entry.icon or "sigil"),
            disabled = entry.disabled == true,
            locked = entry.locked == true,
            badge = entry.badge,
            progress = tonumber(entry.progress) or nil,
            hotkey = entry.hotkey,
            serverEvent = entry.serverEvent,
            clientEvent = entry.clientEvent,
            args = entry.args,
            submenu = entry.submenu,
            close = entry.close ~= false
        }
    end

    return normalized
end

local function handleAction(action, item)
    if not activeMenu or not item then
        return
    end

    if action ~= "select" then
        return
    end

    if item.serverEvent then
        TriggerServerEvent(item.serverEvent, item.args)
    end

    if item.clientEvent then
        TriggerEvent(item.clientEvent, item.args)
    end

    if item.submenu and type(item.submenu) == "table" then
        Menus.Open(item.submenu)
        return
    end

    if item.close ~= false then
        Menus.Close()
    end
end

function Menus.Open(menu)
    local normalized = normalizeMenu(menu)
    activeMenu = normalized

    HC.UI.OpenMenu(normalized, function(action, item)
        if action == "close" then
            Menus.Close(false)
            return
        end

        handleAction(action, item)
    end)
end

function Menus.Update(menu)
    if not activeMenu then
        return
    end

    local updated = normalizeMenu(menu)
    updated.id = activeMenu.id
    activeMenu = updated

    HC.UI.Send("haunted:menu:update", {
        menu = updated
    })
end

function Menus.Close(emit)
    if not activeMenu then
        return
    end

    activeMenu = nil
    HC.UI.CloseMenu()

    if emit ~= false then
        TriggerEvent("haunted:menu:closed")
    end
end

function Menus.IsOpen()
    return activeMenu ~= nil
end

RegisterNetEvent("haunted:menu:open", function(menu)
    Menus.Open(menu)
end)

RegisterNetEvent("haunted:menu:update", function(menu)
    Menus.Update(menu)
end)

RegisterNetEvent("haunted:menu:close", function()
    Menus.Close()
end)

RegisterCommand("hc_menu", function()
    if not (Config.UI and Config.UI.Developer and Config.UI.Developer.PreviewCommands) then
        return
    end

    Menus.Open({
        id = "preview_main",
        title = "Occult Command Ledger",
        subtitle = "Cursed systems calibration",
        searchable = true,
        entries = {
            {
                id = "ghost",
                title = "Ghost Protocol",
                description = "Toggle spirit state and stabilize your veil signature.",
                icon = "ghost",
                clientEvent = "haunted:notify:push",
                args = {
                    type = "supernatural",
                    title = "Ghost Protocol",
                    description = "Route this entry to your production server event."
                }
            },
            {
                id = "ritual",
                title = "Ritual Controls",
                description = "Open nested ritual actions.",
                icon = "rune",
                submenu = {
                    title = "Ritual Controls",
                    subtitle = "Select invocation",
                    entries = {
                        {
                            id = "ward",
                            title = "Ward Circle",
                            description = "Manifest a protective ward.",
                            icon = "sigil",
                            clientEvent = "haunted:notify:push",
                            args = {
                                type = "ritual",
                                title = "Ward Active",
                                description = "A silver ring seals the floor."
                            }
                        },
                        {
                            id = "banish",
                            title = "Banish Echo",
                            description = "Force unstable spirit traces to dissipate.",
                            icon = "skull",
                            clientEvent = "haunted:notify:push",
                            args = {
                                type = "warning",
                                title = "Echo Banished",
                                description = "Residual whispers were suppressed."
                            }
                        }
                    }
                }
            },
            {
                id = "close",
                title = "Close Ledger",
                description = "Return to your current state.",
                icon = "close",
                close = true
            }
        }
    })
end, false)

RegisterKeyMapping("hc_menu", "Haunted Core: Open Context Ledger", "keyboard", (Config.UI and Config.UI.Menus and Config.UI.Menus.OpenKey) or "F2")
