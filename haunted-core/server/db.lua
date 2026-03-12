HauntedCore = HauntedCore or {}
HauntedCore.DB = HauntedCore.DB or {}

local HC = HauntedCore
local DB = HC.DB
local Utils = HC.Utils

local initialized = false
local readyState = false
local readyCallbacks = {}
local lastError = nil

local backend = {
    name = "none",
    available = false,
    reason = "not_initialized"
}

local defaultResult = {
    scalar = nil,
    single = nil,
    query = {},
    insert = 0,
    update = 0,
    execute = 0,
    prepare = {},
    transaction = false
}

local resourceName = GetCurrentResourceName()
local NATIVE_REQUEST_EVENT = "haunted:db:node:request"
local NATIVE_RESPONSE_EVENT = "haunted:db:node:response"
local nativeRequestTimeoutMs = 15000
local nativeRequestId = 0
local nativePending = {}

local standalone = {
    fileName = "standalone_db.json",
    loaded = false,
    dirty = false,
    tables = {},
    meta = {
        autoIncrement = {}
    }
}

local standaloneTableSchema = {
    users = {
        auto = "id",
        unique = {
            { "license" },
            { "citizenid" }
        }
    },
    player_accounts = {
        unique = {
            { "citizenid" }
        }
    },
    player_inventory = {
        unique = {
            { "citizenid" }
        }
    },
    player_metadata = {
        unique = {
            { "citizenid" }
        }
    },
    player_permissions = {
        auto = "id",
        unique = {
            { "identifier", "permission" }
        }
    },
    ghost_states = {
        unique = {
            { "citizenid" }
        }
    },
    jobs = {
        auto = "id",
        unique = {
            { "name" }
        }
    },
    job_grades = {
        auto = "id",
        unique = {
            { "job_name", "grade" }
        }
    },
    owned_entities = {
        auto = "id",
        unique = {
            { "citizenid", "entity_type" }
        }
    },
    audit_logs = {
        auto = "id"
    },
    server_kvp = {
        unique = {
            { "kvp_key" }
        }
    },
    hc_schema_migrations = {
        auto = "id",
        unique = {
            { "name" }
        }
    }
}

local function dbDebugEnabled()
    return Config.Database and Config.Database.Debug
end

local function log(level, message, ...)
    print(("[HauntedDB][%s] " .. tostring(message)):format(level, ...))
end

local function debugLog(message, ...)
    if dbDebugEnabled() then
        log("DEBUG", message, ...)
    end
end

local function trim(value)
    if type(value) ~= "string" then
        return value
    end
    return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function nowTimestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local function resourceExists(resource)
    local count = GetNumResources()
    for i = 0, count - 1 do
        if GetResourceByFindIndex(i) == resource then
            return true
        end
    end
    return false
end

local function hasExternalOxmysql()
    if GetCurrentResourceName() == "oxmysql" then
        return false
    end

    if not resourceExists("oxmysql") then
        return false
    end

    local state = GetResourceState("oxmysql")
    return state == "starting" or state == "started"
end

local function normalizeParams(params)
    return Utils.NormalizeDbParams(params)
end

AddEventHandler(NATIVE_RESPONSE_EVENT, function(requestId, ok, result, err)
    requestId = tonumber(requestId)
    if not requestId then
        return
    end

    local pending = nativePending[requestId]
    if not pending then
        return
    end

    nativePending[requestId] = nil
    pending.ok = ok == true
    pending.result = result
    pending.err = err
    pending.promise:resolve(true)
end)

local function callNativeBridge(action, payload, timeoutMs)
    nativeRequestId = nativeRequestId + 1
    local requestId = nativeRequestId
    local request = {
        promise = promise.new(),
        ok = false,
        result = nil,
        err = nil
    }
    nativePending[requestId] = request

    TriggerEvent(NATIVE_REQUEST_EVENT, requestId, action, payload)

    SetTimeout(timeoutMs or nativeRequestTimeoutMs, function()
        local pending = nativePending[requestId]
        if not pending then
            return
        end
        nativePending[requestId] = nil
        pending.err = "native_request_timeout"
        pending.promise:resolve(true)
    end)

    Citizen.Await(request.promise)
    if request.err then
        return nil, tostring(request.err)
    end

    if not request.ok then
        return nil, "native_request_failed"
    end

    return request.result, nil
end

