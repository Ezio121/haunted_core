HauntedCore = HauntedCore or {}
HauntedCore.HUD = HauntedCore.HUD or {}

local HC = HauntedCore
local HUD = HC.HUD
local UI = HC.UI
local Constants = HC.Constants

local hudEnabled = true
local hudState = {
    ghostState = Constants.GHOST_STATES.ALIVE,
    accounts = {
        cash = 0,
        bank = 0,
        spirit_energy = 0
    },
    status = {
        health = 100,
        armor = 0,
        stamina = 100,
        hunger = 100,
        thirst = 100,
        stress = 0,
        voice = false,
        radio = false
    },
    ghost = {
        hauntLevel = 0,
        possessionCharge = 0,
        whisperRange = 40,
        phaseStability = 100,
        exposureRisk = 0
    },
    location = {
        street = "Unknown",
        zone = "",
        heading = "N",
        time = "00:00",
        weather = "Unknown"
    },
    vehicle = {
        show = false,
        speed = 0,
        rpm = 0,
        gear = 0,
        fuel = 100,
        engineHealth = 1000,
        seatbelt = false
    }
}

local lastSent = {}
local nextLocationTick = 0
local nextStatusTick = 0
local nextVehicleTick = 0
local pauseHidden = false

local compass = {
    [0] = "N",
    [1] = "NNE",
    [2] = "NE",
    [3] = "ENE",
    [4] = "E",
    [5] = "ESE",
    [6] = "SE",
    [7] = "SSE",
    [8] = "S",
    [9] = "SSW",
    [10] = "SW",
    [11] = "WSW",
    [12] = "W",
    [13] = "WNW",
    [14] = "NW",
    [15] = "NNW"
}

local function nowMs()
    return GetGameTimer()
end

local function roundNumber(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

local function valueChanged(current, previous)
    if type(current) ~= type(previous) then
        return true
    end

    if type(current) ~= "table" then
        return current ~= previous
    end

    for key, val in pairs(current) do
        if valueChanged(val, previous and previous[key]) then
            return true
        end
    end

    for key in pairs(previous or {}) do
        if current[key] == nil then
            return true
        end
    end

    return false
end

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local out = {}
    for k, v in pairs(value) do
        out[k] = deepCopy(v)
    end
    return out
end

local function getStreetData(coords)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = streetHash ~= 0 and GetStreetNameFromHashKey(streetHash) or "Unknown"
    local crossing = crossingHash ~= 0 and GetStreetNameFromHashKey(crossingHash) or ""

    if crossing ~= "" then
        street = ("%s / %s"):format(street, crossing)
    end

    return street
end

local function getHeadingCardinal(heading)
    local idx = math.floor(((heading % 360.0) / 22.5) + 0.5) % 16
    return compass[idx] or "N"
end

local function updateStatusState(ped)
    local maxHealth = GetEntityMaxHealth(ped)
    local health = GetEntityHealth(ped)
    local healthPct = 100

    if maxHealth > 100 then
        healthPct = roundNumber(((health - 100) / (maxHealth - 100)) * 100)
    end

    local state = LocalPlayer and LocalPlayer.state

    hudState.status.health = math.max(0, math.min(100, healthPct))
    hudState.status.armor = math.max(0, math.min(100, roundNumber(GetPedArmour(ped))))
    hudState.status.stamina = math.max(0, math.min(100, roundNumber(GetPlayerSprintStaminaRemaining(PlayerId()))))
    hudState.status.hunger = math.max(0, math.min(100, roundNumber((state and state.hunger) or hudState.status.hunger or 100)))
    hudState.status.thirst = math.max(0, math.min(100, roundNumber((state and state.thirst) or hudState.status.thirst or 100)))
    hudState.status.stress = math.max(0, math.min(100, roundNumber((state and state.stress) or hudState.status.stress or 0)))
    hudState.status.voice = NetworkIsPlayerTalking(PlayerId())
    hudState.status.radio = (state and state.radioActive) == true
end

local function updateGhostStateFromBags()
    local state = LocalPlayer and LocalPlayer.state
    if not state then
        return
    end

    hudState.ghostState = state.ghostState or hudState.ghostState
    hudState.accounts.spirit_energy = tonumber(state["account:spirit_energy"]) or hudState.accounts.spirit_energy

    hudState.ghost.hauntLevel = tonumber(state.hauntLevel) or hudState.ghost.hauntLevel
    hudState.ghost.possessionCharge = tonumber(state.possessionCharge) or hudState.ghost.possessionCharge
    hudState.ghost.whisperRange = tonumber(state.whisperRange) or hudState.ghost.whisperRange
    hudState.ghost.phaseStability = tonumber(state.phaseStability) or hudState.ghost.phaseStability
    hudState.ghost.exposureRisk = tonumber(state.ghostExposureRisk) or hudState.ghost.exposureRisk
end

local function updateLocationState(ped)
    local coords = GetEntityCoords(ped)
    hudState.location.street = getStreetData(coords)
    hudState.location.zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z)) or ""
    hudState.location.heading = getHeadingCardinal(GetEntityHeading(ped))
    hudState.location.time = ("%02d:%02d"):format(GetClockHours(), GetClockMinutes())

    local state = LocalPlayer and LocalPlayer.state
    hudState.location.weather = (state and state.weatherName) or "Unknown"
