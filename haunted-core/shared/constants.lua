HauntedCore = HauntedCore or {}

HauntedCore.Constants = {
    RESOURCE_NAME = GetCurrentResourceName(),
    VERSION = "1.0.0",
    GHOST_STATES = {
        ALIVE = "ALIVE",
        GHOST = "GHOST"
    },
    ACCOUNTS = {
        CASH = "cash",
        BANK = "bank",
        SPIRIT = "spirit_energy"
    },
    PERMISSIONS = {
        PLAYER = "player",
        HELPER = "helper",
        ADMIN = "admin",
        GOD = "god"
    },
    EVENTS = {
        REQUEST_TOKEN = "haunted:server:requestSecurityToken",
        SECURITY_TOKEN = "haunted:client:setSecurityToken",
        REQUEST_ABILITY = "haunted:requestAbility",
        GHOST_STATE_SYNC = "haunted:client:ghostStateChanged",
        ABILITY_ACTIVATED = "haunted:client:abilityActivated",
        INVENTORY_SYNC = "haunted:client:inventorySync",
        MONEY_SYNC = "haunted:client:moneySync"
    },
    TABLES = {
        USERS = "users",
        ACCOUNTS = "player_accounts",
        INVENTORY = "player_inventory",
        METADATA = "player_metadata",
        PERMISSIONS = "player_permissions",
        GHOST_STATES = "ghost_states",
        JOBS = "jobs",
        JOB_GRADES = "job_grades",
        OWNED_ENTITIES = "owned_entities",
        AUDIT_LOGS = "audit_logs",
        SERVER_KVP = "server_kvp",
        MIGRATIONS = "hc_schema_migrations"
    },
    COMPAT_RESOURCES = {
        QBCORE = "qb-core",
        ESX = "es_extended",
        QBOX = "qbx_core",
        OXMYSQL = "oxmysql"
    }
}