local function splitCsv(text)
    local out = {}
    local buffer = {}
    local inSingle = false
    local inDouble = false
    local depth = 0

    for i = 1, #text do
        local ch = text:sub(i, i)
        if ch == "'" and not inDouble then
            inSingle = not inSingle
            buffer[#buffer + 1] = ch
        elseif ch == '"' and not inSingle then
            inDouble = not inDouble
            buffer[#buffer + 1] = ch
        elseif ch == "(" and not inSingle and not inDouble then
            depth = depth + 1
            buffer[#buffer + 1] = ch
        elseif ch == ")" and not inSingle and not inDouble and depth > 0 then
            depth = depth - 1
            buffer[#buffer + 1] = ch
        elseif ch == "," and not inSingle and not inDouble and depth == 0 then
            out[#out + 1] = trim(table.concat(buffer))
            buffer = {}
        else
            buffer[#buffer + 1] = ch
        end
    end

    if #buffer > 0 then
        out[#out + 1] = trim(table.concat(buffer))
    end

    return out
end

local function stripQuotes(value)
    if type(value) ~= "string" then
        return value
    end
    local s = trim(value)
    if #s >= 2 and s:sub(1, 1) == "'" and s:sub(-1, -1) == "'" then
        return s:sub(2, -2):gsub("''", "'")
    end
    if #s >= 2 and s:sub(1, 1) == '"' and s:sub(-1, -1) == '"' then
        return s:sub(2, -2)
    end
    return s
end

local function unquoteIdentifier(value)
    if type(value) ~= "string" then
        return value
    end
    return trim(value):gsub("`", "")
end

local function findMatchingParen(str, openPos)
    local depth = 0
    for i = openPos, #str do
        local ch = str:sub(i, i)
        if ch == "(" then
            depth = depth + 1
        elseif ch == ")" then
            depth = depth - 1
            if depth == 0 then
                return i
            end
        end
    end
    return nil
end

local function lowerSql(sql)
    return tostring(sql or ""):lower()
end

local function copyRow(row)
    return Utils.DeepCopy(row)
end

local function ensureStandaloneTable(tableName)
    if standalone.tables[tableName] == nil then
        standalone.tables[tableName] = {}
    end
    if standalone.meta.autoIncrement[tableName] == nil then
        standalone.meta.autoIncrement[tableName] = 1
    end
end

local function ensureStandaloneTables()
    for tableName in pairs(standaloneTableSchema) do
        ensureStandaloneTable(tableName)
    end
end

local function markStandaloneDirty()
    standalone.dirty = true
end

local function getUniqueDefinitions(tableName)
    local schema = standaloneTableSchema[tableName]
    if not schema then
        return {}
    end
    return schema.unique or {}
end

local function uniqueMatch(definition, rowA, rowB)
    for i = 1, #definition do
        local key = definition[i]
        if rowA[key] == nil or rowB[key] == nil then
            return false
        end
        if tostring(rowA[key]) ~= tostring(rowB[key]) then
            return false
        end
    end
    return true
end

local function findExistingRowIndex(tableName, candidate)
    local rows = standalone.tables[tableName]
    if not rows then
        return nil
    end

    local uniques = getUniqueDefinitions(tableName)
    if #uniques == 0 then
        return nil
    end

    for idx = 1, #rows do
        local existing = rows[idx]
        for u = 1, #uniques do
            if uniqueMatch(uniques[u], existing, candidate) then
                return idx
            end
        end
    end

    return nil
end

local function applyAutoIncrement(tableName, row)
    local schema = standaloneTableSchema[tableName]
    if not schema or not schema.auto then
        return
    end

    local key = schema.auto
    if row[key] ~= nil then
        local current = tonumber(row[key]) or 0
        local autoValue = standalone.meta.autoIncrement[tableName] or 1
        if current >= autoValue then
            standalone.meta.autoIncrement[tableName] = current + 1
        end
        return
    end

    row[key] = standalone.meta.autoIncrement[tableName] or 1
    standalone.meta.autoIncrement[tableName] = row[key] + 1
end

local function evaluateLiteralToken(token, paramState)
    local raw = trim(token)
    local lower = raw:lower()

    if raw == "?" then
        local value = paramState.values[paramState.index]
        paramState.index = paramState.index + 1
        return value
    end

    if raw:sub(1, 1) == "@" then
        local named = raw:sub(2)
        return paramState.values[raw] or paramState.values[named]
    end

    if raw:sub(1, 1) == ":" then
        local named = raw:sub(2)
        return paramState.values[raw] or paramState.values[named]
    end

    if lower == "null" then
        return nil
    end

    if lower == "now()" or lower == "current_timestamp" or lower == "current_timestamp()" then
        return nowTimestamp()
    end

    local num = tonumber(raw)
    if num ~= nil then
        return num
    end

    return stripQuotes(raw)
end
local function parseWhereConditions(whereClause, params)
    local conditions = {}
    local paramState = {
        values = params,
        index = 1
    }

    local clause = trim(whereClause or "")
    if clause == "" then
        return conditions
    end

    local parts = {}
    local normalized = clause:gsub("%s+[Aa][Nn][Dd]%s+", "\n")
    for segment in normalized:gmatch("[^\n]+") do
        parts[#parts + 1] = trim(segment)
    end

    for i = 1, #parts do
        local part = parts[i]
        local col, op, rhs = part:match("^`?([%w_]+)`?%s*(=|>=|<=|>|<)%s*(.+)$")
        if col and op and rhs then
            local value = evaluateLiteralToken(rhs, paramState)
            conditions[#conditions + 1] = {
                col = col,
                op = op,
                value = value
            }
        end
    end

    return conditions
end

local function compareValues(left, op, right)
    if op == "=" then
        if left == nil and right == nil then
            return true
        end
        return tostring(left) == tostring(right)
    end

    local lnum = tonumber(left)
    local rnum = tonumber(right)
    if lnum == nil or rnum == nil then
        return false
    end

    if op == ">" then
        return lnum > rnum
    elseif op == "<" then
        return lnum < rnum
    elseif op == ">=" then
        return lnum >= rnum
    elseif op == "<=" then
        return lnum <= rnum
    end

    return false
end

local function rowMatchesConditions(row, conditions)
    for i = 1, #conditions do
        local cond = conditions[i]
        if not compareValues(row[cond.col], cond.op, cond.value) then
            return false
        end
    end
    return true
end

local function parseSetAssignments(setClause)
    local assignments = {}
    local parts = splitCsv(setClause or "")
    for i = 1, #parts do
        local lhs, rhs = parts[i]:match("^`?([%w_]+)`?%s*=%s*(.+)$")
        if lhs and rhs then
            assignments[#assignments + 1] = {
                col = lhs,
                rhs = trim(rhs)
            }
        end
    end
    return assignments
end

local function evalAssignmentValue(rhs, row, insertRow, paramState)
    local lower = rhs:lower()
    local addCol = rhs:match("^`?([%w_]+)`?%s*%+%s*%?$")
    local subCol = rhs:match("^`?([%w_]+)`?%s*%-%s*%?$")

    if addCol then
        local delta = tonumber(evaluateLiteralToken("?", paramState)) or 0
        return (tonumber(row[addCol]) or 0) + delta
    end

    if subCol then
        local delta = tonumber(evaluateLiteralToken("?", paramState)) or 0
        return (tonumber(row[subCol]) or 0) - delta
    end

    local valueRef = rhs:match("^[Vv][Aa][Ll][Uu][Ee][Ss]%s*%(%s*`?([%w_]+)`?%s*%)$")
    if valueRef and insertRow then
        return insertRow[valueRef]
    end

    if lower == "now()" or lower == "current_timestamp" or lower == "current_timestamp()" then
        return nowTimestamp()
    end

    return evaluateLiteralToken(rhs, paramState)
end

local function parseInsertStatement(sql, params)
    local insertStart, insertEnd, tableName = sql:find("[Ii][Nn][Ss][Ee][Rr][Tt]%s+[Ii][Nn][Tt][Oo]%s+`?([%w_]+)`?")
    local ignore = false
    if not tableName then
        insertStart, insertEnd, tableName = sql:find("[Ii][Nn][Ss][Ee][Rr][Tt]%s+[Ii][Gg][Nn][Oo][Rr][Ee]%s+[Ii][Nn][Tt][Oo]%s+`?([%w_]+)`?")
        ignore = tableName ~= nil
    end
    if not tableName then
        return nil, "invalid_insert_statement"
    end

    local lower = lowerSql(sql)
    local valuesPos = lower:find(" values", insertEnd + 1, true)
    if not valuesPos then
        return nil, "insert_values_missing"
    end

    local colStart = sql:find("%(", insertEnd + 1)
    if not colStart or colStart > valuesPos then
        return nil, "insert_columns_missing"
    end

    local colEnd = findMatchingParen(sql, colStart)
    if not colEnd then
        return nil, "insert_columns_invalid"
    end

    local valueStart = sql:find("%(", valuesPos + 1)
    if not valueStart then
        return nil, "insert_values_paren_missing"
    end

    local valueEnd = findMatchingParen(sql, valueStart)
    if not valueEnd then
        return nil, "insert_values_invalid"
    end

    local columnsRaw = sql:sub(colStart + 1, colEnd - 1)
    local valuesRaw = sql:sub(valueStart + 1, valueEnd - 1)
    local updateClause

    local dupPos = lower:find(" on duplicate key update", valueEnd + 1, true)
    if dupPos then
        updateClause = trim(sql:sub(dupPos + #" on duplicate key update"))
    end

    local columns = splitCsv(columnsRaw)
    local values = splitCsv(valuesRaw)
    if #columns ~= #values then
        return nil, "insert_column_value_mismatch"
    end

    local paramState = {
        values = params,
        index = 1
    }

    local row = {}
    for i = 1, #columns do
        local column = unquoteIdentifier(columns[i])
        row[column] = evaluateLiteralToken(values[i], paramState)
    end

    return {
        table = tableName,
        row = row,
        ignore = ignore,
        updateClause = updateClause
    }, nil
end

local function parseSelectStatement(sql, params)
    local lower = lowerSql(sql)
    local selectPos = lower:find("select ", 1, true)
    local fromPos = lower:find(" from ", 1, true)
    if not selectPos or not fromPos then
        return nil, "invalid_select_statement"
    end

    local fieldsRaw = trim(sql:sub(selectPos + 7, fromPos - 1))
    local tableStart = fromPos + 6
    local tableName = sql:sub(tableStart):match("^`?([%w_]+)`?")
    if not tableName then
        return nil, "select_table_missing"
    end

    local whereClause
    local limitValue

    local wherePos = lower:find(" where ", tableStart, true)
    local limitPos = lower:find(" limit ", tableStart, true)

    if wherePos then
        local whereStart = wherePos + 7
        local whereEnd = limitPos and (limitPos - 1) or #sql
        whereClause = trim(sql:sub(whereStart, whereEnd))
    end

    if limitPos then
        local limitRaw = trim(sql:sub(limitPos + 7))
        limitValue = tonumber(limitRaw)
    end

    local fields = splitCsv(fieldsRaw)
    local conditions = parseWhereConditions(whereClause, params)

    return {
        table = tableName,
        fields = fields,
        conditions = conditions,
        limit = limitValue
    }, nil
end

local function parseUpdateStatement(sql, params)
    local updateStart, updateEnd, tableName = sql:find("[Uu][Pp][Dd][Aa][Tt][Ee]%s+`?([%w_]+)`?%s+[Ss][Ee][Tt]%s+")
    if not tableName then
        return nil, "invalid_update_statement"
    end

    local lower = lowerSql(sql)
    local wherePos = lower:find(" where ", updateEnd + 1, true)
    local setClause
    local whereClause
    if wherePos then
        setClause = trim(sql:sub(updateEnd + 1, wherePos - 1))
        whereClause = trim(sql:sub(wherePos + 7))
    else
        setClause = trim(sql:sub(updateEnd + 1))
    end

    local assignments = parseSetAssignments(setClause)
    local conditions = parseWhereConditions(whereClause, params)

    return {
        table = tableName,
        assignments = assignments,
        conditions = conditions,
        params = params
    }, nil
end

local function parseDeleteStatement(sql, params)
    local deleteStart, deleteEnd, tableName = sql:find("[Dd][Ee][Ll][Ee][Tt][Ee]%s+[Ff][Rr][Oo][Mm]%s+`?([%w_]+)`?")
    if not tableName then
        return nil, "invalid_delete_statement"
    end

    local lower = lowerSql(sql)
    local wherePos = lower:find(" where ", deleteEnd + 1, true)
    local whereClause
    if wherePos then
        whereClause = trim(sql:sub(wherePos + 7))
    end

    local conditions = parseWhereConditions(whereClause, params)
    return {
        table = tableName,
        conditions = conditions
    }, nil
end
local function standaloneLoad()
    if standalone.loaded then
        return
    end

    local raw = LoadResourceFile(resourceName, standalone.fileName)
    local decoded = Utils.SafeJsonDecode(raw, nil)
    if type(decoded) == "table" and type(decoded.tables) == "table" then
        standalone.tables = decoded.tables
        standalone.meta = decoded.meta or {
            autoIncrement = {}
        }
    else
        standalone.tables = {}
        standalone.meta = {
            autoIncrement = {}
        }
    end

    standalone.meta.autoIncrement = standalone.meta.autoIncrement or {}
    ensureStandaloneTables()
    standalone.loaded = true
end

local function standaloneSave(force)
    if not standalone.loaded then
        return
    end

    if not standalone.dirty and not force then
        return
    end

    local payload = Utils.SafeJsonEncode({
        tables = standalone.tables,
        meta = standalone.meta
    }, "{}")

    SaveResourceFile(resourceName, standalone.fileName, payload, -1)
    standalone.dirty = false
end

local function startStandaloneSaveThread()
    CreateThread(function()
        while true do
            Wait(2000)
            standaloneSave(false)
        end
    end)
end

local function handleStandaloneCreateTable(sql)
    local tableName = sql:match("[Tt][Aa][Bb][Ll][Ee]%s+[Ii][Ff]%s+[Nn][Oo][Tt]%s+[Ee][Xx][Ii][Ss][Tt][Ss]%s+`?([%w_]+)`?")
    if not tableName then
        tableName = sql:match("[Tt][Aa][Bb][Ll][Ee]%s+`?([%w_]+)`?")
    end
    if tableName then
        ensureStandaloneTable(tableName)
    end
    return 0
end

local function applyProjection(rows, fields)
    if #fields == 1 and trim(fields[1]) == "*" then
        local out = {}
        for i = 1, #rows do
            out[#out + 1] = copyRow(rows[i])
        end
        return out
    end

    local projected = {}
    local countRequest = nil

    for i = 1, #fields do
        local field = trim(fields[i])
        local lower = field:lower()
        if lower:match("^count%(%*%)") then
            local alias = field:match("[Aa][Ss]%s+`?([%w_]+)`?")
            countRequest = alias or "count"
        end
    end

    if countRequest then
        return {
            { [countRequest] = #rows }
        }
    end

    for i = 1, #rows do
        local source = rows[i]
        local dest = {}
        for f = 1, #fields do
            local field = trim(fields[f])
            local col, alias = field:match("^`?([%w_]+)`?%s+[Aa][Ss]%s+`?([%w_]+)`?$")
            if col then
                dest[alias] = source[col]
            else
                local plain = unquoteIdentifier(field)
                dest[plain] = source[plain]
            end
        end
        projected[#projected + 1] = dest
    end

    return projected
end

local function standaloneSelect(sql, params)
    local parsed, err = parseSelectStatement(sql, params)
    if not parsed then
        return nil, err
    end

    ensureStandaloneTable(parsed.table)
    local rows = standalone.tables[parsed.table]
    local matched = {}

    for i = 1, #rows do
        local row = rows[i]
        if rowMatchesConditions(row, parsed.conditions) then
            matched[#matched + 1] = row
            if parsed.limit and #matched >= parsed.limit then
                break
            end
        end
    end

    return applyProjection(matched, parsed.fields), nil
end

local function standaloneInsert(sql, params)
    local parsed, err = parseInsertStatement(sql, params)
    if not parsed then
        return nil, err
    end

    ensureStandaloneTable(parsed.table)
    local rows = standalone.tables[parsed.table]
    local row = parsed.row

    if row.created_at == nil then
        row.created_at = nowTimestamp()
    end
    row.updated_at = nowTimestamp()

    local existingIndex = findExistingRowIndex(parsed.table, row)
    if existingIndex then
        if parsed.ignore and not parsed.updateClause then
            return 0, nil
        end

        if parsed.updateClause and parsed.updateClause ~= "" then
            local existing = rows[existingIndex]
            local assignments = parseSetAssignments(parsed.updateClause)
            local paramState = {
                values = params,
                index = 1
            }

            for i = 1, #assignments do
                local assignment = assignments[i]
                existing[assignment.col] = evalAssignmentValue(assignment.rhs, existing, row, paramState)
            end
            existing.updated_at = nowTimestamp()
            markStandaloneDirty()
        end

        local schema = standaloneTableSchema[parsed.table]
        if schema and schema.auto and rows[existingIndex][schema.auto] then
            return tonumber(rows[existingIndex][schema.auto]) or 0, nil
        end
        return 1, nil
    end

    applyAutoIncrement(parsed.table, row)
    rows[#rows + 1] = row
    markStandaloneDirty()

    local schema = standaloneTableSchema[parsed.table]
    if schema and schema.auto and row[schema.auto] then
        return tonumber(row[schema.auto]) or 0, nil
    end
    return 1, nil
end

local function standaloneUpdate(sql, params)
    local parsed, err = parseUpdateStatement(sql, params)
    if not parsed then
        return nil, err
    end

    ensureStandaloneTable(parsed.table)
    local rows = standalone.tables[parsed.table]
    local affected = 0
    local paramState = {
        values = parsed.params,
        index = 1
    }

    for i = 1, #rows do
        local row = rows[i]
        if rowMatchesConditions(row, parsed.conditions) then
            for a = 1, #parsed.assignments do
                local assignment = parsed.assignments[a]
                row[assignment.col] = evalAssignmentValue(assignment.rhs, row, nil, paramState)
            end
            row.updated_at = nowTimestamp()
            affected = affected + 1
        end
    end

    if affected > 0 then
        markStandaloneDirty()
    end

    return affected, nil
end

local function standaloneDelete(sql, params)
    local parsed, err = parseDeleteStatement(sql, params)
    if not parsed then
        return nil, err
    end

    ensureStandaloneTable(parsed.table)
    local rows = standalone.tables[parsed.table]
    local keep = {}
    local affected = 0

    for i = 1, #rows do
        local row = rows[i]
        if rowMatchesConditions(row, parsed.conditions) then
            affected = affected + 1
        else
            keep[#keep + 1] = row
        end
    end

    if affected > 0 then
        standalone.tables[parsed.table] = keep
        markStandaloneDirty()
    end

    return affected, nil
end

local function standaloneExecute(sql, params, method)
    local lower = lowerSql(sql)
    params = normalizeParams(params)

    if lower:find("^%s*create%s+table") then
        return handleStandaloneCreateTable(sql), nil
    end

    if lower:find("^%s*alter%s+table") or lower:find("^%s*drop%s+table") then
        return 0, nil
    end

    if lower:find("^%s*insert%s+") then
        local insertResult, err = standaloneInsert(sql, params)
        if err then
            return nil, err
        end
        if method == "query" then
            return {}, nil
        end
        return insertResult, nil
    end

    if lower:find("^%s*update%s+") then
        local updateResult, err = standaloneUpdate(sql, params)
        if err then
            return nil, err
        end
        if method == "query" then
            return {}, nil
        end
        return updateResult, nil
    end

    if lower:find("^%s*delete%s+") then
        local deleteResult, err = standaloneDelete(sql, params)
        if err then
            return nil, err
        end
        if method == "query" then
            return {}, nil
        end
        return deleteResult, nil
    end

    if lower:find("^%s*select%s+") then
        local rows, err = standaloneSelect(sql, params)
        if err then
            return nil, err
        end
        if method == "single" then
            return rows[1], nil
        elseif method == "scalar" then
            local first = rows[1]
            if not first then
                return nil, nil
            end
            for _, value in pairs(first) do
                return value, nil
            end
            return nil, nil
        elseif method == "query" or method == "prepare" then
            return rows, nil
        end
        return #rows, nil
    end

    return 0, nil
end
local function normalizeTransactionQueries(queries)
    local normalized = {}
    if type(queries) ~= "table" then
        return normalized
    end

    for i = 1, #queries do
        local entry = queries[i]
        if type(entry) == "string" then
            normalized[#normalized + 1] = {
                query = entry,
                values = {}
            }
        elseif type(entry) == "table" then
            if type(entry.query) == "string" then
                normalized[#normalized + 1] = {
                    query = entry.query,
                    values = normalizeParams(entry.params or entry.values or {})
                }
            elseif type(entry[1]) == "string" then
                normalized[#normalized + 1] = {
                    query = entry[1],
                    values = normalizeParams(entry[2] or {})
                }
            end
        end
    end

    return normalized
end

local function fireReady()
    readyState = true
    for i = 1, #readyCallbacks do
        local callback = readyCallbacks[i]
        local ok, err = pcall(callback)
        if not ok then
            log("ERROR", "ready callback failed: %s", err)
        end
    end
    readyCallbacks = {}
end

local function awaitViaPromise(fn)
    local p = promise.new()
    local ok, err = pcall(fn, function(value)
        p:resolve(value)
    end)

    if not ok then
        p:resolve(nil)
        log("ERROR", "promise wrapper failed: %s", err)
    end

    return Citizen.Await(p)
end

local function callOxmysql(method, query, params)
    params = normalizeParams(params)

    if MySQL and type(MySQL) == "table" then
        local handler = MySQL[method]
        if type(handler) == "table" and type(handler.await) == "function" then
            return handler.await(query, params), nil
        end
    end

    local ox = exports.oxmysql
    local asyncMethod = method .. "_async"
    if ox and type(ox[asyncMethod]) == "function" then
        return ox[asyncMethod](query, params), nil
    end

    if ox and type(ox[method]) == "function" then
        local result = awaitViaPromise(function(resolve)
            ox[method](query, params, function(value)
                resolve(value)
            end)
        end)
        return result, nil
    end

    return nil, "oxmysql_method_missing"
end

local function callOxTransaction(queries)
    local normalizedQueries = normalizeTransactionQueries(queries)

    if MySQL and type(MySQL) == "table" then
        local tx = MySQL.transaction
        if type(tx) == "table" and type(tx.await) == "function" then
            return tx.await(normalizedQueries), nil
        end
    end

    local ox = exports.oxmysql
    if ox and type(ox.transaction) == "function" then
        local value = awaitViaPromise(function(resolve)
            ox.transaction(normalizedQueries, function(success)
                resolve(success)
            end)
        end)
        return value, nil
    end

    return false, "oxmysql_transaction_missing"
end

local function getNativeConfig()
    local dbCfg = Config.Database or {}
    local nativeCfg = dbCfg.NativeMariaDB or {}
    return nativeCfg
end

local function executeNative(method, query, params)
    local cfg = getNativeConfig()
    local timeoutMs = tonumber(cfg.QueryTimeoutMs) or nativeRequestTimeoutMs

    if method == "transaction" then
        local txQueries = normalizeTransactionQueries(query)
        return callNativeBridge("execute", {
            method = "transaction",
            queries = txQueries
        }, timeoutMs + 5000)
    end

    return callNativeBridge("execute", {
        method = method,
        query = tostring(query or ""),
        params = normalizeParams(params)
    }, timeoutMs)
end

local function detectBackend()
    if hasExternalOxmysql() then
        backend.name = "oxmysql"
        backend.available = true
        backend.reason = "external_oxmysql_detected"
        return
    end

    local nativeCfg = getNativeConfig()
    if nativeCfg and nativeCfg.Enabled == true then
        backend.name = "native_mariadb"
        backend.available = true
        backend.reason = "embedded_native_mariadb_enabled"
        return
    end

    backend.name = "standalone"
    backend.available = true
    backend.reason = "builtin_standalone_adapter"
end

local function sanitizeMethodResult(method, result)
    if method == "query" then
        if type(result) ~= "table" then
            return {}
        end
        return result
    end

    if method == "single" then
        if type(result) ~= "table" then
            return nil
        end
        return result
    end

    if method == "scalar" then
        return result
    end

    if method == "insert" or method == "update" or method == "execute" then
        return tonumber(result) or 0
    end

    if method == "prepare" then
        if result == nil then
            return {}
        end
        return result
    end

    if method == "transaction" then
        return result == true
    end

    return result
end

local function executeExternal(method, query, params)
    local ok, value, err
    if method == "transaction" then
        ok, value, err = pcall(callOxTransaction, query)
    elseif method == "execute" then
        ok, value, err = pcall(callOxmysql, "query", query, params)
    else
        ok, value, err = pcall(callOxmysql, method, query, params)
    end

    if not ok then
        return nil, tostring(value)
    end

    if value == nil and err ~= nil then
        return nil, tostring(err)
    end

    return value, nil
end

local function executeStandalone(method, query, params)
    if method == "transaction" then
        local queries = normalizeTransactionQueries(query)
        local snapshot = Utils.DeepCopy(standalone.tables)
        local metaSnapshot = Utils.DeepCopy(standalone.meta)

        for i = 1, #queries do
            local txQuery = queries[i]
            local _, err = standaloneExecute(txQuery.query, txQuery.values or {}, "execute")
            if err then
                standalone.tables = snapshot
                standalone.meta = metaSnapshot
                return false, err
            end
        end

        return true, nil
    end

    return standaloneExecute(query, params, method)
end

local function executeMethod(method, query, params)
    lastError = nil

    if not backend.available then
        lastError = backend.reason
        return defaultResult[method]
    end

    local startedAt = GetGameTimer()
    local result, err

    if backend.name == "oxmysql" then
        result, err = executeExternal(method, query, params)
    elseif backend.name == "native_mariadb" then
        result, err = executeNative(method, query, params)
    elseif backend.name == "standalone" then
        result, err = executeStandalone(method, query, params)
    else
        err = "unknown_backend"
    end

    local elapsed = GetGameTimer() - startedAt
    local slowMs = (Config.Database and Config.Database.SlowQueryWarningMs) or 250
    if elapsed > slowMs then
        log("WARN", "slow query (%dms) backend=%s method=%s sql=%s", elapsed, backend.name, method, tostring(query))
    elseif dbDebugEnabled() then
        debugLog("query (%dms) backend=%s method=%s sql=%s", elapsed, backend.name, method, tostring(query))
    end

    if err ~= nil then
        lastError = tostring(err)
        log("ERROR", "DB method failed backend=%s method=%s error=%s query=%s", backend.name, method, tostring(err), tostring(query))
        if HC.LogAudit then
            HC.LogAudit("db_error", 0, nil, {
                backend = backend.name,
                method = method,
                query = tostring(query),
                error = tostring(err)
            })
        end
        return defaultResult[method]
    end

    return sanitizeMethodResult(method, result)
end

local function runWithOptionalCallback(method, query, params, callback)
    if type(params) == "function" and callback == nil then
        callback = params
        params = {}
    end

    if type(callback) == "function" then
        CreateThread(function()
            local result = executeMethod(method, query, params)
            callback(result)
        end)
        return nil
    end

    return executeMethod(method, query, params)
end
function DB.Init()
    if initialized then
        return
    end
    initialized = true

    detectBackend()
    debugLog("backend detected: %s (%s)", backend.name, backend.reason)

    if backend.name == "standalone" then
        standaloneLoad()
        startStandaloneSaveThread()
        fireReady()
        return
    end

    if backend.name == "native_mariadb" then
        local initResult, initErr = callNativeBridge("init", getNativeConfig(), 20000)
        if initErr ~= nil then
            log("ERROR", "native mariadb init failed: %s", tostring(initErr))
            log("WARN", "falling back to standalone adapter")
            backend.name = "standalone"
            backend.available = true
            backend.reason = "native_init_failed_fallback_standalone"
            standaloneLoad()
            startStandaloneSaveThread()
            fireReady()
            return
        end
        if dbDebugEnabled() then
            debugLog("native mariadb initialized: %s", Utils.SafeJsonEncode(initResult, "{}"))
        end
        fireReady()
        return
    end

    if backend.name == "oxmysql" and MySQL and type(MySQL.ready) == "function" then
        MySQL.ready(function()
            fireReady()
        end)
        return
    end

    CreateThread(function()
        local attempts = 0
        while attempts < 200 do
            attempts = attempts + 1
            local ok, err = callOxmysql("query", "SELECT 1", {})
            if err == nil then
                fireReady()
                return
            end
            Wait(100)
        end
        fireReady()
    end)
end

function DB.IsReady()
    return readyState
end

function DB.GetBackend()
    return backend.name
end

function DB.BackendAvailable()
    return backend.available
end

function DB.GetLastError()
    return lastError
end

function DB.ready(callback)
    if type(callback) ~= "function" then
        return
    end

    if readyState then
        callback()
        return
    end

    readyCallbacks[#readyCallbacks + 1] = callback
end

function DB.scalar(query, params, callback)
    return runWithOptionalCallback("scalar", query, params, callback)
end

function DB.single(query, params, callback)
    return runWithOptionalCallback("single", query, params, callback)
end

function DB.query(query, params, callback)
    return runWithOptionalCallback("query", query, params, callback)
end

function DB.insert(query, params, callback)
    return runWithOptionalCallback("insert", query, params, callback)
end

function DB.update(query, params, callback)
    return runWithOptionalCallback("update", query, params, callback)
end

function DB.execute(query, params, callback)
    return runWithOptionalCallback("execute", query, params, callback)
end

function DB.prepare(query, params, callback)
    return runWithOptionalCallback("prepare", query, params, callback)
end

function DB.transaction(queries, callback)
    if type(callback) == "function" then
        CreateThread(function()
            local result = executeMethod("transaction", queries, nil)
            callback(result)
        end)
        return nil
    end

    return executeMethod("transaction", queries, nil)
end

DB.promise = DB.promise or {}

local function promiseWrapper(method)
    return function(query, params)
        local p = promise.new()
        runWithOptionalCallback(method, query, params, function(result)
            p:resolve(result)
        end)
        return p
    end
end

DB.promise.scalar = promiseWrapper("scalar")
DB.promise.single = promiseWrapper("single")
DB.promise.query = promiseWrapper("query")
DB.promise.insert = promiseWrapper("insert")
DB.promise.update = promiseWrapper("update")
DB.promise.execute = promiseWrapper("execute")
DB.promise.prepare = promiseWrapper("prepare")
DB.promise.transaction = function(queries)
    local p = promise.new()
    DB.transaction(queries, function(result)
        p:resolve(result)
    end)
    return p
end

AddEventHandler("onResourceStop", function(stoppedResource)
    if stoppedResource ~= resourceName then
        return
    end

    for requestId, pending in pairs(nativePending) do
        nativePending[requestId] = nil
        pending.err = "resource_stopping"
        pending.promise:resolve(true)
    end

    if backend.name == "native_mariadb" then
        callNativeBridge("close", {}, 5000)
    end

    if backend.name == "standalone" then
        standaloneSave(true)
    end
end)
