HauntedCore = HauntedCore or {}
HauntedCore.Client = HauntedCore.Client or {}

local HC = HauntedCore

local auraFxHandle = nil
local auraAsset = "core"
local auraFxName = "ent_dst_elec_fire"
local timecycleActive = false
local lastFootstepAt = 0

local function ensureAuraStarted()
    if auraFxHandle then
        return
    end

    RequestNamedPtfxAsset(auraAsset)
    if not HasNamedPtfxAssetLoaded(auraAsset) then
        return
    end

    UseParticleFxAssetNextCall(auraAsset)
    auraFxHandle = StartParticleFxLoopedOnEntity(
        auraFxName,
        PlayerPedId(),
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        Config.Ghost.visual.auraScale or 0.65,
        false, false, false
    )
end

local function stopAura()
    if auraFxHandle then
        StopParticleFxLooped(auraFxHandle, false)
        auraFxHandle = nil
    end
end

local function applyDistortion()
    if timecycleActive then
        return
    end
    SetTimecycleModifier("spectator5")
    timecycleActive = true
end

local function clearDistortion()
    if not timecycleActive then
        return
    end
    ClearTimecycleModifier()
    timecycleActive = false
end

CreateThread(function()
    while true do
        Wait(250)
        local isGhost = HC.Client.IsGhostActive and HC.Client.IsGhostActive() or false

        if isGhost then
            ensureAuraStarted()
            applyDistortion()
        else
            stopAura()
            clearDistortion()
        end
    end
end)

CreateThread(function()
    while true do
        Wait(100)
        local isGhost = HC.Client.IsGhostActive and HC.Client.IsGhostActive() or false
        if isGhost then
            local ped = PlayerPedId()
            if ped ~= 0 and IsPedOnFoot(ped) and IsPedWalking(ped) then
                local now = GetGameTimer()
                if now - lastFootstepAt > 850 then
                    lastFootstepAt = now
                    PlaySoundFromEntity(-1, "GOLF_SWING_LIGHT", ped, "HUD_FRONTEND_DEFAULT_SOUNDSET", false, 0)
                end
            end
        end
    end
end)
