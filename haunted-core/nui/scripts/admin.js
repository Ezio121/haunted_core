import { createElement } from "./utils.js";

let root;
let panelData = null;

const ensureRoot = () => {
    if (!root) root = document.getElementById("admin-root");
    return root;
};

const render = () => {
    const node = ensureRoot();
    node.innerHTML = "";

    if (!panelData?.open) {
        node.classList.add("hidden");
        node.setAttribute("aria-hidden", "true");
        return;
    }

    const data = panelData.data || {};

    const panel = createElement("section", "admin-panel interactive");
    const header = createElement("header", "admin-header");
    header.append(
        createElement("div", "admin-title", data.title || "Forbidden Control Panel"),
        createElement("div", "label-muted", data.subtitle || "Staff operations")
    );

    const grid = createElement("div", "admin-grid");

    const players = createElement("section", "admin-card");
    players.appendChild(createElement("div", "title-display", "Player Lookup"));

    const list = createElement("div", "admin-list");
    const entries = Array.isArray(data.players) ? data.players : [];
    entries.forEach((entry) => {
        const row = createElement("div", "admin-row");
        const left = createElement("div");
        left.append(
            createElement("div", "name", `${entry.name || "Unknown"} (${entry.id || "?"})`),
            createElement("div", "meta", `${entry.citizenid || "N/A"} - ${entry.permission || "player"}`)
        );
        const right = createElement("div", "meta", entry.ghostState || "ALIVE");
        row.append(left, right);
        list.appendChild(row);
    });

    players.appendChild(list);

    const logs = createElement("section", "admin-card");
    logs.appendChild(createElement("div", "title-display", "Recent Audit"));

    const logList = createElement("div", "admin-list");
    const actions = Array.isArray(data.logs) ? data.logs : [];
    actions.forEach((entry) => {
        const row = createElement("div", "admin-row");
        row.append(
            createElement("div", "name", entry.action || "unknown"),
            createElement("div", "meta", entry.time || "now")
        );
        logList.appendChild(row);
    });
    logs.appendChild(logList);

    grid.append(players, logs);
    panel.append(header, grid);

    node.appendChild(panel);
    node.classList.remove("hidden");
    node.setAttribute("aria-hidden", "false");
};

export const openAdmin = (payload = {}) => {
    panelData = {
        open: true,
        data: payload
    };
    render();
};

export const updateAdmin = (payload = {}) => {
    if (!panelData) return;
    panelData.data = {
        ...(panelData.data || {}),
        ...payload
    };
    render();
};

export const closeAdmin = () => {
    panelData = { open: false, data: null };
    render();
};
