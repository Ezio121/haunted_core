HauntedCore = HauntedCore or {}
HauntedCore.Notifications = HauntedCore.Notifications or {}

local HC = HauntedCore
local Notifications = HC.Notifications

local defaults = {
    type = "info",
    title = "Haunted Core",
    description = "",
    duration = (Config.UI and Config.UI.Notifications and Config.UI.Notifications.DefaultDurationMs) or 4200,
    icon = "sigil"
}

local function normalizePayload(data)
    local payload = {}
    payload.type = tostring((data and data.type) or defaults.type)
    payload.title = tostring((data and data.title) or defaults.title)
    payload.description = tostring((data and data.description) or defaults.description)
    payload.duration = math.max(800, tonumber((data and data.duration) or defaults.duration) or defaults.duration)
    payload.icon = tostring((data and data.icon) or defaults.icon)
    payload.sound = data and data.sound or nil
    payload.meta = data and data.meta or {}
    return payload
end

function Notifications.Push(data)
    local payload = normalizePayload(data)

    if HC.UI and HC.UI.Notify then
        HC.UI.Notify(payload)
    end

    return true
end

RegisterNetEvent("haunted:notify:push", function(data)
    Notifications.Push(data)
end)

RegisterCommand("hc_uinotify", function(_, args)
    if not (Config.UI and Config.UI.Developer and Config.UI.Developer.PreviewCommands) then
        return
    end

    local nType = args[1] or "supernatural"
    local title = args[2] or "Cursed Signal"
    local description = table.concat(args, " ", 3)

    if description == "" then
        description = "The veil is thin. Your senses drift into the spirit realm."
    end

    Notifications.Push({
        type = nType,
        title = title,
        description = description,
        duration = 4800,
        icon = "ghost",
        sound = "whisper_open"
    })
end, false)
