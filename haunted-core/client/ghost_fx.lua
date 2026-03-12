HauntedCore = HauntedCore or {}
HauntedCore.GhostFX = HauntedCore.GhostFX or {}

local HC = HauntedCore
local GhostFX = HC.GhostFX
local Constants = HC.Constants

local localGhostState = Constants.GHOST_STATES.ALIVE
local possessionActive = false
local phaseUntil = 0

local function nowMs()
    return GetGameTimer()
end

local function notifyTransition(state)
    if state == Constants.GHOST_STATES.GHOST then
        TriggerEvent("haunted:notify:push", {
            type = "supernatural",
            title = "Veil Breached",
            description = "Your spirit has crossed beyond the living realm.",
            icon = "ghost",
            sound = "whisper_open"
        })
    else
        TriggerEvent("haunted:notify:push", {
            type = "info",
            title = "Anchored",
            description = "You have returned to your mortal resonance.",
            icon = "return"
        })
    end
end

local function applyGhostOverlay(active)
    if not (HC.UI and HC.UI.ShowOverlay and HC.UI.HideOverlay) then
        return
    end

    if active then
        HC.UI.ShowOverlay("ghost_ambient", {
            intensity = (Config.UI and Config.UI.Theme and Config.UI.Theme.GhostDistortionIntensity) or 0.74
        })
    else
        HC.UI.HideOverlay("ghost_ambient")
    end
end

local function applyPossessionOverlay(active)
    possessionActive = active == true

    if possessionActive then
        HC.UI.ShowOverlay("possession", {
            title = "Possession Active",
            hint = "Hold BACKSPACE to release control",
            stability = (LocalPlayer and LocalPlayer.state and LocalPlayer.state.possessionStability) or 100
        })
    else
        HC.UI.HideOverlay("possession")
    end
end

RegisterNetEvent(Constants.EVENTS.GHOST_STATE_SYNC, function(payload)
    if type(payload) ~= "table" then
        return
    end

    if tonumber(payload.source or -1) ~= GetPlayerServerId(PlayerId()) then
        return
    end

    local state = payload.state
    if state ~= Constants.GHOST_STATES.ALIVE and state ~= Constants.GHOST_STATES.GHOST then
        return
    end

    if state ~= localGhostState then
        localGhostState = state
        notifyTransition(state)
        applyGhostOverlay(state == Constants.GHOST_STATES.GHOST)
    end
end)

RegisterNetEvent(Constants.EVENTS.ABILITY_ACTIVATED, function(payload)
    if type(payload) ~= "table" then
        return
    end

    local ability = payload.ability
    if ability == "object_possession" then
        applyPossessionOverlay(true)
        CreateThread(function()
            Wait(tonumber(payload.durationMs) or 10000)
            applyPossessionOverlay(false)
        end)
    elseif ability == "phase_through_walls" then
        phaseUntil = nowMs() + (tonumber(payload.durationMs) or 5000)
        HC.UI.ShowOverlay("phase", {
            duration = tonumber(payload.durationMs) or 5000
        })
    end
end)

CreateThread(function()
    while true do
        Wait(200)

        if phaseUntil > 0 and nowMs() > phaseUntil then
            phaseUntil = 0
            HC.UI.HideOverlay("phase")
        end

        if possessionActive then
            if IsControlJustPressed(0, 194) then
                applyPossessionOverlay(false)
            end
        end
    end
end)

AddEventHandler("onClientResourceStart", function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    Wait(400)
    local state = LocalPlayer and LocalPlayer.state and LocalPlayer.state.ghostState or Constants.GHOST_STATES.ALIVE
    localGhostState = state
    applyGhostOverlay(state == Constants.GHOST_STATES.GHOST)
end)
