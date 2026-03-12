HauntedCore = HauntedCore or {}
local HC = HauntedCore

function GetPlayer(source)
    return HC.PlayerManager.GetPlayer(source)
end

function GetPlayerByCitizenId(citizenId)
    return HC.PlayerManager.GetPlayerByCitizenId(citizenId)
end

function CreatePlayer(source)
    return HC.PlayerManager.CreatePlayer(source)
end

function SavePlayer(source)
    return HC.PlayerManager.SavePlayer(source)
end

function DropPlayerBySource(source, reason)
    return HC.PlayerManager.DropPlayer(source, reason)
end

exports("GetPlayer", GetPlayer)
exports("GetPlayerByCitizenId", GetPlayerByCitizenId)
exports("CreatePlayer", CreatePlayer)
exports("SavePlayer", SavePlayer)
exports("DropPlayer", DropPlayerBySource)
