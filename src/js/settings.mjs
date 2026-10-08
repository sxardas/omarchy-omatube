export const DEFAULT_DIR = "~/Videos/OmaTube"

export const LIMITS = {
    maxParallel: {min: 1, max: 10, step: 1, value: 5},
    playlistLimit: {min: 10, max: 5000, step: 10, value: 1000},
    downloadRows: {min: 5, max: 20, step: 1, value: 10},
    playlistRows: {min: 1, max: 10, step: 1, value: 5},
    historyRows: {min: 5, max: 50, step: 5, value: 10},
    historyLimit: {min: 10, max: 1000, step: 10, value: 100}
}

export function limit(name, value) {
    const l = LIMITS[name]
    let n = Number(value)
    if (value === undefined || value === null || value === "" || !isFinite(n)) return l.value
    n = Math.max(l.min, Math.min(l.max, n))
    return l.min + Math.floor((n - l.min) / l.step) * l.step
}

export function expandDir(configured, home) {
    let dir = String(configured || "").trim() || DEFAULT_DIR
    if (dir === "~") dir = home
    else if (dir.startsWith("~/")) dir = home + dir.slice(1)
    else if (dir.charAt(0) !== "/") dir = home + "/" + dir
    return dir.length > 1 ? dir.replace(/\/+$/, "") : dir
}

export function cookiesBrowser(value) {
    const v = String(value || "").trim().toLowerCase()
    return v === "none" ? "" : v
}
