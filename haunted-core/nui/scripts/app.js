import { getState, setState } from "./store.js";
import { onMessage, setupReady } from "./events.js";
import { renderHud } from "./hud.js";
import { configureNotifications, pushNotification } from "./notifications.js";
import { openMenu, updateMenu, closeMenu } from "./menus.js";
import { openRadial, closeRadial } from "./radial.js";
import { showOverlay, hideOverlay, updateInteraction } from "./overlays.js";
import { openInventory, updateInventory, closeInventory } from "./inventory.js";
import { openAdmin, updateAdmin, closeAdmin } from "./admin.js";

const root = document.getElementById("haunted-ui");
const loadingRoot = document.getElementById("loading-root");
const characterRoot = document.getElementById("character-root");

const applyTheme = (config) => {
    const ui = config || {};
    const theme = ui.Theme || {};

    root.dataset.theme = String(theme.Variant || "cursed-victorian");
    root.style.setProperty("--ui-scale", String(ui.Layout?.Scale || 1));
    root.style.setProperty("--grain-opacity", String(theme.GrainOpacity ?? 0.07));
    root.style.setProperty("--fog-opacity", String(theme.FogOpacity ?? 0.1));

    root.classList.toggle("performance", Boolean(theme.PerformanceMode));
    root.classList.toggle("reduced-motion", Boolean(theme.ReducedMotion));
    root.classList.toggle("streamer-mode", Boolean(theme.StreamerMode));

    configureNotifications(ui.Notifications || {});

    ensureAudioHooks(ui.Audio || {});
}

const ensureAudioHooks = (audioConfig) => {
    document.querySelectorAll("audio[data-ui-sound]").forEach((node) => node.remove());

    const entries = {
        whisper_open: audioConfig.WhisperOpen,
        rune_activate: audioConfig.RuneActivate,
        cursed_error: audioConfig.CursedError,
        spirit_full: audioConfig.SpiritFull,
        possession_start: audioConfig.PossessionStart,
        limbo_transition: audioConfig.LimboTransition
    };

    Object.entries(entries).forEach(([key, file]) => {
        if (!file) return;
        const audio = document.createElement("audio");
        audio.dataset.uiSound = key;
        audio.src = `assets/audio/${file}`;
        audio.volume = Math.max(0, Math.min(1, Number(audioConfig.Volume || 0.45)));
        audio.preload = "auto";
        document.body.appendChild(audio);
    });
};

const updateHudFromState = () => {
    const state = getState();
    renderHud(state.hud.data, state.hud.enabled);
    root.classList.toggle("ghost-state", state.hud.data?.ghostState === "GHOST");
};

onMessage("haunted:ui:bootstrap", (payload) => {
    setState({
        ready: true,
        ui: {
            ...getState().ui,
            config: payload.config || {}
        }
    });

    applyTheme(payload.config || {});

    root.classList.remove("hidden");
});

onMessage("haunted:theme:apply", (payload) => {
    const nextConfig = payload.config || {};
    setState({ ui: { ...getState().ui, config: nextConfig } });
    applyTheme(nextConfig);
});

onMessage("haunted:hud:update", (payload) => {
    setState({
        hud: {
            enabled: payload.enabled !== false,
            data: payload.hud || getState().hud.data
        }
    });
    updateHudFromState();
});

onMessage("haunted:hud:toggle", (payload) => {
    setState({
        hud: {
            ...getState().hud,
            enabled: payload.enabled === true
        }
    });
    updateHudFromState();
});

onMessage("haunted:notify:push", (payload) => {
    pushNotification(payload || {});
});

onMessage("haunted:menu:open", (payload) => {
    openMenu(payload || {});
});

onMessage("haunted:menu:update", (payload) => {
    updateMenu(payload || {});
});

onMessage("haunted:menu:close", () => {
    closeMenu(false);
});

onMessage("haunted:radial:open", (payload) => {
    openRadial(payload || {});
});

onMessage("haunted:radial:close", () => {
    closeRadial(false);
});

