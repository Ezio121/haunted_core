HauntedCore = HauntedCore or {}
local HC = HauntedCore

function AddMoney(source, account, amount, reason)
    return HC.Economy.AddMoney(source, account, amount, reason)
end

function RemoveMoney(source, account, amount, reason)
    return HC.Economy.RemoveMoney(source, account, amount, reason)
end

function GetMoney(source, account)
    return HC.Economy.GetMoney(source, account)
end

function AddSpiritEnergy(source, amount, reason)
    return HC.Economy.AddSpiritEnergy(source, amount, reason)
end

exports("AddMoney", AddMoney)
exports("RemoveMoney", RemoveMoney)
exports("GetMoney", GetMoney)
exports("AddSpiritEnergy", AddSpiritEnergy)
