HauntedCore = HauntedCore or {}
HauntedCore.Economy = HauntedCore.Economy or {}

local HC = HauntedCore
local Economy = HC.Economy
local Utils = HC.Utils
local Constants = HC.Constants

local defaultAccounts = Utils.DeepCopy(Config.Economy.startingAccounts or {
    cash = 0,
    bank = 0,
    spirit_energy = 0
})
local maxTransaction = tonumber(Config.Economy.maxTransaction) or 1000000

local function isValidAccount(account)
    return defaultAccounts[account] ~= nil
end

local function ensureAccounts(player)
    player.accounts = player.accounts or {}
    for account, value in pairs(defaultAccounts) do
        if player.accounts[account] == nil then
            player.accounts[account] = value
        end
    end
    return player.accounts
end

local function syncAccountStateBag(source, account, balance)
    local playerRef = Player(source)
    if playerRef then
        playerRef.state:set(("account:%s"):format(account), balance, true)
    end
end

local function validateAmount(source, amount, context)
    local normalized = Utils.NormalizeCount(amount)
    if normalized <= 0 then
        return false, "invalid_amount"
    end

    if normalized > maxTransaction then
        if HC.AntiExploit then
            HC.AntiExploit.Flag(source, ("economy_overflow:%s"):format(context or "unknown"), 30)
        end
        return false, "above_max_transaction"
    end

    return true, normalized
end

local function pushMoneyUpdate(source, account, balance, reason)
    TriggerClientEvent(Constants.EVENTS.MONEY_SYNC, source, {
        account = account,
        balance = balance,
        reason = reason
    })
end

function Economy.Init()
    return true
end

function Economy.InitializePlayer(source)
    local player = HC.PlayerManager.GetPlayer(source)
    if not player then
        return false, "player_not_found"
    end

    local accounts = ensureAccounts(player)
    for account, balance in pairs(accounts) do
        syncAccountStateBag(source, account, balance)
    end

    return true
end

function Economy.GetMoney(source, account)
    account = tostring(account or "")
    local player = HC.PlayerManager.GetPlayer(source)
    if not player then
        return 0
    end

    local accounts = ensureAccounts(player)
    return accounts[account] or 0
end

function Economy.AddMoney(source, account, amount, reason)
    account = tostring(account or "")
    if not isValidAccount(account) then
        return false, "invalid_account"
    end

    local player = HC.PlayerManager.GetPlayer(source)
    if not player then
        return false, "player_not_found"
    end

    local valid, normalizedAmount = validateAmount(source, amount, "add")
    if not valid then
        return false, normalizedAmount
    end

    local accounts = ensureAccounts(player)
    accounts[account] = (accounts[account] or 0) + normalizedAmount
    syncAccountStateBag(source, account, accounts[account])
    pushMoneyUpdate(source, account, accounts[account], reason or "add")
    HC.Events.Emit("economy:changed", source, account, accounts[account], normalizedAmount, "add")
    return true, accounts[account]
end

function Economy.RemoveMoney(source, account, amount, reason)
    account = tostring(account or "")
    if not isValidAccount(account) then
        return false, "invalid_account"
    end

    local player = HC.PlayerManager.GetPlayer(source)
    if not player then
        return false, "player_not_found"
    end

    local valid, normalizedAmount = validateAmount(source, amount, "remove")
    if not valid then
        return false, normalizedAmount
    end

    local accounts = ensureAccounts(player)
    local current = accounts[account] or 0
    if current < normalizedAmount then
        return false, "insufficient_funds"
    end

    accounts[account] = current - normalizedAmount
    syncAccountStateBag(source, account, accounts[account])
    pushMoneyUpdate(source, account, accounts[account], reason or "remove")
    HC.Events.Emit("economy:changed", source, account, accounts[account], normalizedAmount, "remove")
    return true, accounts[account]
end

function Economy.AddSpiritEnergy(source, amount, reason)
    return Economy.AddMoney(source, Constants.ACCOUNTS.SPIRIT, amount, reason or "spirit_gain")
end
