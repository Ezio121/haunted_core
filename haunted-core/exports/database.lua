HauntedCore = HauntedCore or {}
local HC = HauntedCore

local function Scalar(query, params, callback)
    return HC.DB.scalar(query, params, callback)
end

local function Single(query, params, callback)
    return HC.DB.single(query, params, callback)
end

local function Query(query, params, callback)
    return HC.DB.query(query, params, callback)
end

local function Insert(query, params, callback)
    return HC.DB.insert(query, params, callback)
end

local function Update(query, params, callback)
    return HC.DB.update(query, params, callback)
end

local function Execute(query, params, callback)
    return HC.DB.execute(query, params, callback)
end

local function Transaction(queries, callback)
    return HC.DB.transaction(queries, callback)
end

local function Prepare(query, params, callback)
    return HC.DB.prepare(query, params, callback)
end

exports("Scalar", Scalar)
exports("Single", Single)
exports("Query", Query)
exports("Insert", Insert)
exports("Update", Update)
exports("Execute", Execute)
exports("Transaction", Transaction)
exports("Prepare", Prepare)
exports("scalar", Scalar)
exports("single", Single)
exports("query", Query)
exports("insert", Insert)
exports("update", Update)
exports("execute", Execute)
exports("transaction", Transaction)
exports("prepare", Prepare)
