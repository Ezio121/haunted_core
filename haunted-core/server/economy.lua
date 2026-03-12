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
local accountLocks = {}

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

local function accountColumn(account)
    if account == Constants.ACCOUNTS.CASH then
        return "cash"
    elseif account == Constants.ACCOUNTS.BANK then
        return "bank"
    elseif account == Constants.ACCOUNTS.SPIRIT then
        return "spirit_energy"
    end
    return nil
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
        HC.LogAudit("invalid_money_mutation", source, nil, {
            reason = "amount_not_positive",
            amount = amount,
            context = context
        })
        return false, "invalid_amount"
    end

    if normalized > maxTransaction then
        HC.LogAudit("invalid_money_mutation", source, nil, {
            reason = "amount_above_max",
            amount = normalized,
            context = context
        })
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

local function withAccountLock(source, fn)
    if accountLocks[source] then
        return false, "account_locked"
    end

    accountLocks[source] = true
    local ok, resultA, resultB = xpcall(fn, debug.traceback)
    accountLocks[source] = nil

    if not ok then
        print(("[HauntedCore][Economy] account lock failure for %s: %s"):format(source, resultA))
        return false, "runtime_error"
    end

    return resultA, resultB
end

local function setMemoryBalance(player, account, value)
    local accounts = ensureAccounts(player)
    accounts[account] = value
    if player._dirty then
        player._dirty.accounts = true
    end
end

local function fetchBalanceFromDb(citizenId, account)
    local column = accountColumn(account)
    if not column then
        return nil
    end

    local sql = ("SELECT %s AS balance FROM player_accounts WHERE citizenid = ? LIMIT 1"):format(column)
    local value = HC.DB.scalar(sql, { citizenId })
    return tonumber(value) or 0
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
    local cached = tonumber(accounts[account]) or 0
    if cached > 0 then
        return cached
    end

    local dbBalance = fetchBalanceFromDb(player.citizenid, account)
    if dbBalance then
        accounts[account] = dbBalance
        return dbBalance
    end

    return cached
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

    if not HC.DB.BackendAvailable() then
        local accounts = ensureAccounts(player)
        accounts[account] = (accounts[account] or 0) + normalizedAmount
        setMemoryBalance(player, account, accounts[account])
        syncAccountStateBag(source, account, accounts[account])
        pushMoneyUpdate(source, account, accounts[account], reason or "add")
        return true, accounts[account]
    end

    local column = accountColumn(account)
    local ok, newBalance = withAccountLock(source, function()
        local updated = HC.DB.update(
            ("UPDATE player_accounts SET %s = %s + ?, updated_at = CURRENT_TIMESTAMP WHERE citizenid = ?"):format(column, column),
            { normalizedAmount, player.citizenid }
        )
        if tonumber(updated) <= 0 then
            HC.DB.execute(
                "INSERT INTO player_accounts (citizenid, cash, bank, spirit_energy) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP",
                { player.citizenid, 0, 0, 0 }
            )
            updated = HC.DB.update(
                ("UPDATE player_accounts SET %s = %s + ?, updated_at = CURRENT_TIMESTAMP WHERE citizenid = ?"):format(column, column),
                { normalizedAmount, player.citizenid }
            )
            if tonumber(updated) <= 0 then
                return false, "db_update_failed"
            end
        end

        local balance = fetchBalanceFromDb(player.citizenid, account)
        setMemoryBalance(player, account, balance)
        return true, balance
    end)

    if not ok then
        return false, newBalance
    end

    if normalizedAmount > (maxTransaction * 0.5) then
        HC.LogAudit("high_value_money_add", source, player.citizenid, {
            account = account,
            amount = normalizedAmount,
            reason = reason
        })
    end

    syncAccountStateBag(source, account, newBalance)
    pushMoneyUpdate(source, account, newBalance, reason or "add")
    HC.Events.Emit("economy:changed", source, account, newBalance, normalizedAmount, "add")
    return true, newBalance
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

    if not HC.DB.BackendAvailable() then
        local accounts = ensureAccounts(player)
        local current = tonumber(accounts[account]) or 0
        if current < normalizedAmount then
            return false, "insufficient_funds"
        end
        accounts[account] = current - normalizedAmount
        setMemoryBalance(player, account, accounts[account])
        syncAccountStateBag(source, account, accounts[account])
        pushMoneyUpdate(source, account, accounts[account], reason or "remove")
        return true, accounts[account]
    end

    local column = accountColumn(account)
    local ok, newBalance = withAccountLock(source, function()
        local updated = HC.DB.update(
            ("UPDATE player_accounts SET %s = %s - ?, updated_at = CURRENT_TIMESTAMP WHERE citizenid = ? AND %s >= ?"):format(column, column, column),
            { normalizedAmount, player.citizenid, normalizedAmount }
        )

        if tonumber(updated) <= 0 then
            return false, "insufficient_funds"
        end

        local balance = fetchBalanceFromDb(player.citizenid, account)
        setMemoryBalance(player, account, balance)
        return true, balance
    end)

    if not ok then
        if newBalance == "insufficient_funds" then
            HC.LogAudit("invalid_money_mutation", source, player.citizenid, {
                account = account,
                attempted_remove = normalizedAmount,
                reason = "insufficient_funds"
            })
        end
        return false, newBalance
    end

    syncAccountStateBag(source, account, newBalance)
    pushMoneyUpdate(source, account, newBalance, reason or "remove")
    HC.Events.Emit("economy:changed", source, account, newBalance, normalizedAmount, "remove")
    return true, newBalance
