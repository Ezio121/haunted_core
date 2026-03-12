HauntedCore = HauntedCore or {}
HauntedCore.Client = HauntedCore.Client or {}

local HC = HauntedCore
local Constants = HC.Constants

local localGhostState = Constants.GHOST_STATES.ALIVE
local ghostPlayers = {}
local phaseExpiresAt = 0
local invisExpiresAt = 0

local function gameNow()
    return GetGameTimer()
end

local function isLocalGhost()
    return localGhostState == Constants.GHOST_STATES.GHOST
end

function HC.Client.IsGhostActive()
    return isLocalGhost()
end

local function notify(text)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, false)
end

local function applyLocalGhostState()
    local ped = PlayerPedId()
    if ped == 0 then
        return
    end

    if isLocalGhost() then
        SetEntityAlpha(ped, Config.Ghost.visual.alpha or 160, false)
        SetPedCanRagdoll(ped, false)
    else
        ResetEntityAlpha(ped)
        SetPedCanRagdoll(ped, true)
    end
end

RegisterNetEvent(Constants.EVENTS.GHOST_STATE_SYNC, function(payload)
    if type(payload) ~= "table" then
        return
    end

    local targetSource = tonumber(payload.source or 0)
    local state = payload.state
    if state ~= Constants.GHOST_STATES.ALIVE and state ~= Constants.GHOST_STATES.GHOST then
        return
    end

    if targetSource == GetPlayerServerId(PlayerId()) then
        localGhostState = state
        applyLocalGhostState()
        if state == Constants.GHOST_STATES.GHOST then
            notify("You crossed into the spirit realm.")
        else
            notify("You returned to the living realm.")
        end
    end

    ghostPlayers[targetSource] = state
end)

RegisterNetEvent(Constants.EVENTS.ABILITY_ACTIVATED, function(payload)
    if type(payload) ~= "table" then
        return
    end

    local ability = payload.ability
    local durationMs = tonumber(payload.durationMs) or 0
    local expiresAt = gameNow() + durationMs

    if ability == "phase_through_walls" then
        phaseExpiresAt = math.max(phaseExpiresAt, expiresAt)
    elseif ability == "invisibility" then
        invisExpiresAt = math.max(invisExpiresAt, expiresAt)
    end
end)

CreateThread(function()
    while true do
        Wait(100)
        local ped = PlayerPedId()
        if ped ~= 0 then
            local now = gameNow()
            local phaseActive = now < phaseExpiresAt
            local invisActive = now < invisExpiresAt

            if phaseActive then
                SetEntityCollision(ped, false, false)
            else
                SetEntityCollision(ped, true, true)
            end

            if invisActive then
                SetEntityAlpha(ped, 40, false)
            else
                if isLocalGhost() then
                    SetEntityAlpha(ped, Config.Ghost.visual.alpha or 160, false)
                else
                    ResetEntityAlpha(ped)
                end
            end

            if isLocalGhost() then
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 140, true)
                DisableControlAction(0, 141, true)
                DisableControlAction(0, 142, true)
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(750)
        local myPed = PlayerPedId()
        if myPed ~= 0 then
            local players = GetActivePlayers()
            for i = 1, #players do
                local clientId = players[i]
                if clientId ~= PlayerId() then
                    local serverId = GetPlayerServerId(clientId)
                    local otherPed = GetPlayerPed(clientId)
                    if otherPed ~= 0 then
                        if ghostPlayers[serverId] == Constants.GHOST_STATES.GHOST then
                            SetEntityAlpha(otherPed, 140, false)
                            SetEntityNoCollisionEntity(myPed, otherPed, true)
                        else
                            ResetEntityAlpha(otherPed)
                        end
                    end
                end
            end
        end
    end
end)
