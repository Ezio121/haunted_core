import { createElement, postNui } from "./utils.js";

let root;
let activeRadial = null;
let selectedIndex = -1;

const ensureRoot = () => {
    if (!root) root = document.getElementById("radial-root");
    return root;
};

const sendRadialAction = async (action, slice = null, meta = {}) => {
    await postNui("haunted:ui:radialAction", {
        action,
        slice,
        meta,
        callbackId: activeRadial?.callbackId || null
    });
};

const normalizeSlices = (slices) => {
    if (!Array.isArray(slices)) return [];
    return slices.map((slice, index) => ({
        id: String(slice.id || index),
        label: String(slice.label || "Action"),
        icon: String(slice.icon || "sigil"),
        cooldown: Number(slice.cooldown || 0),
        locked: slice.locked === true,
        submenu: slice.submenu,
        close: slice.close === true,
        back: slice.back === true,
        ability: slice.ability,
        meta: slice.meta || {}
    }));
};

const render = () => {
    const node = ensureRoot();
    node.innerHTML = "";

    if (!activeRadial) {
        node.classList.add("hidden");
        node.setAttribute("aria-hidden", "true");
        return;
    }

    const wrap = createElement("section", "radial-wrap interactive");
    const ring = createElement("div", "radial-ring");
    const center = createElement("div", "radial-center");

    const centerTitle = createElement("div", "title", activeRadial.title || "Spectral Wheel");
    const centerSubtitle = createElement("div", "subtitle", activeRadial.subtitle || "Select an ability");
    center.append(centerTitle, centerSubtitle);

    const slices = normalizeSlices(activeRadial.slices);
    const step = 360 / Math.max(1, slices.length);

    slices.forEach((slice, index) => {
        const wedge = createElement("button", "radial-slice");
        wedge.type = "button";
        wedge.style.setProperty("--slice-rotation", `${(index * step) - (step / 2)}deg`);

        if (index === selectedIndex) wedge.classList.add("selected");
        if (slice.locked) wedge.classList.add("locked");

        const hit = createElement("div", "hit");
        const label = createElement("div", "label", slice.label);
        const cooldown = createElement("div", "cooldown", slice.cooldown > 0 ? `${Math.ceil(slice.cooldown / 1000)}s` : "");

        wedge.append(hit, label, cooldown);

        wedge.addEventListener("mouseenter", () => {
            selectedIndex = index;
            render();
        });

        wedge.addEventListener("click", async () => {
            if (slice.locked) return;
            await sendRadialAction("select", slice);
        });

        wrap.appendChild(wedge);
    });

    wrap.append(ring, center);
    node.appendChild(wrap);
    node.classList.remove("hidden");
    node.setAttribute("aria-hidden", "false");
};

const keyHandler = async (event) => {
    if (!activeRadial) return;

    const slices = normalizeSlices(activeRadial.slices);
    if (slices.length === 0) return;

    if (event.key === "ArrowRight" || event.key === "d" || event.key === "D") {
        event.preventDefault();
        selectedIndex = (selectedIndex + 1 + slices.length) % slices.length;
        render();
        return;
    }

    if (event.key === "ArrowLeft" || event.key === "a" || event.key === "A") {
        event.preventDefault();
        selectedIndex = (selectedIndex - 1 + slices.length) % slices.length;
        render();
        return;
    }

    if (event.key === "Enter") {
        event.preventDefault();
        const slice = slices[selectedIndex] || slices[0];
        if (slice && !slice.locked) {
            await sendRadialAction("select", slice);
        }
        return;
    }

    if (event.key === "Backspace" || event.key === "Escape") {
        event.preventDefault();
        await closeRadial();
    }
};

window.addEventListener("keydown", keyHandler);

export const openRadial = (payload) => {
    activeRadial = {
        ...(payload.radial || {}),
        callbackId: payload.callbackId || null
    };
    selectedIndex = 0;
    render();
};

export const closeRadial = async (emit = true) => {
    if (!activeRadial) return;
    if (emit) await sendRadialAction("close", null);
    activeRadial = null;
    selectedIndex = -1;
    render();
};
