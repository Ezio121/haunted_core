HauntedCore = HauntedCore or {}
HauntedCore.EntityManager = HauntedCore.EntityManager or {}

local HC = HauntedCore
local EntityManager = HC.EntityManager
local Utils = HC.Utils

local possessionByNetId = {}
local possessionBySource = {}
local hauntedByNetId = {}

local function nowMs()
    return Utils.NowMs()
end

local function cleanupExpired()
    local current = nowMs()

    for netId, possession in pairs(possessionByNetId) do
        if current >= possession.expiresAt then
            EntityManager.ReleasePossession(netId, "expired")
        end
    end

    for netId, hauntData in pairs(hauntedByNetId) do
        if current >= hauntData.expiresAt then
            hauntedByNetId[netId] = nil
            TriggerClientEvent("haunted:client:hauntEnded", -1, { netId = netId })
        end
    end
end

function EntityManager.Init()
    CreateThread(function()
        while true do
            Wait(1000)
            cleanupExpired()
        end
    end)
end

function EntityManager.GetPossession(netId)
    return possessionByNetId[tonumber(netId or 0)]
end

function EntityManager.PossessEntity(source, netId, durationMs)
    source = tonumber(source or 0)
    netId = tonumber(netId or 0)
    durationMs = tonumber(durationMs or 0)

    if source <= 0 or netId <= 0 or durationMs <= 0 then
        return false, "invalid_params"
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) then
        return false, "invalid_entity"
    end

    local current = possessionByNetId[netId]
    if current and current.source ~= source then
        return false, "already_possessed"
    end

    local priorNetId = possessionBySource[source]
    if priorNetId and priorNetId ~= netId then
        EntityManager.ReleasePossession(priorNetId, "replaced")
    end

    local expiresAt = nowMs() + durationMs
    possessionByNetId[netId] = {
        source = source,
        netId = netId,
        expiresAt = expiresAt
    }
    possessionBySource[source] = netId

    local player = HC.PlayerManager.GetPlayer(source)
    if player then
        HC.DB.execute([[
            INSERT INTO owned_entities (citizenid, entity_type, net_id, metadata)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE net_id = VALUES(net_id), metadata = VALUES(metadata), updated_at = CURRENT_TIMESTAMP
        ]], {
            player.citizenid,
            "possessed",
            netId,
            Utils.SafeJsonEncode({ expiresAt = expiresAt }, "{}")
        })
    end

    TriggerClientEvent("haunted:client:entityPossession", source, {
        netId = netId,
        durationMs = durationMs
    })

    return true
end

function EntityManager.ReleasePossession(netId, reason)
    netId = tonumber(netId or 0)
    if netId <= 0 then
        return false
    end

    local possession = possessionByNetId[netId]
    if not possession then
        return false
    end

    possessionByNetId[netId] = nil
    if possessionBySource[possession.source] == netId then
        possessionBySource[possession.source] = nil
    end

    TriggerClientEvent("haunted:client:entityPossessionEnded", possession.source, {
        netId = netId,
        reason = reason or "released"
    })

    return true
end

function EntityManager.HauntEntity(source, netId, durationMs, intensity)
    source = tonumber(source or 0)
    netId = tonumber(netId or 0)
    durationMs = tonumber(durationMs or 0)
    intensity = tonumber(intensity or 1.0)

    if source <= 0 or netId <= 0 or durationMs <= 0 then
        return false, "invalid_params"
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) then
        return false, "invalid_entity"
    end

    hauntedByNetId[netId] = {
        source = source,
        intensity = intensity,
        expiresAt = nowMs() + durationMs
    }

    local player = HC.PlayerManager.GetPlayer(source)
    if player then
        HC.DB.execute([[
            INSERT INTO owned_entities (citizenid, entity_type, net_id, metadata)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE net_id = VALUES(net_id), metadata = VALUES(metadata), updated_at = CURRENT_TIMESTAMP
        ]], {
            player.citizenid,
            "haunted",
            netId,
            Utils.SafeJsonEncode({ intensity = intensity, durationMs = durationMs }, "{}")
        })
    end

    TriggerClientEvent("haunted:client:hauntStarted", -1, {
        source = source,
        netId = netId,
        intensity = intensity,
        durationMs = durationMs
    })

    return true
end

AddEventHandler("playerDropped", function()
    local source = source
    local netId = possessionBySource[source]
    if netId then
        EntityManager.ReleasePossession(netId, "owner_dropped")
    end
end)
