HauntedCore = HauntedCore or {}
local HC = HauntedCore

local function AddMoney(source, account, amount, reason)
    return HC.Economy.AddMoney(source, account, amount, reason)
end

local function RemoveMoney(source, account, amount, reason)
    return HC.Economy.RemoveMoney(source, account, amount, reason)
end

local function SetMoney(source, account, amount, reason)
    return HC.Economy.SetMoney(source, account, amount, reason)
end

local function TransferMoney(fromSource, toSource, account, amount, reason)
    return HC.Economy.TransferMoney(fromSource, toSource, account, amount, reason)
end

local function GetMoney(source, account)
    return HC.Economy.GetMoney(source, account)
end

local function AddSpiritEnergy(source, amount, reason)
    return HC.Economy.AddSpiritEnergy(source, amount, reason)
end

local function RemoveSpiritEnergy(source, amount, reason)
    return HC.Economy.RemoveSpiritEnergy(source, amount, reason)
end

exports("AddMoney", AddMoney)
exports("RemoveMoney", RemoveMoney)
exports("SetMoney", SetMoney)
exports("TransferMoney", TransferMoney)
exports("GetMoney", GetMoney)
exports("AddSpiritEnergy", AddSpiritEnergy)
exports("RemoveSpiritEnergy", RemoveSpiritEnergy)
