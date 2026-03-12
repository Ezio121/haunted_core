import { createElement } from "./utils.js";

let root;
let active = null;

const ensureRoot = () => {
    if (!root) root = document.getElementById("inventory-root");
    return root;
};

const renderItems = (container, items) => {
    container.innerHTML = "";

    if (!Array.isArray(items) || items.length === 0) {
        for (let i = 0; i < 24; i += 1) {
            const empty = createElement("div", "item-card");
            empty.append(createElement("div", "item-name", "Empty"));
            container.appendChild(empty);
        }
        return;
    }

    for (const item of items) {
        const card = createElement("div", "item-card");
        card.dataset.rarity = String(item?.metadata?.rarity || item?.rarity || "common").toLowerCase();

        card.append(
            createElement("div", "item-name", item.label || item.name || "Unknown"),
            createElement("div", "item-meta", item?.metadata?.description || ""),
            createElement("div", "item-count", `x${item.count || 1}`)
        );

        container.appendChild(card);
    }
};

const render = () => {
    const node = ensureRoot();
    node.innerHTML = "";

    if (!active?.open) {
        node.classList.add("hidden");
        node.setAttribute("aria-hidden", "true");
        return;
    }

    const data = active.data || {};

    const panel = createElement("section", "inventory-panel interactive");
    const left = createElement("section", "inventory-left");

    const header = createElement("header", "inventory-header");
    header.append(
        createElement("div", "inventory-title", data.title || "Haunted Inventory"),
        createElement("div", "inventory-weight", `Weight ${data.weight || 0}/${data.maxWeight || 100}`)
    );

    const quickSlots = createElement("div", "quick-slots");
    const slots = Array.isArray(data.quickSlots) ? data.quickSlots : [];
    for (let i = 0; i < 5; i += 1) {
        const slot = createElement("div", "quick-slot", slots[i]?.label || `Slot ${i + 1}`);
        quickSlots.appendChild(slot);
    }

    const grid = createElement("div", "inventory-grid");
    renderItems(grid, data.items || []);

    const actions = createElement("div", "inventory-actions");
    ["Use", "Split", "Drop"].forEach((label) => {
        const button = createElement("button", "inventory-btn", label);
        button.type = "button";
        actions.appendChild(button);
    });

    left.append(header, quickSlots, grid, actions);

    const right = createElement("aside", "inventory-right");
    const tooltip = createElement("section", "tooltip-panel");
    tooltip.append(
        createElement("div", "tooltip-title", data.tooltip?.title || "Item Details"),
        createElement("div", "tooltip-body", data.tooltip?.description || "Select an item to inspect metadata and ritual properties.")
    );

    right.appendChild(tooltip);
    panel.append(left, right);

    node.appendChild(panel);
    node.classList.remove("hidden");
    node.setAttribute("aria-hidden", "false");
};

export const openInventory = (payload = {}) => {
    active = {
        open: true,
        data: payload
    };
    render();
};

export const updateInventory = (payload = {}) => {
    if (!active) return;
    active.data = {
        ...(active.data || {}),
        ...payload
    };
    render();
};

export const closeInventory = () => {
    if (!active) return;
    active = {
        open: false,
        data: null
    };
    render();
};
