HauntedCore = HauntedCore or {}
HauntedCore.Utils = HauntedCore.Utils or {}

local Utils = HauntedCore.Utils

local TOKEN_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

function Utils.NowMs()
    return GetGameTimer()
end

function Utils.SafeJsonDecode(raw, fallback)
    if type(raw) ~= "string" or raw == "" then
        return fallback
    end

    local ok, decoded = pcall(json.decode, raw)
    if not ok then
        return fallback
    end

    return decoded
end

function Utils.DeepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    if seen and seen[value] then
        return seen[value]
    end

    local copy = {}
    seen = seen or {}
    seen[value] = copy

    for k, v in pairs(value) do
        copy[Utils.DeepCopy(k, seen)] = Utils.DeepCopy(v, seen)
    end

    return copy
end

function Utils.DeepEqual(a, b)
    if a == b then
        return true
    end

    if type(a) ~= type(b) then
        return false
    end

    if type(a) ~= "table" then
        return false
    end

    for k, v in pairs(a) do
        if not Utils.DeepEqual(v, b[k]) then
            return false
        end
    end

    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end

    return true
end

function Utils.GetIdentifierByType(source, wantedType)
    wantedType = tostring(wantedType)
    local identifiers = GetPlayerIdentifiers(source)
    local prefix = wantedType .. ":"

    for i = 1, #identifiers do
        local identifier = identifiers[i]
        if identifier:sub(1, #prefix) == prefix then
            return identifier
        end
    end

    return nil
end

function Utils.GetPrimaryIdentifier(source)
    return Utils.GetIdentifierByType(source, "license")
        or Utils.GetIdentifierByType(source, "fivem")
        or Utils.GetIdentifierByType(source, "discord")
        or ("player:%s"):format(tostring(source))
end

function Utils.CreateCitizenId(seed)
    local base = tostring(seed or "unknown")
    local hash = 2166136261

    for i = 1, #base do
        hash = (hash ~ string.byte(base, i)) * 16777619
        hash = hash & 0xFFFFFFFF
    end

    return ("HC%08X"):format(hash)
end

function Utils.RandomToken(length)
    local n = tonumber(length) or 32
    if n < 8 then
        n = 8
    end

    local output = {}
    local maxIndex = #TOKEN_CHARS

    for i = 1, n do
        local idx = math.random(1, maxIndex)
        output[i] = TOKEN_CHARS:sub(idx, idx)
    end

    return table.concat(output)
end

function Utils.SecureCompare(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then
        return false
    end

    if #a ~= #b then
        return false
    end

    local diff = 0
    for i = 1, #a do
        diff = diff | (string.byte(a, i) ~ string.byte(b, i))
    end

    return diff == 0
end

function Utils.NormalizeCount(value)
    local count = math.floor(tonumber(value) or 0)
    return count
end

function Utils.Clamp(value, min, max)
    if value < min then
        return min
    end
    if value > max then
        return max
    end
    return value
end
