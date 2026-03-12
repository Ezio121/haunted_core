HauntedCore = HauntedCore or {}

local HC = HauntedCore
HC.Config = Config or {}
HC.Version = HC.Constants and HC.Constants.VERSION or "1.0.0"

HC.Player = HC.Player or {}
HC.Ghost = HC.Ghost or {}
HC.Security = HC.Security or {}
HC.Economy = HC.Economy or {}
HC.Inventory = HC.Inventory or {}
HC.Permissions = HC.Permissions or {}

function HC.IsServer()
    return IsDuplicityVersion()
end

function HC.GetPlayer(source)
    if HC.PlayerManager and HC.PlayerManager.GetPlayer then
        return HC.PlayerManager.GetPlayer(source)
    end
    return nil
end

function HC.GetPlayerByCitizenId(citizenId)
    if HC.PlayerManager and HC.PlayerManager.GetPlayerByCitizenId then
        return HC.PlayerManager.GetPlayerByCitizenId(citizenId)
    end
    return nil
end

function HC.DebugLog(message, ...)
    local cfg = HC.Config and HC.Config.Core
    if not cfg or not cfg.debug then
        return
    end

    local text = "[HauntedCore] " .. tostring(message)
    if select("#", ...) > 0 then
        text = text:format(...)
    end
    print(text)
end
