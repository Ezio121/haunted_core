HauntedCore = HauntedCore or {}
HauntedCore.Client = HauntedCore.Client or {}

local HC = HauntedCore
local Constants = HC.Constants

local function notify(text)
    if HauntedCore.Notifications and HauntedCore.Notifications.Push then
        HauntedCore.Notifications.Push({
            type = "info",
            title = "Ability",
            description = tostring(text),
            icon = "sigil"
        })
        return
    end

    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, false)
end

local function hasSecurityToken()
    return type(HC.Client.GetSecurityToken) == "function" and HC.Client.GetSecurityToken() ~= nil
end

local function triggerAbility(ability, extra)
    if not hasSecurityToken() then
        notify("Ability request blocked: token sync pending.")
        return
    end

    local payload = {
        ability = ability
    }

    if type(extra) == "table" then
        for k, v in pairs(extra) do
            payload[k] = v
        end
    end

    TriggerServerEvent(Constants.EVENTS.REQUEST_ABILITY, HC.Client.BuildSecurePayload(payload))
end

local function rotationToDirection(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local cosX = math.cos(x)
    return {
        x = -math.sin(z) * cosX,
        y = math.cos(z) * cosX,
        z = math.sin(x)
    }
end

local function raycastEntity(distance)
    local camRot = GetGameplayCamRot(2)
    local camPos = GetGameplayCamCoord()
    local direction = rotationToDirection(camRot)

    local destination = vector3(
        camPos.x + direction.x * distance,
        camPos.y + direction.y * distance,
        camPos.z + direction.z * distance
    )

    local ray = StartShapeTestRay(
        camPos.x, camPos.y, camPos.z,
        destination.x, destination.y, destination.z,
        -1,
        PlayerPedId(),
        0
    )

    local _, hit, _, _, entity = GetShapeTestResult(ray)
    if hit == 1 and entity and entity ~= 0 then
        return entity
    end

    return nil
end

RegisterCommand("hc_phase", function()
    triggerAbility("phase_through_walls")
end, false)
RegisterKeyMapping("hc_phase", "Haunted Core: Phase Through Walls", "keyboard", Config.Client.abilityKeys.phase_through_walls or "F6")

RegisterCommand("hc_invis", function()
    triggerAbility("invisibility")
end, false)
RegisterKeyMapping("hc_invis", "Haunted Core: Invisibility", "keyboard", Config.Client.abilityKeys.invisibility or "F7")

RegisterCommand("hc_possess", function()
    local entity = raycastEntity(12.0)
    if not entity then
        notify("No valid target for possession.")
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId == 0 then
        notify("Target is not networked.")
        return
    end

    triggerAbility("object_possession", {
        targetNetId = netId
    })
end, false)
RegisterKeyMapping("hc_possess", "Haunted Core: Possess Target", "keyboard", Config.Client.abilityKeys.object_possession or "F8")

RegisterCommand("hc_haunt", function()
    local entity = raycastEntity(15.0)
    if not entity then
        notify("No entity selected to haunt.")
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId == 0 then
        notify("Target is not networked.")
        return
    end

    triggerAbility("haunt_entities", {
        targetNetId = netId
    })
end, false)
RegisterKeyMapping("hc_haunt", "Haunted Core: Haunt Entity", "keyboard", Config.Client.abilityKeys.haunt_entities or "F9")

RegisterCommand("spiritwhisper", function(_, args)
    local message = table.concat(args, " ")
    if message == "" then
        notify("Usage: /spiritwhisper <message>")
        return
    end
    triggerAbility("spirit_whisper", {
        message = message
    })
end, false)

CreateThread(function()
    TriggerEvent("chat:addSuggestion", "/spiritwhisper", "Send a ghost whisper to nearby players", {
        { name = "message", help = "Message to whisper from beyond" }
    })
end)
