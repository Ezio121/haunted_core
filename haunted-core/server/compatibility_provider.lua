HauntedCore = HauntedCore or {}
HauntedCore.CompatibilityProvider = HauntedCore.CompatibilityProvider or {}

local HC = HauntedCore
local Provider = HC.CompatibilityProvider

local initialized = false

local function safeInvoke(callback, value)
    if type(callback) ~= "function" then
        return
    end
    local ok, err = pcall(callback, value)
    if not ok then
        print(("[HauntedCore][Compatibility] callback error: %s"):format(err))
    end
end

local function registerLegacyObjectEvents()
    AddEventHandler("QBCore:GetObject", function(cb)
        safeInvoke(cb, QBCore)
    end)

    AddEventHandler("esx:getSharedObject", function(cb)
        safeInvoke(cb, ESX)
    end)

    AddEventHandler("QBox:GetObject", function(cb)
        safeInvoke(cb, QBox)
    end)
end

function Provider.Init()
    if initialized then
        return
    end
    initialized = true

    if Config.Compatibility and Config.Compatibility.LegacyCallbacks then
        registerLegacyObjectEvents()
    end

    print("[HauntedCore] Compatibility provider initialized (qb-core/es_extended/qbx_core/oxmysql via provide).")
end
