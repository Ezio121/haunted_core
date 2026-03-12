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
    }
}
