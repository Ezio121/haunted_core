import { createElement, normalizeIcon } from "./utils.js";

let root;
let counter = 0;
const queue = [];
let maxVisible = 6;

const ensureRoot = () => {
    if (!root) {
        root = document.getElementById("notifications-root");
    }
    return root;
};

const playSound = (name) => {
    if (!name) return;
    const audio = document.querySelector(`audio[data-ui-sound="${name}"]`);
    if (audio) {
        audio.currentTime = 0;
        void audio.play().catch(() => {});
    }
};

const prune = () => {
    while (queue.length > maxVisible) {
        const oldest = queue.shift();
        if (oldest?.el) oldest.el.remove();
    }
};

export const configureNotifications = (config) => {
    const node = ensureRoot();
    maxVisible = Number(config?.MaxVisible || 6);

    const position = String(config?.Position || "top-right").toLowerCase();
    node.classList.remove("top-right", "bottom-right", "top-center");
    if (position === "bottom-right") {
        node.classList.add("bottom-right");
    } else if (position === "top-center") {
        node.classList.add("top-center");
    } else {
        node.classList.add("top-right");
    }
};

export const pushNotification = (payload) => {
    const node = ensureRoot();

    const item = createElement("article", `notify-item ${payload.type || "info"}`);
    item.dataset.id = String(++counter);

    const icon = createElement("div", "notify-icon", normalizeIcon(payload.icon));
    const content = createElement("div", "notify-content");

    const title = createElement("div", "notify-title", payload.title || "Haunted Core");
    const desc = createElement("div", "notify-desc", payload.description || "");

    content.append(title, desc);
    item.append(icon, content);
    node.appendChild(item);

    const record = { id: item.dataset.id, el: item };
    queue.push(record);
    prune();

    const duration = Math.max(800, Number(payload.duration || 4200));
    const timeout = window.setTimeout(() => {
        item.classList.add("exit");
        window.setTimeout(() => {
            item.remove();
        }, 220);

        const idx = queue.findIndex((entry) => entry.id === record.id);
        if (idx >= 0) queue.splice(idx, 1);

        window.clearTimeout(timeout);
    }, duration);

    playSound(payload.sound);
};
