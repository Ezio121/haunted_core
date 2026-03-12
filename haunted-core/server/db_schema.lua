HauntedCore = HauntedCore or {}
HauntedCore.DBSchema = HauntedCore.DBSchema or {}

local HC = HauntedCore
local Schema = HC.DBSchema

local migrationTableSql = [[
CREATE TABLE IF NOT EXISTS hc_schema_migrations (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    version INT UNSIGNED NOT NULL,
    name VARCHAR(128) NOT NULL,
    applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_hc_schema_migrations_name (name),
    KEY idx_hc_schema_migrations_version (version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]]

function Schema.EnsureMigrationTable()
    if not HC.DB or not HC.DB.execute then
        return false
    end
    if not HC.DB.BackendAvailable() then
        return false
    end

    HC.DB.execute(migrationTableSql)
    return true
end

function Schema.EnsureCoreMetadata()
    if not HC.DB.BackendAvailable() then
        return false
    end

    local kvpSql = [[
    CREATE TABLE IF NOT EXISTS server_kvp (
        kvp_key VARCHAR(128) NOT NULL,
        kvp_value LONGTEXT NULL,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (kvp_key)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]]

    HC.DB.execute(kvpSql)
    return true
end

function Schema.Ensure()
    Schema.EnsureMigrationTable()
    Schema.EnsureCoreMetadata()
    return true
end