end

local function updateVehicleState(ped)
    if not IsPedInAnyVehicle(ped, false) then
        hudState.vehicle.show = false
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        hudState.vehicle.show = false
        return
    end

    local speedMph = GetEntitySpeed(vehicle) * 2.236936

    hudState.vehicle.show = true
    hudState.vehicle.speed = roundNumber(speedMph)
    hudState.vehicle.rpm = roundNumber((GetVehicleCurrentRpm(vehicle) or 0.0) * 100)
    hudState.vehicle.gear = GetVehicleCurrentGear(vehicle)
    hudState.vehicle.fuel = roundNumber(GetVehicleFuelLevel(vehicle) or 0.0)
    hudState.vehicle.engineHealth = roundNumber(GetVehicleEngineHealth(vehicle) or 0.0)
    hudState.vehicle.seatbelt = (LocalPlayer and LocalPlayer.state and LocalPlayer.state.seatbeltOn) == true
end

local function sendPartialUpdate(force)
    if not UI or not UI.UpdateHud then
        return
    end

    if force or valueChanged(hudState, lastSent) then
        lastSent = deepCopy(hudState)
        UI.UpdateHud({
            hud = hudState,
            enabled = hudEnabled
        })
    end
end

function HUD.SetVisible(enabled)
    hudEnabled = enabled == true
    if UI and UI.ToggleHud then
        UI.ToggleHud(hudEnabled)
    end
end

function HUD.PushGhostState(state, source)
    if tonumber(source or -1) ~= GetPlayerServerId(PlayerId()) then
        return
    end

    hudState.ghostState = state
    sendPartialUpdate(true)
end

function HUD.PushMoney(account, balance)
    if type(account) ~= "string" then
        return
    end

    hudState.accounts[account] = tonumber(balance) or hudState.accounts[account] or 0
    sendPartialUpdate(true)
end

function HUD.PushNeeds(payload)
    if type(payload) ~= "table" then
        return
    end

    hudState.status.hunger = roundNumber(payload.hunger or hudState.status.hunger)
    hudState.status.thirst = roundNumber(payload.thirst or hudState.status.thirst)
    hudState.status.stress = roundNumber(payload.stress or hudState.status.stress)
    sendPartialUpdate(true)
end

RegisterNetEvent(Constants.EVENTS.GHOST_STATE_SYNC, function(payload)
    if type(payload) ~= "table" then
        return
    end
    HUD.PushGhostState(payload.state, payload.source)
end)

RegisterNetEvent(Constants.EVENTS.MONEY_SYNC, function(payload)
    if type(payload) ~= "table" then
        return
    end
    HUD.PushMoney(payload.account, payload.balance)
end)

RegisterNetEvent("haunted:hud:needs", function(payload)
    HUD.PushNeeds(payload)
end)

RegisterNetEvent("haunted:hud:toggle", function(enabled)
    HUD.SetVisible(enabled)
end)

CreateThread(function()
    while true do
        Wait(120)

        if not hudEnabled then
            goto continue
        end

        if IsPauseMenuActive() then
            if not pauseHidden and UI and UI.ToggleHud then
                UI.ToggleHud(false)
                pauseHidden = true
            end
            Wait(200)
            goto continue
        end

        if pauseHidden and UI and UI.ToggleHud then
            UI.ToggleHud(true)
            pauseHidden = false
        end

        local ped = PlayerPedId()
        if ped == 0 then
            goto continue
        end

        local tick = nowMs()

        if tick >= nextStatusTick then
            nextStatusTick = tick + 350
            updateStatusState(ped)
            updateGhostStateFromBags()
        end

        if tick >= nextLocationTick then
            nextLocationTick = tick + 1000
            updateLocationState(ped)
        end

        if tick >= nextVehicleTick then
            nextVehicleTick = tick + 220
            updateVehicleState(ped)
        end

        sendPartialUpdate(false)

        ::continue::
    end
end)

AddEventHandler("onClientResourceStart", function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    Wait(350)
    sendPartialUpdate(true)
end)
