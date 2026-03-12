HauntedCore = HauntedCore or {}
local HC = HauntedCore

function HasPermission(source, permission)
    return HC.Permissions.HasPermission(source, permission)
end

function AddPermission(source, permission)
    return HC.Permissions.AddPermission(source, permission)
end

function RemovePermission(source, permission)
    return HC.Permissions.RemovePermission(source, permission)
end

exports("HasPermission", HasPermission)
exports("AddPermission", AddPermission)
exports("RemovePermission", RemovePermission)
