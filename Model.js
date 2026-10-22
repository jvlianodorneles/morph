// Pure geometry, format ranking, URI decoding, and settings lifecycle.

function decodedPath(uriPart) {
    try {
        return decodeURIComponent(uriPart);
    } catch (e) {
        return uriPart;
    }
}

function pathsFromUris(text) {
    var lines = String(text || "").split("\n");
    var out = [];
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].replace("\r", "").trim();
        if (line.length === 0 || line.charAt(0) === "#") continue;
        if (line.indexOf("file://") === 0) {
            out.push(decodedPath(line.substring(7)));
        } else if (line.indexOf("/") === 0) {
            out.push(line);
        }
    }
    return out;
}

function hit(x, y, diameter, count) {
    if (count === undefined) count = 8;
    if (count < 1) return -1;
    var dx = x - diameter / 2;
    var dy = y - diameter / 2;
    var r = Math.sqrt(dx * dx + dy * dy) / diameter;
    if (r < 0.18) return -2; // center hub
    if (r > 0.48) return -1; // outside
    var step = 360 / count;
    var angle = (Math.atan2(dy, dx) * 180 / Math.PI + 90 + step / 2 + 360) % 360;
    return Math.floor(angle / step) % count;
}

function placement(px, py, width, height, reserved, preferred) {
    var r = reserved || [0, 0, 0, 0], pad = 12, footer = 42;
    var left = r[0] + pad, top = r[1] + pad;
    var availableW = Math.max(1, width - r[0] - r[2] - pad * 2);
    var availableH = Math.max(1, height - r[1] - r[3] - pad * 2);
    var size = Math.max(1, Math.min(preferred, availableW, availableH - footer));
    if (size > 280) size = Math.min(size, availableH / (1 + footer / 280));
    var captionScale = Math.max(1, size / 280);
    footer *= captionScale;
    return {
        size: size,
        captionScale: captionScale,
        footer: footer,
        x: Math.max(left, Math.min(px - size / 2, left + availableW - size)),
        y: Math.max(top, Math.min(py - size / 2, top + availableH - size - footer))
    };
}

function prioritizeFormats(category, availableFormats, preferredFormatsMap, slotCount, page) {
    if (!Array.isArray(availableFormats) || availableFormats.length === 0) {
        return { items: [], page: 0, totalPages: 1, totalCount: 0 };
    }
    slotCount = Math.max(6, Math.min(10, slotCount || 8));
    var preferred = (preferredFormatsMap && preferredFormatsMap[category]) || [];

    // Sort available: preferred first (in the order listed in preferred), then any other available alphabetically
    var sorted = [];
    var seen = {};

    for (var i = 0; i < preferred.length; i++) {
        var fmt = String(preferred[i]).toUpperCase();
        if (availableFormats.indexOf(fmt) >= 0 && !seen[fmt]) {
            sorted.push(fmt);
            seen[fmt] = true;
        }
    }

    for (var j = 0; j < availableFormats.length; j++) {
        var f = String(availableFormats[j]).toUpperCase();
        if (!seen[f]) {
            sorted.push(f);
            seen[f] = true;
        }
    }

    var totalPages = Math.max(1, Math.ceil(sorted.length / slotCount));
    var currentPage = Math.max(0, Math.min(totalPages - 1, page || 0));
    var start = currentPage * slotCount;
    var pageItems = sorted.slice(start, start + slotCount);

    return {
        items: pageItems,
        allSorted: sorted,
        page: currentPage,
        totalPages: totalPages,
        totalCount: sorted.length
    };
}

function parse(raw, fallback) {
    try {
        var val = JSON.parse(raw);
        if (!val || typeof val !== "object") return { config: fallback, error: "Invalid configuration object." };
        var diameter = Math.max(220, Math.min(500, Number(val.diameter) || 280));
        var slotCount = Number(val.slotCount) === 6 ? 6 : 8;
        var animation = val.animation !== false;
        var outputDirectoryMode = val.outputDirectoryMode === "custom" ? "custom" : "source";
        var customOutputPath = String(val.customOutputPath || "");
        var notifications = val.notifications !== false;
        var altLeftClick = val.altLeftClick !== false;
        var shortcut = String(val.shortcut || "ALT + C");
        var preferredFormats = val.preferredFormats || (fallback && fallback.preferredFormats) || {};

        return {
            config: {
                diameter: diameter,
                slotCount: slotCount,
                animation: animation,
                outputDirectoryMode: outputDirectoryMode,
                customOutputPath: customOutputPath,
                notifications: notifications,
                altLeftClick: altLeftClick,
                shortcut: shortcut,
                preferredFormats: preferredFormats
            },
            error: ""
        };
    } catch (e) {
        return { config: fallback, error: "Could not parse JSON configuration." };
    }
}

function mergeSettings(currentDoc, draft) {
    var result = JSON.parse(JSON.stringify(currentDoc || {}));
    if (draft.diameter !== undefined) result.diameter = draft.diameter;
    if (draft.slotCount !== undefined) result.slotCount = draft.slotCount;
    if (draft.animation !== undefined) result.animation = draft.animation;
    if (draft.outputDirectoryMode !== undefined) result.outputDirectoryMode = draft.outputDirectoryMode;
    if (draft.customOutputPath !== undefined) result.customOutputPath = draft.customOutputPath;
    if (draft.notifications !== undefined) result.notifications = draft.notifications;
    if (draft.altLeftClick !== undefined) result.altLeftClick = draft.altLeftClick;
    if (draft.shortcut !== undefined) result.shortcut = draft.shortcut;
    if (draft.preferredFormats !== undefined) result.preferredFormats = draft.preferredFormats;
    return result;
}

if (typeof module !== "undefined") {
    module.exports = {
        pathsFromUris: pathsFromUris,
        hit: hit,
        placement: placement,
        prioritizeFormats: prioritizeFormats,
        parse: parse,
        mergeSettings: mergeSettings
    };
}
