export function formatBytes(bytes) {
    if (bytes === null || bytes === undefined || !isFinite(bytes)) return ""
    const units = ["B", "KiB", "MiB", "GiB"]
    let i = 0
    let v = bytes
    while (v >= 1024 && i < units.length - 1) {
        v /= 1024
        i++
    }
    return (i === 0 ? Math.round(v) : v.toFixed(v >= 100 ? 0 : 1)) + " " + units[i]
}

export function formatDuration(seconds) {
    if (seconds === null || seconds === undefined || !isFinite(seconds) || seconds < 0) return ""
    const s = Math.round(seconds)
    const h = Math.floor(s / 3600)
    const m = Math.floor((s % 3600) / 60)
    const pad = x => (x < 10 ? "0" : "") + x
    return (h > 0 ? h + ":" + pad(m) : m) + ":" + pad(s % 60)
}

export function basename(path) {
    const s = String(path || "")
    return s.slice(s.lastIndexOf("/") + 1)
}

export function localPath(url) {
    return decodeURIComponent(String(url).replace(/^file:\/\//, ""))
}
