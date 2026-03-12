HauntedCore = HauntedCore or {}
HauntedCore.Client = HauntedCore.Client or {}

local HC = HauntedCore
local Client = HC.Client
local Constants = HC.Constants

local securityToken = nil

function Client.GetSecurityToken()
    return securityToken
end

function Client.BuildSecurePayload(data)
    return {
        token = securityToken,
        data = data
    }
end

local function requestToken()
    TriggerServerEvent(Constants.EVENTS.REQUEST_TOKEN)
end

RegisterNetEvent(Constants.EVENTS.SECURITY_TOKEN, function(token)
    if type(token) ~= "string" or token == "" then
        return
    end
    securityToken = token
end)

AddEventHandler("playerSpawned", function()
    requestToken()
end)

AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    Wait(500)
    requestToken()
end)

CreateThread(function()
    while true do
        Wait(10000)
        if not securityToken then
            requestToken()
        end
    end
end)
