import { deepMerge } from "./utils.js";

const defaultState = {
    ready: false,
    ui: {
        focused: false,
        config: {}
    },
    hud: {
        enabled: true,
        data: {
            ghostState: "ALIVE",
            accounts: { cash: 0, bank: 0, spirit_energy: 0 },
            status: {
                health: 100,
                armor: 0,
                hunger: 100,
                thirst: 100,
                stress: 0,
                stamina: 100,
                voice: false,
                radio: false
            },
            ghost: {
                hauntLevel: 0,
                possessionCharge: 0,
                whisperRange: 40,
                phaseStability: 100,
                exposureRisk: 0
            },
            location: {
                street: "Unknown",
                zone: "",
                heading: "N",
                time: "00:00",
                weather: "Unknown"
            },
            vehicle: {
                show: false,
                speed: 0,
                rpm: 0,
                gear: 0,
                fuel: 0,
                engineHealth: 1000,
                seatbelt: false
            }
        }
    },
    notifications: [],
    menu: {
        open: false,
        callbackId: null,
        data: null,
        selected: 0,
        query: ""
    },
    radial: {
        open: false,
        callbackId: null,
        data: null,
        selected: -1
    },
    overlays: {},
    interaction: {
        prompt: null
    },
    inventory: {
        open: false,
        data: null
    },
    admin: {
        open: false,
        data: null
    }
};

const listeners = new Set();
const clone = (value) => JSON.parse(JSON.stringify(value));
let state = clone(defaultState);

export const getState = () => state;

export const setState = (patch) => {
    state = deepMerge(state, patch);
    for (const listener of listeners) {
        listener(state);
    }
};

export const subscribe = (listener) => {
    listeners.add(listener);
    return () => listeners.delete(listener);
};

export const resetState = () => {
    state = clone(defaultState);
    for (const listener of listeners) {
        listener(state);
    }
};
