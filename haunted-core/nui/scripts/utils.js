export const isObject = (value) => value !== null && typeof value === "object" && !Array.isArray(value);

export const deepMerge = (target, source) => {
    if (!isObject(target) || !isObject(source)) {
        return source;
    }

    const output = { ...target };
    for (const key of Object.keys(source)) {
        const srcValue = source[key];
        const dstValue = output[key];
        output[key] = isObject(srcValue) ? deepMerge(isObject(dstValue) ? dstValue : {}, srcValue) : srcValue;
    }
    return output;
};

export const clamp = (value, min, max) => Math.min(max, Math.max(min, Number(value) || 0));

export const createElement = (tag, className, text) => {
    const el = document.createElement(tag);
    if (className) {
        el.className = className;
    }
    if (text !== undefined && text !== null) {
        el.textContent = String(text);
    }
    return el;
};

export const formatMoney = (value) => {
    const safe = Number(value) || 0;
    return new Intl.NumberFormat("en-US", {
        maximumFractionDigits: 0
    }).format(safe);
};

export const formatPercent = (value) => `${clamp(value, 0, 100)}%`;

export const iconGlyph = {
    ghost: "G",
    sigil: "S",
    rune: "R",
    skull: "X",
    warning: "!",
    close: "x",
    phase: "P",
    veil: "V",
    possession: "O",
    whisper: "W",
    haunt: "H",
    return: "<",
    interact: "E"
};

export const normalizeIcon = (iconName) => {
    const key = String(iconName || "sigil").toLowerCase();
    return iconGlyph[key] || key.charAt(0).toUpperCase();
};

export const postNui = async (endpoint, payload = {}) => {
    try {
        const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : "haunted-core";
        const response = await fetch(`https://${resourceName}/${endpoint}`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json; charset=UTF-8"
            },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            return null;
        }

        return await response.json();
    } catch (_err) {
        return null;
    }
};

export const stateDiff = (next, prev) => {
    if (!isObject(next) || !isObject(prev)) {
        return true;
    }

    const keys = new Set([...Object.keys(next), ...Object.keys(prev)]);
    for (const key of keys) {
        const a = next[key];
        const b = prev[key];
        if (isObject(a) && isObject(b)) {
            if (stateDiff(a, b)) {
                return true;
            }
            continue;
        }

        if (Array.isArray(a) && Array.isArray(b)) {
            if (a.length !== b.length) {
                return true;
            }

            for (let i = 0; i < a.length; i += 1) {
                if (isObject(a[i]) && isObject(b[i])) {
                    if (stateDiff(a[i], b[i])) {
                        return true;
                    }
                } else if (a[i] !== b[i]) {
                    return true;
                }
            }
            continue;
        }

        if (a !== b) {
            return true;
        }
    }

    return false;
};
