HauntedCore = HauntedCore or {}
local HC = HauntedCore

local function GetPlayer(source)
    return HC.PlayerManager.GetPlayer(source)
end

local function GetPlayerByCitizenId(citizenId)
    return HC.PlayerManager.GetPlayerByCitizenId(citizenId)
end

local function CreatePlayer(source)
    return HC.PlayerManager.CreatePlayer(source)
end

local function SavePlayer(source)
    return HC.PlayerManager.SavePlayer(source)
end

local function DropPlayerBySource(source, reason)
    return HC.PlayerManager.DropPlayer(source, reason)
end

exports("GetPlayer", GetPlayer)
exports("GetPlayerByCitizenId", GetPlayerByCitizenId)
exports("CreatePlayer", CreatePlayer)
exports("SavePlayer", SavePlayer)
exports("DropPlayer", DropPlayerBySource)