onMessage("haunted:overlay:show", (payload) => {
    showOverlay(payload || {});
});

onMessage("haunted:overlay:hide", (payload) => {
    hideOverlay(payload || {});
});

onMessage("haunted:interaction:update", (payload) => {
    updateInteraction(payload || {});
});

onMessage("haunted:inventory:open", (payload) => {
    openInventory(payload || {});
});

onMessage("haunted:inventory:update", (payload) => {
    updateInventory(payload || {});
});

onMessage("haunted:inventory:close", () => {
    closeInventory();
});

onMessage("haunted:admin:open", (payload) => {
    openAdmin(payload || {});
});

onMessage("haunted:admin:update", (payload) => {
    updateAdmin(payload || {});
});

onMessage("haunted:admin:close", () => {
    closeAdmin();
});

onMessage("haunted:ui:blur", () => {
    closeMenu(false);
    closeRadial(false);
});

onMessage("haunted:loading:show", (payload) => {
    loadingRoot.innerHTML = "";
    const panel = document.createElement("section");
    panel.className = "loading-panel";
    panel.innerHTML = `
        <div class="title-display">${payload.title || "Haunted Core"}</div>
        <div class="menu-subtitle">${payload.subtitle || "Binding your spirit to the server..."}</div>
    `;
    loadingRoot.appendChild(panel);
    loadingRoot.classList.remove("hidden");
});

onMessage("haunted:loading:hide", () => {
    loadingRoot.classList.add("hidden");
    loadingRoot.innerHTML = "";
});

onMessage("haunted:character:open", (payload) => {
    characterRoot.innerHTML = "";
    const panel = document.createElement("section");
    panel.className = "character-panel";
    panel.innerHTML = `
        <div class="title-display">${payload.title || "Character Ledger"}</div>
        <div class="menu-subtitle">${payload.subtitle || "Select or create your vessel."}</div>
    `;
    characterRoot.appendChild(panel);
    characterRoot.classList.remove("hidden");
});

onMessage("haunted:character:close", () => {
    characterRoot.classList.add("hidden");
    characterRoot.innerHTML = "";
});

const runPreview = () => {
    const previewConfig = {
        Theme: {
            Variant: "cursed-victorian",
            PerformanceMode: false,
            ReducedMotion: false,
            StreamerMode: false,
            GrainOpacity: 0.08,
            FogOpacity: 0.12
        },
        Layout: {
            Scale: 1
        },
        Notifications: {
            MaxVisible: 5,
            Position: "top-right"
        },
        Audio: {}
    };

    applyTheme(previewConfig);
    root.classList.remove("hidden");

    setState({
        ready: true,
        hud: {
            enabled: true,
            data: {
                ghostState: "GHOST",
                accounts: {
                    cash: 1880,
                    bank: 17340,
                    spirit_energy: 315
                },
                status: {
                    health: 82,
                    armor: 25,
                    hunger: 64,
                    thirst: 58,
                    stress: 22,
                    stamina: 71,
                    voice: false,
                    radio: true
                },
                ghost: {
                    hauntLevel: 4,
                    possessionCharge: 67,
                    whisperRange: 42,
                    phaseStability: 79,
                    exposureRisk: 18
                },
                location: {
                    street: "Eclipse Blvd / Milton Rd",
                    zone: "Rockford Hills",
                    heading: "NW",
                    time: "02:14",
                    weather: "Fog"
                },
                vehicle: {
                    show: true,
                    speed: 63,
                    rpm: 58,
                    gear: 4,
                    fuel: 47,
                    engineHealth: 884,
                    seatbelt: true
                }
            }
        }
    });

    updateHudFromState();

    pushNotification({
        type: "supernatural",
        title: "Spectral Surge",
        description: "Spirit energy resonates through the veil.",
        icon: "ghost",
        duration: 4800
    });
};

const boot = async () => {
    if (window.GetParentResourceName) {
        await setupReady();
    } else {
        runPreview();
    }
};

boot();
