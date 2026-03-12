HauntedCore = HauntedCore or {}
HauntedCore.Radial = HauntedCore.Radial or {}

local HC = HauntedCore
local Radial = HC.Radial
local Constants = HC.Constants

local radialOpen = false
local currentStack = {}

local ghostWheel = {
    id = "ghost_root",
    title = "Spectral Conduit",
    subtitle = "Choose an invocation",
    slices = {
        {
            id = "phase_through_walls",
            label = "Phase",
            icon = "phase",
            ability = "phase_through_walls",
            cooldown = 0,
            locked = false
        },
        {
            id = "invisibility",
            label = "Manifest Veil",
            icon = "veil",
            ability = "invisibility",
            cooldown = 0,
            locked = false
        },
        {
            id = "object_possession",
            label = "Possess",
            icon = "possession",
            ability = "object_possession",
            cooldown = 0,
            locked = false
        },
        {
            id = "spirit_whisper",
            label = "Whisper",
            icon = "whisper",
            ability = "spirit_whisper",
            cooldown = 0,
            locked = false,
            meta = {
                prompt = true
            }
        },
        {
            id = "haunt_entities",
            label = "Haunt",
            icon = "haunt",
            ability = "haunt_entities",
            cooldown = 0,
            locked = false
        },
        {
            id = "return",
            label = "Return",
            icon = "return",
            close = true
        }
    }
}

local function triggerAbilityFromSlice(slice)
    if not slice or not slice.ability then
        return
    end

    if not HC.Client or not HC.Client.GetSecurityToken or not HC.Client.BuildSecurePayload then
        return
    end

    local token = HC.Client.GetSecurityToken()
    if not token then
        TriggerEvent("haunted:notify:push", {
            type = "warning",
            title = "Conduit Unstable",
            description = "Security token sync pending. Try again shortly.",
            icon = "warning"
        })
        return
    end

    local payload = {
        ability = slice.ability
    }

    if slice.ability == "spirit_whisper" then
        DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP8", "", "", "", "", "", 120)
        while UpdateOnscreenKeyboard() == 0 do
            Wait(0)
        end
        if GetOnscreenKeyboardResult() then
            payload.message = GetOnscreenKeyboardResult()
        else
            return
        end
    end

    TriggerServerEvent(Constants.EVENTS.REQUEST_ABILITY, HC.Client.BuildSecurePayload(payload))
end

local function pushLayer(data)
    currentStack[#currentStack + 1] = data
end

local function popLayer()
    if #currentStack > 1 then
        currentStack[#currentStack] = nil
    end
    return currentStack[#currentStack]
end

local function currentLayer()
    return currentStack[#currentStack]
end

local function openLayer(layer)
    if not layer then
        return
    end

    radialOpen = true
    HC.UI.OpenRadial(layer, function(action, slice)
        if action == "close" then
            Radial.Close()
            return
        end

        if action ~= "select" then
            return
        end

        if slice and slice.submenu then
            pushLayer(slice.submenu)
            openLayer(slice.submenu)
            return
        end

        if slice and slice.back then
            local parent = popLayer()
            openLayer(parent)
            return
        end

        if slice and slice.close then
            Radial.Close()
            return
        end

        triggerAbilityFromSlice(slice)

        if Config.UI and Config.UI.Radial and Config.UI.Radial.CloseOnSelect ~= false then
            Radial.Close()
        end
    end)
end

function Radial.Open(data)
    data = data or ghostWheel
    currentStack = {}
    pushLayer(data)
    openLayer(data)
end

function Radial.Close()
    radialOpen = false
    currentStack = {}
    HC.UI.CloseRadial()
end

function Radial.IsOpen()
    return radialOpen
end

RegisterNetEvent("haunted:radial:open", function(data)
    Radial.Open(data)
end)

RegisterNetEvent("haunted:radial:close", function()
    Radial.Close()
end)

RegisterCommand("hc_radial", function()
    Radial.Open(ghostWheel)
end, false)

RegisterKeyMapping("hc_radial", "Haunted Core: Open Ghost Ability Wheel", "keyboard", (Config.UI and Config.UI.Radial and Config.UI.Radial.OpenKey) or "F5")
