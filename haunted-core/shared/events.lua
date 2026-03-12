HauntedCore = HauntedCore or {}
HauntedCore.Events = HauntedCore.Events or {}

local EventBus = HauntedCore.Events
local handlers = {}
local nextToken = 0

function EventBus.On(eventName, callback)
    if type(eventName) ~= "string" or type(callback) ~= "function" then
        return nil
    end

    nextToken = nextToken + 1
    local token = nextToken
    local bucket = handlers[eventName]

    if not bucket then
        bucket = {}
        handlers[eventName] = bucket
    end

    bucket[token] = callback
    return token
end

function EventBus.Off(eventName, token)
    local bucket = handlers[eventName]
    if not bucket then
        return false
    end

    if bucket[token] == nil then
        return false
    end

    bucket[token] = nil
    return true
end

function EventBus.Emit(eventName, ...)
    local bucket = handlers[eventName]
    if not bucket then
        return 0
    end

    local fired = 0
    for token, callback in pairs(bucket) do
        local ok, err = pcall(callback, ...)
        if ok then
            fired = fired + 1
        else
            print(("[HauntedCore] EventBus callback error (%s/%s): %s"):format(eventName, token, err))
        end
    end

    return fired
end
