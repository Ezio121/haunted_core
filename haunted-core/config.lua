Config = Config or {}

Config.Core = {
    debug = false,
    autosaveIntervalMs = 300000,
    playerDropSaveDelayMs = 25
}

Config.Security = {
    tokenLength = 48,
    tokenRotationIntervalMs = 900000,
    maxInvalidAttempts = 6,
    globalRateLimit = {
        limit = 45,
        windowMs = 3000
    },
    defaultEventRateLimit = {
        limit = 12,
        windowMs = 1500
    },
    massTriggerProtection = {
        burstWindowMs = 750,
        burstLimit = 18,
        strikeKick = 4
    }
}

Config.Economy = {
    maxTransaction = 1000000,
    startingAccounts = {
        cash = 500,
        bank = 2500,
        spirit_energy = 100
    }
}

Config.Inventory = {
    maxStack = 9999,
    maxUniqueItems = 150
}

Config.Permissions = {
    hierarchy = {
        player = 1,
        helper = 2,
        admin = 3,
        god = 4
    }
}

Config.Ghost = {
    defaultState = "ALIVE",
    regenAliveSpiritPerTick = 1,
    regenTickMs = 15000,
    abilities = {
        phase_through_walls = {
            cost = 8,
            cooldownMs = 12000,
            durationMs = 5000
        },
        invisibility = {
            cost = 15,
            cooldownMs = 20000,
            durationMs = 9000
        },
        object_possession = {
            cost = 18,
            cooldownMs = 24000,
            durationMs = 12000
        },
        spirit_whisper = {
            cost = 4,
            cooldownMs = 3000,
            range = 40.0,
            maxMessageLength = 120
        },
        haunt_entities = {
            cost = 10,
            cooldownMs = 15000,
            durationMs = 8000
        }
    },
    visual = {
        alpha = 160,
        auraScale = 0.65
    }
}

Config.Client = {
    abilityKeys = {
        phase_through_walls = "F6",
        invisibility = "F7",
        object_possession = "F8",
        haunt_entities = "F9"
    }
}

Config.AntiExploit = {
    scoreKickThreshold = 100,
    duplicateWindowMs = 400,
    objectSpawnPerSecond = 18,
    blockExplosions = true
}

Config.Bridges = {
    qbcore = true,
    esx = true,
    qbox = true
}
