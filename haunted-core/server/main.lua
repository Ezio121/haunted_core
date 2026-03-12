HauntedCore = HauntedCore or {}

local HC = HauntedCore
local Constants = HC.Constants

local coreReady = false

local function bootstrapPlayer(source)
    local player = HC.PlayerManager.CreatePlayer(source)
    if not player then
        return nil
    end

    HC.Economy.InitializePlayer(source)
    HC.EventSecurity.GenerateToken(source)
    HC.FlushAuditQueue()
    TriggerClientEvent(Constants.EVENTS.GHOST_STATE_SYNC, -1, {
        source = source,
        state = player.ghost_state,
        reason = "bootstrap"
    })

    return player
end

local function saveAllPlayers()
    local players = GetPlayers()
    for i = 1, #players do
        local source = tonumber(players[i])
        if source then
            HC.PlayerManager.SavePlayer(source)
        end
    end
end

local function initializeCoreModules()
    HC.Permissions.Init()
    HC.Economy.Init()
    HC.Inventory.Init()
    HC.EntityManager.Init()
    HC.EventSecurity.Init()
    HC.Ghost.Init()
    HC.AntiExploit.Init()
    HC.CompatibilityProvider.Init()
end

local function startAutosaveLoop()
    local intervalMinutes = (Config.Database and Config.Database.SaveIntervalMinutes) or 10
    local saveInterval = math.max(1, tonumber(intervalMinutes) or 10) * 60000
    CreateThread(function()
        while true do
            Wait(saveInterval)
            saveAllPlayers()
        end
    end)
end

local function startCore()
    if coreReady then
        return
    end

    initializeCoreModules()
    local players = GetPlayers()
    for i = 1, #players do
        local source = tonumber(players[i])
        if source then
            bootstrapPlayer(source)
        end
    end

    startAutosaveLoop()
    coreReady = true

    print(("[HauntedCore] Started v%s (%s)"):format(HC.Version or "1.0.0", GetCurrentResourceName()))
end

CreateThread(function()
    math.randomseed(os.time() + GetGameTimer())
    HC.DB.Init()

    HC.DB.ready(function()
        if Config.Database and Config.Database.AutoCreateSchema then
            HC.DBSchema.Ensure()
        end
        if Config.Database and Config.Database.AutoMigrate then
            HC.DBMigrations.Run()
        end
        if HC.DB.GetBackend and HC.DB.GetBackend() == "native_mariadb" then
            print("[HauntedCore] Using embedded native MariaDB adapter.")
        elseif HC.DB.GetBackend and HC.DB.GetBackend() == "standalone" then
            print("[HauntedCore] External oxmysql not detected. Using built-in standalone database adapter.")
        end
        startCore()
    end)
end)

AddEventHandler("playerJoining", function()
    local source = source
    CreateThread(function()
        local waitCycles = 0
        while not coreReady and waitCycles < 200 do
            waitCycles = waitCycles + 1
            Wait(50)
        end

        if coreReady then
            Wait(100)
            bootstrapPlayer(source)
        end
    end)
end)

AddEventHandler("playerDropped", function(reason)
    local source = source
    Wait(tonumber(Config.Core.playerDropSaveDelayMs) or 25)
    HC.PlayerManager.DropPlayer(source, nil)
    HC.Events.Emit("player:dropped:completed", source, reason)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end
    saveAllPlayers()
end)
