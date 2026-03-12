import { formatMoney, clamp } from "./utils.js";

const statusOrder = [
    ["health", "Health"],
    ["armor", "Armor"],
    ["hunger", "Hunger"],
    ["thirst", "Thirst"],
    ["stress", "Stress"],
    ["stamina", "Stamina"]
];

const statusRefs = new Map();

const getSeverity = (value) => {
    const safe = clamp(value, 0, 100);
    if (safe <= 12) return "critical";
    if (safe <= 25) return "warn";
    return "normal";
};

const createStatusRow = (key, label) => {
    const row = document.createElement("div");
    row.className = "status-row";
    row.dataset.key = key;

    const name = document.createElement("div");
    name.className = "name";
    name.textContent = label;

    const track = document.createElement("div");
    track.className = "bar-track";

    const fill = document.createElement("div");
    fill.className = "bar-fill";
    fill.style.width = "0%";

    track.appendChild(fill);

    const value = document.createElement("div");
    value.className = "value";
    value.textContent = "0";

    row.append(name, track, value);

    statusRefs.set(key, { row, fill, value });
    return row;
};

let hudBuilt = false;
let hudRoot;
let vehicleRoot;

const refs = {};

const buildHud = () => {
    if (hudBuilt) return;

    hudRoot = document.getElementById("hud-root");
    vehicleRoot = document.getElementById("vehicle-root");

    const shell = document.createElement("div");
    shell.className = "hud-shell ornament-corners";

    const top = document.createElement("div");
    top.className = "hud-top";

    const location = document.createElement("div");
    location.className = "hud-location";

    refs.street = document.createElement("div");
    refs.street.className = "street";
    refs.zone = document.createElement("div");
    refs.zone.className = "zone";
    location.append(refs.street, refs.zone);

    refs.clock = document.createElement("div");
    refs.clock.className = "hud-clock";

    top.append(location, refs.clock);

    const currency = document.createElement("div");
    currency.className = "hud-currency";

    const mkChip = (label, cls) => {
        const chip = document.createElement("div");
        chip.className = `money-chip ${cls}`;
        const name = document.createElement("div");
        name.className = "label";
        name.textContent = label;
        const val = document.createElement("div");
        val.className = "value";
        val.textContent = "0";
        chip.append(name, val);
        currency.appendChild(chip);
        return val;
    };

    refs.cash = mkChip("Cash", "cash");
    refs.bank = mkChip("Bank", "bank");
    refs.spirit = mkChip("Spirit", "spirit");

    const bars = document.createElement("div");
    bars.className = "hud-bars";
    for (const [key, label] of statusOrder) {
        bars.appendChild(createStatusRow(key, label));
    }

    const ghostPanel = document.createElement("div");
    ghostPanel.className = "hud-ghost-panel";

    const mkGhostChip = (label) => {
        const chip = document.createElement("div");
        chip.className = "ghost-chip";
        const l = document.createElement("div");
        l.className = "ghost-label";
        l.textContent = label;
        const v = document.createElement("div");
        v.className = "ghost-value";
        v.textContent = "0";
        chip.append(l, v);
        ghostPanel.appendChild(chip);
        return v;
    };

    refs.hauntLevel = mkGhostChip("Haunt Level");
    refs.possessionCharge = mkGhostChip("Possession");
    refs.whisperRange = mkGhostChip("Whisper");
    refs.phaseStability = mkGhostChip("Phase Stability");

    const meta = document.createElement("div");
    meta.className = "hud-meta";
    refs.voice = document.createElement("div");
    refs.weather = document.createElement("div");
    meta.append(refs.voice, refs.weather);

    shell.append(top, currency, bars, ghostPanel, meta);
    hudRoot.appendChild(shell);
    refs.shell = shell;

    const vehicleShell = document.createElement("div");
    vehicleShell.className = "vehicle-shell hidden";

    const head = document.createElement("div");
    head.className = "vehicle-head";
    refs.gear = document.createElement("div");
    refs.gear.textContent = "GEAR 0";
    refs.seatbelt = document.createElement("div");
    refs.seatbelt.textContent = "BELT OFF";
    head.append(refs.gear, refs.seatbelt);

    refs.speed = document.createElement("div");
    refs.speed.className = "speed-value";
    refs.speed.textContent = "0";

    const meters = document.createElement("div");
    meters.className = "vehicle-meters";

    const mkMeter = (label) => {
        const meter = document.createElement("div");
        meter.className = "vehicle-meter";
        const n = document.createElement("div");
        n.className = "name";
        n.textContent = label;
        const v = document.createElement("div");
        v.className = "value";
        v.textContent = "0";
        meter.append(n, v);
        meters.appendChild(meter);
        return v;
    };

    refs.rpm = mkMeter("RPM");
    refs.fuel = mkMeter("Fuel");
    refs.engine = mkMeter("Engine");

    vehicleShell.append(head, refs.speed, meters);
    vehicleRoot.appendChild(vehicleShell);
    refs.vehicleShell = vehicleShell;

    hudBuilt = true;
};

