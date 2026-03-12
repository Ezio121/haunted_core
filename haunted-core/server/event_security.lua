HauntedCore = HauntedCore or {}
HauntedCore.EventSecurity = HauntedCore.EventSecurity or {}

local HC = HauntedCore
local EventSecurity = HC.EventSecurity
local Utils = HC.Utils
local Constants = HC.Constants

local tokens = {}
local invalidAttempts = {}
local eventBuckets = {}
local globalBuckets = {}
local massBuckets = {}
local initialized = false

local function currentMs()
    return Utils.NowMs()
end

local function resetSourceState(source)
    tokens[source] = nil
    invalidAttempts[source] = nil
    eventBuckets[source] = nil
    globalBuckets[source] = nil
    massBuckets[source] = nil
end

local function hitRateBucket(bucket, limit, windowMs)
    local now = currentMs()
    if now >= bucket.resetAt then
        bucket.count = 0
        bucket.resetAt = now + windowMs
    end

    bucket.count = bucket.count + 1
    return bucket.count <= limit
end

local function getEventBucket(source, eventName, windowMs)
    local byEvent = eventBuckets[source]
    if not byEvent then
        byEvent = {}
        eventBuckets[source] = byEvent
    end

    local bucket = byEvent[eventName]
    if not bucket then
        bucket = {
            count = 0,
            resetAt = currentMs() + windowMs
        }
        byEvent[eventName] = bucket
    end

    return bucket
end

local function getGlobalBucket(source, windowMs)
    local bucket = globalBuckets[source]
    if not bucket then
        bucket = {
            count = 0,
            resetAt = currentMs() + windowMs
        }
        globalBuckets[source] = bucket
    end
    return bucket
end

local function registerInvalidAttempt(source, reason)
    invalidAttempts[source] = (invalidAttempts[source] or 0) + 1
    local attempts = invalidAttempts[source]
    local maxAttempts = Config.Security.maxInvalidAttempts or 6

    HC.LogAudit("security_invalid_attempt", source, nil, {
        reason = reason,
        attempts = attempts
    })

    if HC.AntiExploit then
        HC.AntiExploit.Flag(source, ("security_invalid:%s"):format(reason or "unknown"), 8)
    end

    if attempts >= maxAttempts then
        HC.PlayerManager.DropPlayer(source, "Haunted Core Security: invalid network payload")
    end
end

local function checkMassTrigger(source)
    local cfg = Config.Security.massTriggerProtection or {}
    local burstWindowMs = tonumber(cfg.burstWindowMs) or 750
    local burstLimit = tonumber(cfg.burstLimit) or 18
    local strikeKick = tonumber(cfg.strikeKick) or 4
    local now = currentMs()

    local bucket = massBuckets[source]
    if not bucket then
        bucket = {
            windowStart = now,
            count = 0,
            strikes = 0
        }
        massBuckets[source] = bucket
    end

    if now - bucket.windowStart > burstWindowMs then
        bucket.windowStart = now
        bucket.count = 0
    end

    bucket.count = bucket.count + 1
    if bucket.count <= burstLimit then
        return true
    end

    bucket.strikes = bucket.strikes + 1
    bucket.count = 0
    bucket.windowStart = now

    HC.LogAudit("event_spam_attempt", source, nil, {
        strikes = bucket.strikes,
        reason = "mass_trigger"
    })

    if HC.AntiExploit then
        HC.AntiExploit.Flag(source, "security_mass_trigger", 18)
    end

    if bucket.strikes >= strikeKick then
        HC.PlayerManager.DropPlayer(source, "Haunted Core Security: mass trigger detection")
        return false
    end

    return false
end

local function checkRateLimit(source, eventName, options)
    local defaults = Config.Security.defaultEventRateLimit or {}
    local rateCfg = options and options.rateLimit or defaults
    local eventLimit = tonumber(rateCfg.limit) or 12
    local eventWindow = tonumber(rateCfg.windowMs) or 1500

    local globalCfg = Config.Security.globalRateLimit or {}
    local globalLimit = tonumber(globalCfg.limit) or 45
    local globalWindow = tonumber(globalCfg.windowMs) or 3000

    local eventBucket = getEventBucket(source, eventName, eventWindow)
    if not hitRateBucket(eventBucket, eventLimit, eventWindow) then
        HC.LogAudit("event_spam_attempt", source, nil, {
            event = eventName,
            reason = "event_rate_limit"
        })
        if HC.AntiExploit then
            HC.AntiExploit.Flag(source, ("event_rate:%s"):format(eventName), 10)
        end
        return false, "event_rate_limit"
    end

    local globalBucket = getGlobalBucket(source, globalWindow)
    if not hitRateBucket(globalBucket, globalLimit, globalWindow) then
        HC.LogAudit("event_spam_attempt", source, nil, {
            event = eventName,
            reason = "global_rate_limit"
        })
        if HC.AntiExploit then
            HC.AntiExploit.Flag(source, "global_rate_limit", 12)
        end
        return false, "global_rate_limit"
    end

    if not checkMassTrigger(source) then
        return false, "mass_trigger"
    end

    return true
