HauntedCore = HauntedCore or {}
HauntedCore.DBMigrations = HauntedCore.DBMigrations or {}

local HC = HauntedCore
local DBMigrations = HC.DBMigrations
local Constants = HC.Constants

local resourceName = GetCurrentResourceName()
local migrationFiles = {
    "sql/migrations/001_base.sql",
    "sql/migrations/002_ghost_state.sql",
    "sql/migrations/003_audit_logs.sql"
}

local function migrationVersion(path)
    local raw = path:match("/(%d+)_")
    return tonumber(raw) or 0
end

local function splitSqlStatements(sql)
    local statements = {}
    local buffer = {}
    local len = #sql
    local i = 1
    local inSingleQuote = false
    local inDoubleQuote = false
    local inBacktick = false
    local inLineComment = false
    local inBlockComment = false

    while i <= len do
        local ch = sql:sub(i, i)
        local nextCh = (i < len) and sql:sub(i + 1, i + 1) or ""

        if inLineComment then
            if ch == "\n" then
                inLineComment = false
            end
            i = i + 1
        elseif inBlockComment then
            if ch == "*" and nextCh == "/" then
                inBlockComment = false
                i = i + 2
            else
                i = i + 1
            end
        else
            if not inSingleQuote and not inDoubleQuote and not inBacktick then
                if ch == "-" and nextCh == "-" then
                    inLineComment = true
                    i = i + 2
                elseif ch == "/" and nextCh == "*" then
                    inBlockComment = true
                    i = i + 2
                elseif ch == ";" then
                    local statement = table.concat(buffer):gsub("^%s+", ""):gsub("%s+$", "")
                    if statement ~= "" then
                        statements[#statements + 1] = statement
                    end
                    buffer = {}
                    i = i + 1
                else
                    if ch == "'" then
                        inSingleQuote = true
                    elseif ch == '"' then
                        inDoubleQuote = true
                    elseif ch == "`" then
                        inBacktick = true
                    end
                    buffer[#buffer + 1] = ch
                    i = i + 1
                end
            else
                buffer[#buffer + 1] = ch
                if inSingleQuote and ch == "'" then
                    inSingleQuote = false
                elseif inDoubleQuote and ch == '"' then
                    inDoubleQuote = false
                elseif inBacktick and ch == "`" then
                    inBacktick = false
                end
                i = i + 1
            end
        end
    end

    local tail = table.concat(buffer):gsub("^%s+", ""):gsub("%s+$", "")
    if tail ~= "" then
        statements[#statements + 1] = tail
    end

    return statements
end

local function loadMigrationFile(path)
    local content = LoadResourceFile(resourceName, path)
    if not content then
        return nil, ("migration file missing: %s"):format(path)
    end
    return content, nil
end

local function migrationApplied(name)
    local row = HC.DB.single(("SELECT id FROM %s WHERE name = ? LIMIT 1"):format(Constants.TABLES.MIGRATIONS), { name })
    return row ~= nil
end

local function markMigrationApplied(version, name)
    HC.DB.insert(
        ("INSERT INTO %s (version, name) VALUES (?, ?)"):format(Constants.TABLES.MIGRATIONS),
        { version, name }
    )
end

local function applyMigration(path)
    local name = path:match("([^/]+)$") or path
    if migrationApplied(name) then
        return true
    end

    local fileContent, err = loadMigrationFile(path)
    if not fileContent then
        print(("[HauntedCore][Migrations] %s"):format(err))
        return false
    end

    local statements = splitSqlStatements(fileContent)
    for i = 1, #statements do
        local statement = statements[i]
        HC.DB.execute(statement)
        local err = HC.DB.GetLastError and HC.DB.GetLastError() or nil
        if err then
            print(("[HauntedCore][Migrations] failed statement in %s at #%s (%s)"):format(name, i, err))
            return false
        end
    end

    markMigrationApplied(migrationVersion(path), name)
    print(("[HauntedCore][Migrations] applied %s"):format(name))
    return true
end

function DBMigrations.Run()
    if not HC.DB or not HC.DB.IsReady or not HC.DB.IsReady() then
        return false
    end

    if not HC.DB.BackendAvailable() then
        print("[HauntedCore][Migrations] skipped (no SQL backend available)")
        return false
    end

    HC.DBSchema.EnsureMigrationTable()

    for i = 1, #migrationFiles do
        local ok = applyMigration(migrationFiles[i])
        if not ok then
            return false
        end
    end

    return true
end