const updateStatusRows = (status) => {
    for (const [key] of statusOrder) {
        const row = statusRefs.get(key);
        if (!row) continue;
        const value = clamp(status[key], 0, 100);
        row.fill.style.width = `${value}%`;
        row.value.textContent = String(Math.round(value));
        row.row.dataset.state = getSeverity(value);
    }
};

export const renderHud = (hudState, enabled) => {
    buildHud();

    if (!enabled) {
        hudRoot.classList.add("hidden");
        vehicleRoot.classList.add("hidden");
        return;
    }

    hudRoot.classList.remove("hidden");

    const state = hudState || {};
    const status = state.status || {};
    const ghost = state.ghost || {};
    const location = state.location || {};
    const vehicle = state.vehicle || {};

    refs.street.textContent = location.street || "Unknown";
    refs.zone.textContent = `${location.zone || ""} ${location.heading ? `- ${location.heading}` : ""}`.trim();
    refs.clock.textContent = `${location.time || "00:00"}${location.weather ? ` / ${location.weather}` : ""}`;

    refs.cash.textContent = formatMoney(state.accounts?.cash || 0);
    refs.bank.textContent = formatMoney(state.accounts?.bank || 0);
    refs.spirit.textContent = formatMoney(state.accounts?.spirit_energy || 0);

    updateStatusRows(status);

    refs.hauntLevel.textContent = `${Math.round(clamp(ghost.hauntLevel, 0, 999))}`;
    refs.possessionCharge.textContent = `${Math.round(clamp(ghost.possessionCharge, 0, 100))}%`;
    refs.whisperRange.textContent = `${Math.round(clamp(ghost.whisperRange, 0, 150))}m`;
    refs.phaseStability.textContent = `${Math.round(clamp(ghost.phaseStability, 0, 100))}%`;

    refs.voice.textContent = `VOICE ${status.voice ? "LIVE" : "OFF"}${status.radio ? " / RADIO" : ""}`;
    refs.weather.textContent = state.ghostState === "GHOST" ? "SPIRIT REALM" : "MORTAL REALM";

    refs.shell.classList.toggle("ghost", state.ghostState === "GHOST");

    if (vehicle.show) {
        vehicleRoot.classList.remove("hidden");
        refs.vehicleShell.classList.remove("hidden");
        refs.speed.textContent = String(Math.round(vehicle.speed || 0));
        refs.gear.textContent = `GEAR ${Math.max(0, Math.round(vehicle.gear || 0))}`;
        refs.seatbelt.textContent = vehicle.seatbelt ? "BELT ON" : "BELT OFF";
        refs.rpm.textContent = `${Math.round(vehicle.rpm || 0)}%`;
        refs.fuel.textContent = `${Math.round(vehicle.fuel || 0)}%`;
        refs.engine.textContent = `${Math.round(vehicle.engineHealth || 0)}`;
    } else {
        refs.vehicleShell.classList.add("hidden");
    }
};
