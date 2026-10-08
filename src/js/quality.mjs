export const QUALITIES = [
    {key: "best", label: "Best", tip: "The highest the video has, up to 4K and beyond"},
    {key: "1080", label: "1080p"},
    {key: "720", label: "720p"},
    {key: "480", label: "480p"},
    {key: "audio", label: "Audio", tip: "The original audio stream, not re-encoded (m4a or opus)"}
]

export function normalizeQuality(value) {
    const v = String(value || "").trim().toLowerCase()
    const q = QUALITIES.find(q => v === q.key || v === q.label.toLowerCase())
    if (q) return q.key
    return v === "mp3" || v === "audio (mp3)" ? "audio" : ""
}

export function qualityLabel(key) {
    const q = QUALITIES.find(q => q.key === key)
    return q ? q.label : ""
}

export function qualityTip(q) {
    return q.tip || "At most " + q.label + "; less when the video has no " + q.label
}
