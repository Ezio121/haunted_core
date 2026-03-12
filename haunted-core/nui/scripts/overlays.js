import { createElement, clamp } from "./utils.js";

let overlayRoot;
let interactionRoot;
const overlays = new Map();

const ensureRoots = () => {
    if (!overlayRoot) overlayRoot = document.getElementById("overlay-root");
    if (!interactionRoot) interactionRoot = document.getElementById("interaction-root");
};

const renderOverlayCard = (name, data) => {
    const wrapper = createElement("div", "overlay-item");
    wrapper.dataset.overlay = name;

    const panel = createElement("div", "overlay-panel");
    const title = createElement("div", "overlay-title", data?.title || name.replace(/_/g, " "));
    const subtitle = createElement("div", "overlay-subtitle", data?.subtitle || "");
    panel.append(title, subtitle);

    if (data?.hint) {
        panel.appendChild(createElement("div", "overlay-whisper", data.hint));
    }

    if (data?.whisper) {
        panel.appendChild(createElement("div", "overlay-whisper", data.whisper));
    }

    if (typeof data?.stability === "number") {
        panel.appendChild(createElement("div", "overlay-whisper", `Stability ${Math.round(clamp(data.stability, 0, 100))}%`));
    }

    wrapper.appendChild(panel);
    return wrapper;
};

export const showOverlay = ({ name, data }) => {
    ensureRoots();
    if (!name) return;

    const previous = overlays.get(name);
    if (previous) previous.remove();

    const element = renderOverlayCard(name, data || {});
    overlays.set(name, element);
    overlayRoot.appendChild(element);
};

export const hideOverlay = ({ name }) => {
    ensureRoots();
    if (!name) return;

    const element = overlays.get(name);
    if (!element) return;

    element.style.animation = "overlayFadeOut 180ms ease forwards";
    window.setTimeout(() => {
        element.remove();
    }, 200);
    overlays.delete(name);
};

export const updateInteraction = ({ prompt }) => {
    ensureRoots();
    interactionRoot.innerHTML = "";

    if (!prompt) {
        return;
    }

    const box = createElement("div", "interaction-prompt");
    const line = createElement("div", "interaction-line");

    const key = createElement("div", "prompt-key", prompt.key || "E");
    const body = createElement("div", "prompt-body");
    body.append(
        createElement("div", "prompt-label", prompt.label || "Interact"),
        createElement("div", "prompt-desc", prompt.description || "")
    );

    line.append(key, body);
    box.appendChild(line);

    if (prompt.hold) {
        const progress = createElement("div", "prompt-progress");
        const fill = createElement("span");
        fill.style.width = `${Math.round(clamp(prompt.progress || 0, 0, 100))}%`;
        progress.appendChild(fill);
        box.appendChild(progress);
    }

    interactionRoot.appendChild(box);
};
