HauntedCore = HauntedCore or {}
local HC = HauntedCore

local function HasPermission(source, permission)
    return HC.Permissions.HasPermission(source, permission)
end

local function AddPermission(source, permission)
    return HC.Permissions.AddPermission(source, permission)
end

local function RemovePermission(source, permission)
    return HC.Permissions.RemovePermission(source, permission)
end

exports("HasPermission", HasPermission)
exports("AddPermission", AddPermission)
exports("RemovePermission", RemovePermission)