end

local function sanitizeRequestPayload(payload)
    if type(payload) ~= "table" then
        return nil
    end
    return payload.data
end

function EventSecurity.GenerateToken(source)
    source = tonumber(source or 0)
    if source <= 0 then
        return nil
    end

    local token = Utils.RandomToken(Config.Security.tokenLength or 48)
    tokens[source] = token
    invalidAttempts[source] = 0
    TriggerClientEvent(Constants.EVENTS.SECURITY_TOKEN, source, token)
    return token
end

function EventSecurity.InvalidateToken(source)
    source = tonumber(source or 0)
    if source <= 0 then
        return
    end
    resetSourceState(source)
end

function EventSecurity.GetToken(source)
    return tokens[tonumber(source or 0)]
end

function EventSecurity.ValidateRequest(source, eventName, payload, options)
    source = tonumber(source or 0)
    if source <= 0 then
        return false, nil, "invalid_source"
    end

    if type(payload) ~= "table" then
        registerInvalidAttempt(source, "payload_not_table")
        return false, nil, "invalid_payload"
    end

    local token = payload.token
    local expected = tokens[source]
    if not expected or not Utils.SecureCompare(expected, token or "") then
        registerInvalidAttempt(source, "invalid_token")
        return false, nil, "invalid_token"
    end

    local passRate, rateReason = checkRateLimit(source, eventName, options)
    if not passRate then
        HC.LogAudit("event_spam_attempt", source, nil, {
            event = eventName,
            reason = rateReason
        })
        return false, nil, rateReason
    end

    local data = sanitizeRequestPayload(payload)
    if options and type(options.sanityCheck) == "function" then
        local ok, reason = options.sanityCheck(source, data)
        if not ok then
            registerInvalidAttempt(source, reason or "sanity_check_failed")
            return false, nil, reason or "sanity_check_failed"
        end
    end

    if options and options.permission then
        if not HC.Permissions.HasPermission(source, options.permission) then
            registerInvalidAttempt(source, "permission_denied")
            return false, nil, "permission_denied"
        end
    end

    return true, data, nil
end

function EventSecurity.RegisterSecureNetEvent(eventName, callback, options)
    if type(eventName) ~= "string" or type(callback) ~= "function" then
        error("RegisterSecureNetEvent requires event name and callback")
    end

    RegisterNetEvent(eventName, function(payload)
        local src = source
        local ok, data = EventSecurity.ValidateRequest(src, eventName, payload, options)
        if not ok then
            return
        end

        local success, err = xpcall(function()
            callback(src, data)
        end, debug.traceback)

        if not success then
            print(("[HauntedCore] Secure event error (%s): %s"):format(eventName, err))
            HC.LogAudit("secure_event_runtime_error", src, nil, {
                event = eventName,
                error = tostring(err)
            })
            if HC.AntiExploit then
                HC.AntiExploit.Flag(src, "secure_event_runtime_error", 6)
            end
        end
    end)
end

function EventSecurity.Init()
    if initialized then
        return
    end
    initialized = true

    RegisterNetEvent(Constants.EVENTS.REQUEST_TOKEN, function()
        local src = source
        if HC.PlayerManager.GetPlayer(src) then
            EventSecurity.GenerateToken(src)
        end
    end)

    local rotationMs = tonumber(Config.Security.tokenRotationIntervalMs) or 900000
    CreateThread(function()
        while true do
            Wait(rotationMs)
            local players = GetPlayers()
            for i = 1, #players do
                local src = tonumber(players[i])
                if src and src > 0 then
                    EventSecurity.GenerateToken(src)
                end
            end
        end
    end)
end

_G.RegisterSecureNetEvent = EventSecurity.RegisterSecureNetEvent

AddEventHandler("playerDropped", function()
    EventSecurity.InvalidateToken(source)
end)
