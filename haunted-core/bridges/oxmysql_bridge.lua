if not (Config.Bridges and Config.Bridges.oxmysql and Config.Compatibility and Config.Compatibility.OxmysqlEmulation) then
    return
end

HauntedCore = HauntedCore or {}
local HC = HauntedCore

local function callDb(method, query, params, callback)
    if type(params) == "function" and callback == nil then
        callback = params
        params = {}
    end

    local dbMethod = HC.DB[method]
    if type(dbMethod) ~= "function" then
        if type(callback) == "function" then
            callback(nil)
            return nil
        end
        return nil
    end

    if type(callback) == "function" then
        return dbMethod(query, params or {}, callback)
    end

    return dbMethod(query, params or {})
end

local function callTx(queries, callback)
    if type(callback) == "function" then
        return HC.DB.transaction(queries, callback)
    end
    return HC.DB.transaction(queries)
end

local function exportMethod(method)
    return function(query, params, callback)
        return callDb(method, query, params, callback)
    end
end

exports("query", exportMethod("query"))
exports("single", exportMethod("single"))
exports("scalar", exportMethod("scalar"))
exports("insert", exportMethod("insert"))
exports("update", exportMethod("update"))
exports("execute", exportMethod("execute"))
exports("prepare", exportMethod("prepare"))
exports("transaction", function(queries, callback)
    return callTx(queries, callback)
end)

exports("query_async", function(query, params)
    return callDb("query", query, params)
end)
exports("single_async", function(query, params)
    return callDb("single", query, params)
end)
exports("scalar_async", function(query, params)
    return callDb("scalar", query, params)
end)
exports("insert_async", function(query, params)
    return callDb("insert", query, params)
end)
exports("update_async", function(query, params)
    return callDb("update", query, params)
end)
exports("execute_async", function(query, params)
    return callDb("execute", query, params)
end)

local function makeCallable(method)
    local wrapper = {}
    setmetatable(wrapper, {
        __call = function(_, query, params, callback)
            return callDb(method, query, params, callback)
        end
    })

    wrapper.await = function(query, params)
        return callDb(method, query, params)
    end

    return wrapper
end

local existingMySQL = MySQL
local shouldCreateGlobal = true
if type(existingMySQL) == "table" and existingMySQL.__provider and existingMySQL.__provider ~= "haunted-core" then
    shouldCreateGlobal = false
end

if shouldCreateGlobal then
    MySQL = MySQL or {}
    MySQL.__provider = "haunted-core"
    MySQL.query = makeCallable("query")
    MySQL.single = makeCallable("single")
    MySQL.scalar = makeCallable("scalar")
    MySQL.insert = makeCallable("insert")
    MySQL.update = makeCallable("update")
    MySQL.prepare = makeCallable("prepare")
    MySQL.execute = makeCallable("execute")

    MySQL.transaction = {}
    setmetatable(MySQL.transaction, {
        __call = function(_, queries, callback)
            return callTx(queries, callback)
        end
    })
    MySQL.transaction.await = function(queries)
        return callTx(queries)
    end

    MySQL.Sync = MySQL.Sync or {}
    MySQL.Sync.fetchAll = function(query, params)
        return callDb("query", query, params)
    end
    MySQL.Sync.fetchScalar = function(query, params)
        return callDb("scalar", query, params)
    end
    MySQL.Sync.execute = function(query, params)
        return callDb("execute", query, params)
    end

    MySQL.Async = MySQL.Async or {}
    MySQL.Async.fetchAll = function(query, params, callback)
        return callDb("query", query, params, callback)
    end
    MySQL.Async.fetchScalar = function(query, params, callback)
        return callDb("scalar", query, params, callback)
    end
    MySQL.Async.execute = function(query, params, callback)
        return callDb("execute", query, params, callback)
    end
    MySQL.Async.insert = function(query, params, callback)
        return callDb("insert", query, params, callback)
    end

    MySQL.ready = function(callback)
        if type(callback) ~= "function" then
            return
        end
        HC.DB.ready(callback)
    end
end
