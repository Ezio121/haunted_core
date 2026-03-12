import { postNui } from "./utils.js";

const handlers = new Map();

export const onMessage = (type, handler) => {
    handlers.set(type, handler);
};

export const emitMessage = (type, payload) => {
    const handler = handlers.get(type);
    if (handler) {
        handler(payload || {});
    }
};

window.addEventListener("message", (event) => {
    const data = event.data;
    if (!data || typeof data.type !== "string") {
        return;
    }

    emitMessage(data.type, data.payload || {});
});

window.addEventListener("keydown", async (event) => {
    if (event.key !== "Escape") {
        return;
    }

    await postNui("haunted:ui:close", {});
    emitMessage("haunted:menu:close", {});
    emitMessage("haunted:radial:close", {});
});

export const setupReady = async () => {
    await postNui("haunted:ui:ready", {});
};
