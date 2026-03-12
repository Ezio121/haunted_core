HauntedCore = HauntedCore or {}

local HC = HauntedCore
local Constants = HC.Constants

local function bootstrapPlayer(source)
    local player = HC.PlayerManager.CreatePlayer(source)
    if not player then
        return nil
    end

    HC.Economy.InitializePlayer(source)
    HC.EventSecurity.GenerateToken(source)
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

CreateThread(function()
    math.randomseed(os.time() + GetGameTimer())

    HC.Permissions.Init()
    HC.Economy.Init()
    HC.EntityManager.Init()
    HC.EventSecurity.Init()
    HC.Ghost.Init()
    HC.AntiExploit.Init()

    local players = GetPlayers()
    for i = 1, #players do
        local source = tonumber(players[i])
        if source then
            bootstrapPlayer(source)
        end
    end

    local saveInterval = tonumber(Config.Core.autosaveIntervalMs) or 300000
    CreateThread(function()
        while true do
            Wait(saveInterval)
            saveAllPlayers()
        end
    end)

    print(("[HauntedCore] Started v%s (%s)"):format(HC.Version or "1.0.0", GetCurrentResourceName()))
end)

AddEventHandler("playerJoining", function()
    local source = source
    CreateThread(function()
        Wait(100)
        bootstrapPlayer(source)
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
