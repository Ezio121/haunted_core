HauntedCore = HauntedCore or {}
local HC = HauntedCore

local function SetGhostState(source, state, reason)
    return HC.Ghost.SetGhostState(source, state, reason)
end

local function GetGhostState(source)
    return HC.Ghost.GetGhostState(source)
end

local function UseGhostAbility(source, abilityName, payload)
    return HC.Ghost.UseAbility(source, abilityName, payload)
end

exports("SetGhostState", SetGhostState)
exports("GetGhostState", GetGhostState)
exports("UseGhostAbility", UseGhostAbility)
