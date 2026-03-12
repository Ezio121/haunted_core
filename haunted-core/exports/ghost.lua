HauntedCore = HauntedCore or {}
local HC = HauntedCore

function SetGhostState(source, state, reason)
    return HC.Ghost.SetGhostState(source, state, reason)
end

function GetGhostState(source)
    return HC.Ghost.GetGhostState(source)
end

function UseGhostAbility(source, abilityName, payload)
    return HC.Ghost.UseAbility(source, abilityName, payload)
end

exports("SetGhostState", SetGhostState)
exports("GetGhostState", GetGhostState)
exports("UseGhostAbility", UseGhostAbility)