end

function Economy.SetMoney(source, account, amount, reason)
    account = tostring(account or "")
    local newAmount = Utils.NormalizeCount(amount)
    if not isValidAccount(account) then
        return false, "invalid_account"
    end

    if newAmount < 0 then
        HC.LogAudit("invalid_money_mutation", source, nil, {
            account = account,
            amount = newAmount,
            reason = "negative_balance_attempt"
        })
        return false, "negative_not_allowed"
    end

    local player = HC.PlayerManager.GetPlayer(source)
    if not player then
        return false, "player_not_found"
    end

    if not HC.DB.BackendAvailable() then
        setMemoryBalance(player, account, newAmount)
        syncAccountStateBag(source, account, newAmount)
        pushMoneyUpdate(source, account, newAmount, reason or "set")
        return true, newAmount
    end

    local column = accountColumn(account)
    local ok, dbResult = withAccountLock(source, function()
        local updated = HC.DB.update(
            ("UPDATE player_accounts SET %s = ?, updated_at = CURRENT_TIMESTAMP WHERE citizenid = ?"):format(column),
            { newAmount, player.citizenid }
        )
        if tonumber(updated) <= 0 then
            return false, "db_update_failed"
        end

        setMemoryBalance(player, account, newAmount)
        return true, newAmount
    end)

    if not ok then
        return false, dbResult
    end

    syncAccountStateBag(source, account, newAmount)
    pushMoneyUpdate(source, account, newAmount, reason or "set")
    return true, newAmount
end

function Economy.TransferMoney(fromSource, toSource, account, amount, reason)
    account = tostring(account or Constants.ACCOUNTS.BANK)
    local normalized = Utils.NormalizeCount(amount)
    if normalized <= 0 then
        return false, "invalid_amount"
    end

    if fromSource == toSource then
        return false, "same_source"
    end

    local fromPlayer = HC.PlayerManager.GetPlayer(fromSource)
    local toPlayer = HC.PlayerManager.GetPlayer(toSource)
    if not fromPlayer or not toPlayer then
        return false, "player_not_found"
    end

    local removed, removeReason = Economy.RemoveMoney(fromSource, account, normalized, reason or "transfer_out")
    if not removed then
        return false, removeReason
    end

    local added, addReason = Economy.AddMoney(toSource, account, normalized, reason or "transfer_in")
    if not added then
        Economy.AddMoney(fromSource, account, normalized, "transfer_rollback")
        return false, addReason
    end

    HC.LogAudit("money_transfer", fromSource, fromPlayer.citizenid, {
        target = toPlayer.citizenid,
        account = account,
        amount = normalized,
        reason = reason
    })

    return true
end

function Economy.AddSpiritEnergy(source, amount, reason)
    return Economy.AddMoney(source, Constants.ACCOUNTS.SPIRIT, amount, reason or "spirit_gain")
end

function Economy.RemoveSpiritEnergy(source, amount, reason)
    return Economy.RemoveMoney(source, Constants.ACCOUNTS.SPIRIT, amount, reason or "spirit_spend")
end
