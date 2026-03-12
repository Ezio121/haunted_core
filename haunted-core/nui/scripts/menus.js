import { createElement, normalizeIcon, postNui } from "./utils.js";

let root;
let activeMenu = null;
let selectedIndex = 0;
let searchValue = "";

const ensureRoot = () => {
    if (!root) root = document.getElementById("menu-root");
    return root;
};

const getEntries = () => {
    if (!activeMenu?.entries) return [];
    if (!searchValue.trim()) return activeMenu.entries;

    const query = searchValue.trim().toLowerCase();
    return activeMenu.entries.filter((entry) => {
        const title = String(entry.title || "").toLowerCase();
        const description = String(entry.description || "").toLowerCase();
        return title.includes(query) || description.includes(query);
    });
};

const sendMenuAction = async (action, item = null, meta = {}) => {
    await postNui("haunted:ui:menuAction", {
        action,
        item,
        meta,
        callbackId: activeMenu?.callbackId || null
    });
};

const renderEntries = (container, entries) => {
    container.innerHTML = "";

    if (entries.length === 0) {
        const empty = createElement("div", "menu-entry");
        empty.innerHTML = `<div class="text"><div class="title">No entries</div><div class="desc">No options match the current search.</div></div>`;
        container.appendChild(empty);
        return;
    }

    if (selectedIndex >= entries.length) selectedIndex = entries.length - 1;
    if (selectedIndex < 0) selectedIndex = 0;

    entries.forEach((entry, index) => {
        const card = createElement("button", "menu-entry");
        card.type = "button";
        card.dataset.selected = String(index === selectedIndex);
        card.dataset.disabled = String(entry.disabled === true);
        card.dataset.locked = String(entry.locked === true);

        const icon = createElement("div", "icon", normalizeIcon(entry.icon));

        const text = createElement("div", "text");
        const title = createElement("div", "title", entry.title || "Untitled");
        const desc = createElement("div", "desc", entry.description || "");
        text.append(title, desc);

        if (typeof entry.progress === "number") {
            const progress = createElement("div", "menu-progress");
            const bar = createElement("span");
            bar.style.width = `${Math.max(0, Math.min(100, entry.progress))}%`;
            progress.appendChild(bar);
            text.appendChild(progress);
        }

        const meta = createElement("div", "meta", entry.hotkey || entry.badge || (entry.locked ? "LOCKED" : ""));

        card.append(icon, text, meta);

        card.addEventListener("mouseenter", () => {
            selectedIndex = index;
            render();
        });

        card.addEventListener("click", async () => {
            if (entry.disabled || entry.locked) return;
            await sendMenuAction("select", entry);
        });

        container.appendChild(card);
    });
};

const onKeyDown = async (event) => {
    if (!activeMenu) return;

    const entries = getEntries();

    if (event.key === "ArrowDown") {
        event.preventDefault();
        if (entries.length > 0) selectedIndex = (selectedIndex + 1) % entries.length;
        render();
        return;
    }

    if (event.key === "ArrowUp") {
        event.preventDefault();
        if (entries.length > 0) selectedIndex = (selectedIndex - 1 + entries.length) % entries.length;
        render();
        return;
    }

    if (event.key === "Enter") {
        event.preventDefault();
        const entry = entries[selectedIndex];
        if (!entry || entry.disabled || entry.locked) return;
        await sendMenuAction("select", entry);
        return;
    }

    if (event.key === "Backspace") {
        event.preventDefault();
        await closeMenu();
    }
};

const render = () => {
    const node = ensureRoot();
    node.innerHTML = "";

    if (!activeMenu) {
        node.classList.add("hidden");
        node.setAttribute("aria-hidden", "true");
        return;
    }

    const panel = createElement("section", "menu-panel interactive");

    const header = createElement("header", "menu-header");
    const title = createElement("div", "menu-title", activeMenu.title || "Menu");
    const subtitle = createElement("div", "menu-subtitle", activeMenu.subtitle || "");
    header.append(title, subtitle);

    const toolbar = createElement("div", "menu-toolbar");
    const breadcrumbs = createElement("div", "label-muted", (activeMenu.breadcrumbs || []).join(" / "));

    if (activeMenu.searchable !== false) {
        const search = createElement("input", "menu-search");
        search.type = "text";
        search.placeholder = "Search sigils...";
        search.value = searchValue;
        search.addEventListener("input", () => {
            searchValue = search.value;
            selectedIndex = 0;
            render();
        });
        toolbar.append(search, breadcrumbs);
    } else {
        toolbar.append(breadcrumbs);
    }

    const list = createElement("div", "menu-list");
    renderEntries(list, getEntries());

    const footer = createElement("footer", "menu-footer", "Arrows navigate - Enter select - Backspace close");

    panel.append(header, toolbar, list, footer);
    node.appendChild(panel);
    node.classList.remove("hidden");
    node.setAttribute("aria-hidden", "false");
};

export const openMenu = (payload) => {
    activeMenu = {
        ...(payload.menu || {}),
        callbackId: payload.callbackId || null
    };
    selectedIndex = 0;
    searchValue = "";
    render();
};

export const updateMenu = (payload) => {
    if (!activeMenu) return;
    activeMenu = {
        ...activeMenu,
        ...(payload.menu || {})
    };
    render();
};

export const closeMenu = async (emit = true) => {
    if (!activeMenu) return;
    if (emit) await sendMenuAction("close");
    activeMenu = null;
    selectedIndex = 0;
    searchValue = "";
    render();
};

window.addEventListener("keydown", onKeyDown);

