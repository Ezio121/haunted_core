HauntedCore = HauntedCore or {}
HauntedCore.Ghost = HauntedCore.Ghost or {}

local HC = HauntedCore
local Ghost = HC.Ghost
local Constants = HC.Constants
local Utils = HC.Utils

local cooldowns = {}

local function nowMs()
    return Utils.NowMs()
end

local function getAbilityConfig(abilityName)
    if not Config.Ghost or not Config.Ghost.abilities then
        return nil
    end
    return Config.Ghost.abilities[abilityName]
end

local function getPlayer(source)
    return HC.PlayerManager.GetPlayer(source)
end

local function setStateBag(source, state)
    local playerRef = Player(source)
    if playerRef then
        playerRef.state:set("ghostState", state, true)
    end
end

local function persistGhostState(player)
    HC.DB.execute([[
        INSERT INTO ghost_states (citizenid, state, spirit_energy, haunt_level, possession_state, last_transition_at)
        VALUES (?, ?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE
            state = VALUES(state),
            spirit_energy = VALUES(spirit_energy),
            haunt_level = VALUES(haunt_level),
            possession_state = VALUES(possession_state),
            last_transition_at = VALUES(last_transition_at),
            updated_at = CURRENT_TIMESTAMP
    ]], {
        player.citizenid,
        player.ghost_state,
        player.accounts.spirit_energy or 0,
        tonumber(player.metadata.haunt_level) or 0,
        Utils.SafeJsonEncode({}, "{}")
    })
end

local function sendGhostState(source, state, reason)
    TriggerClientEvent(Constants.EVENTS.GHOST_STATE_SYNC, -1, {
        source = source,
        state = state,
        reason = reason or "sync"
    })
end

local function ensureCooldownBucket(source)
    local bucket = cooldowns[source]
    if not bucket then
        bucket = {}
        cooldowns[source] = bucket
    end
    return bucket
end

local function abilityOnCooldown(source, abilityName)
    local bucket = ensureCooldownBucket(source)
    local expiresAt = bucket[abilityName]
    if not expiresAt then
        return false, 0
    end

    local remaining = expiresAt - nowMs()
    if remaining <= 0 then
        bucket[abilityName] = nil
        return false, 0
    end

    return true, remaining
end

local function setAbilityCooldown(source, abilityName, cooldownMs)
    local bucket = ensureCooldownBucket(source)
    bucket[abilityName] = nowMs() + cooldownMs
end

local function nearbyPlayers(source, maxDistance)
    local out = {}
    local srcPed = GetPlayerPed(source)
    if srcPed == 0 then
        return out
    end

    local srcCoords = GetEntityCoords(srcPed)
    local list = GetPlayers()
    for i = 1, #list do
        local other = tonumber(list[i])
        if other and other ~= source then
            local ped = GetPlayerPed(other)
            if ped ~= 0 then
                local coords = GetEntityCoords(ped)
                local dx = srcCoords.x - coords.x
                local dy = srcCoords.y - coords.y
                local dz = srcCoords.z - coords.z
                local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
                if dist <= maxDistance then
                    out[#out + 1] = other
                end
            end
        end
    end
    return out
end

function Ghost.GetGhostState(source)
    local player = getPlayer(source)
    if not player then
        return Constants.GHOST_STATES.ALIVE
    end
    return player.ghost_state or Constants.GHOST_STATES.ALIVE
end

function Ghost.SetGhostState(source, state, reason)
    state = tostring(state or Constants.GHOST_STATES.ALIVE)
    if state ~= Constants.GHOST_STATES.ALIVE and state ~= Constants.GHOST_STATES.GHOST then
        HC.LogAudit("ghost_state_abuse_attempt", source, nil, {
            state = state,
            reason = "invalid_state"
        })
        return false, "invalid_state"
    end

    local player = getPlayer(source)
    if not player then
        return false, "player_not_found"
    end

    player.ghost_state = state
    player.metadata.lastGhostState = os.time()
    player._dirty.ghost = true
    setStateBag(source, state)
    persistGhostState(player)
    sendGhostState(source, state, reason or "set_state")
    HC.Events.Emit("ghost:stateChanged", source, state)
    HC.LogAudit("ghost_state_changed", source, player.citizenid, {
        state = state,
        reason = reason
    })
    return true
end

function Ghost.CanPlayersInteract(sourceA, sourceB)
    local stateA = Ghost.GetGhostState(sourceA)
    local stateB = Ghost.GetGhostState(sourceB)
    return stateA == stateB
end

function Ghost.CanUseAbility(source, abilityName)
    local player = getPlayer(source)
    if not player then
        return false, "player_not_found"
    end

    if player.ghost_state ~= Constants.GHOST_STATES.GHOST then
        HC.LogAudit("ghost_ability_denied", source, player.citizenid, {
            ability = abilityName,
            reason = "not_ghost"
        })
        return false, "not_ghost"
    end

    local ability = getAbilityConfig(abilityName)
    if not ability then
        return false, "invalid_ability"
    end

    local onCd = abilityOnCooldown(source, abilityName)
    if onCd then
        return false, "cooldown"
    end

    local spirit = HC.Economy.GetMoney(source, Constants.ACCOUNTS.SPIRIT)
    if spirit < (ability.cost or 0) then
        HC.LogAudit("ghost_ability_denied", source, player.citizenid, {
            ability = abilityName,
            reason = "insufficient_spirit",
            spirit = spirit
        })
        return false, "insufficient_spirit_energy"
    end

    return true, ability
end

local function abilityPhaseThroughWalls(source, ability)
    TriggerClientEvent(Constants.EVENTS.ABILITY_ACTIVATED, source, {
        ability = "phase_through_walls",
        durationMs = ability.durationMs
    })
    return true
end

local function abilityInvisibility(source, ability)
    TriggerClientEvent(Constants.EVENTS.ABILITY_ACTIVATED, source, {
        ability = "invisibility",
        durationMs = ability.durationMs
    })
    return true
end

local function abilityObjectPossession(source, ability, payload)
    local netId = payload and payload.targetNetId
    if not netId then
        return false, "missing_target_netid"
    end

    local ok, reason = HC.EntityManager.PossessEntity(source, netId, ability.durationMs)
    if not ok then
        return false, reason
    end

    TriggerClientEvent(Constants.EVENTS.ABILITY_ACTIVATED, source, {
        ability = "object_possession",
        durationMs = ability.durationMs,
        targetNetId = netId
    })

    return true
end

local function abilitySpiritWhisper(source, ability, payload)
    local message = payload and payload.message
    if type(message) ~= "string" then
        return false, "invalid_message"
    end

    message = message:gsub("^%s+", ""):gsub("%s+$", "")
    if message == "" then
        return false, "empty_message"
    end

    local maxLength = ability.maxMessageLength or 120
    if #message > maxLength then
        return false, "message_too_long"
    end

    local recipients = nearbyPlayers(source, ability.range or 40.0)
    local name = GetPlayerName(source) or ("Ghost %s"):format(source)

    for i = 1, #recipients do
        local target = recipients[i]
        TriggerClientEvent("chat:addMessage", target, {
            color = { 155, 220, 255 },
            args = { "[Spirit Whisper]", ("%s: %s"):format(name, message) }
        })
    end

    TriggerClientEvent("chat:addMessage", source, {
        color = { 155, 220, 255 },
        args = { "[Spirit Whisper]", message }
    })

    return true
end

local function abilityHauntEntities(source, ability, payload)
    local netId = payload and payload.targetNetId
    if not netId then
        return false, "missing_target_netid"
    end

    local ok, reason = HC.EntityManager.HauntEntity(source, netId, ability.durationMs, 1.0)
    if not ok then
        return false, reason
    end

    TriggerClientEvent(Constants.EVENTS.ABILITY_ACTIVATED, source, {
        ability = "haunt_entities",
        durationMs = ability.durationMs,
        targetNetId = netId
    })

    return true
end

local abilityHandlers = {
    phase_through_walls = abilityPhaseThroughWalls,
    invisibility = abilityInvisibility,
    object_possession = abilityObjectPossession,
    spirit_whisper = abilitySpiritWhisper,
    haunt_entities = abilityHauntEntities
}

function Ghost.UseAbility(source, abilityName, payload)
    local allowed, abilityOrReason = Ghost.CanUseAbility(source, abilityName)
    if not allowed then
        return false, abilityOrReason
    end

    local ability = abilityOrReason
    local handler = abilityHandlers[abilityName]
    if not handler then
        return false, "handler_not_found"
    end

    local executed, reason = handler(source, ability, payload or {})
    if not executed then
        return false, reason
    end

    local removed, removeReason = HC.Economy.RemoveMoney(source, Constants.ACCOUNTS.SPIRIT, ability.cost or 0, "ghost_ability")
    if not removed then
        return false, removeReason
    end

    setAbilityCooldown(source, abilityName, tonumber(ability.cooldownMs) or 1000)
    local player = getPlayer(source)
    if player then
        persistGhostState(player)
    end
    HC.LogAudit("ghost_ability_used", source, player and player.citizenid or nil, {
        ability = abilityName,
        cost = ability.cost or 0
    })
    HC.Events.Emit("ghost:abilityUsed", source, abilityName)
    return true
end

function Ghost.Init()
    RegisterSecureNetEvent(Constants.EVENTS.REQUEST_ABILITY, function(source, payload)
        local ability = payload and payload.ability
        if type(ability) ~= "string" then
            return
        end
        Ghost.UseAbility(source, ability, payload)
    end, {
        rateLimit = {
            limit = 8,
            windowMs = 3000
        },
        sanityCheck = function(source, payload)
            if type(payload) ~= "table" then
                return false, "payload_not_table"
            end

            local ability = payload.ability
            if type(ability) ~= "string" or not getAbilityConfig(ability) then
                return false, "invalid_ability"
            end

            local player = getPlayer(source)
            if not player then
                return false, "player_not_found"
            end

            return true
        end
    })

    RegisterCommand("ghost", function(source, args)
        if source == 0 then
            return
        end

        if not HC.Permissions.HasPermission(source, "admin") then
            return
        end

        local desired = args[1]
        local current = Ghost.GetGhostState(source)
        local nextState = current == Constants.GHOST_STATES.GHOST and Constants.GHOST_STATES.ALIVE or Constants.GHOST_STATES.GHOST

        if desired then
            desired = string.upper(desired)
            if desired == "ALIVE" or desired == "GHOST" then
                nextState = desired
            end
        end

        Ghost.SetGhostState(source, nextState, "command")
    end, false)

    CreateThread(function()
        local regenTick = tonumber(Config.Ghost.regenTickMs) or 15000
        local regenAmount = tonumber(Config.Ghost.regenAliveSpiritPerTick) or 1
        while true do
            Wait(regenTick)
            local players = GetPlayers()
            for i = 1, #players do
                local src = tonumber(players[i])
                if src and Ghost.GetGhostState(src) == Constants.GHOST_STATES.ALIVE then
                    HC.Economy.AddSpiritEnergy(src, regenAmount, "alive_regen")
                end
            end
        end
    end)
end

AddEventHandler("playerDropped", function()
    cooldowns[source] = nil
end)
