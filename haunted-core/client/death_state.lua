HauntedCore = HauntedCore or {}
HauntedCore.DeathState = HauntedCore.DeathState or {}

local HC = HauntedCore
local DeathState = HC.DeathState

local dead = false
local deadAt = 0
local limboShown = false

local function nowMs()
    return GetGameTimer()
end

function DeathState.ShowDeathOverlay()
    HC.UI.ShowOverlay("death", {
        title = "Soul Severed",
        subtitle = "Your body is silent. Await intervention.",
        pulse = true
    })
end

function DeathState.ShowLimboOverlay()
    HC.UI.ShowOverlay("limbo", {
        title = "Limbo",
        subtitle = "Drift through the veil until called back.",
        whisper = "The candle remembers your name."
    })
end

function DeathState.HideOverlays()
    HC.UI.HideOverlay("death")
    HC.UI.HideOverlay("limbo")
    HC.UI.HideOverlay("afterlife")
end

function DeathState.OnDeath()
    dead = true
    deadAt = nowMs()
    limboShown = false

    TriggerEvent("haunted:notify:push", {
        type = "warning",
        title = "Near Death",
        description = "Your spirit is slipping from the mortal plane.",
        icon = "skull",
        sound = "cursed_error"
    })

    DeathState.ShowDeathOverlay()
end

function DeathState.OnRevive()
    dead = false
    deadAt = 0
    limboShown = false

    DeathState.HideOverlays()
    TriggerEvent("haunted:notify:push", {
        type = "success",
        title = "Resurrected",
        description = "A pulse of life drags you back to the living realm.",
        icon = "return"
    })
end

RegisterNetEvent("haunted:death:forceOverlay", function(name, payload)
    if name == "afterlife" then
        HC.UI.ShowOverlay("afterlife", payload or {
            title = "Afterlife Queue",
            subtitle = "Awaiting ritual restoration"
        })
    elseif name == "hide" then
        DeathState.HideOverlays()
    end
end)

CreateThread(function()
    while true do
        Wait(250)

        local ped = PlayerPedId()
        if ped == 0 then
            goto continue
        end

        local isDead = IsEntityDead(ped)
        if isDead and not dead then
            DeathState.OnDeath()
        elseif not isDead and dead then
            DeathState.OnRevive()
        end

        if dead and not limboShown and nowMs() - deadAt > 8500 then
            limboShown = true
            DeathState.ShowLimboOverlay()
        end

        ::continue::
    end
end)
