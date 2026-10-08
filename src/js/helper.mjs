export const CACHE_NAME = ".omatube.cache"

export function parseJson(raw) {
    try {
        const parsed = JSON.parse(String(raw || "").trim())
        return parsed && typeof parsed === "object" ? parsed : null
    } catch (e) {
        return null
    }
}

function num(value) {
    if (value === undefined || value === null || value === "NA" || value === "") return null
    const n = Number(value)
    return isFinite(n) ? n : null
}

export function cleanError(message) {
    return String(message || "").replace(/^\[[^\]]+\]\s*[^:\s]+:\s*/, "").trim()
}

export function lastError(raw) {
    const line = String(raw || "").trim().split("\n").pop()
    return cleanError(line.replace(/^ERROR:\s*/, ""))
}

export function parseLine(line) {
    const s = String(line || "")
    const space = s.indexOf(" ")
    const rest = s.slice(space + 1)
    switch (s.slice(0, space)) {
        case "OMATUBE_PROGRESS": {
            const f = rest.split("|")
            const total = num(f[2])
            return {
                kind: "progress",
                status: f[0],
                downloaded: num(f[1]),
                total: total === null ? num(f[3]) : total,
                speed: num(f[4]),
                eta: num(f[5])
            }
        }
        case "OMATUBE_ITEM": {
            const item = parseJson(rest) || {}
            return {
                kind: "item",
                id: String(item.id || ""),
                title: String(item.title || ""),
                label: String(item.label || ""),
                streams: Math.max(1, num(item.streams) || 1),
                duration: num(item.duration)
            }
        }
        case "OMATUBE_EXISTS":
            return {kind: "exists", path: rest}
        case "OMATUBE_FILE":
            return {kind: "file", path: rest}
        case "ERROR:":
            return {kind: "error", message: cleanError(rest)}
    }
    return null
}

export function parseDeps(raw) {
    const p = parseJson(raw) || {}
    return {ytdlp: String(p.ytdlp || ""), ffmpeg: p.ffmpeg === true, deno: p.deno === true}
}

function missingTools(deps) {
    if (!deps) return []
    return [["yt-dlp", deps.ytdlp], ["ffmpeg", deps.ffmpeg], ["deno", deps.deno]]
        .filter(t => !t[1]).map(t => t[0])
}

export function needsSetup(deps) {
    return missingTools(deps).length > 0
}

export function setupText(deps) {
    const missing = missingTools(deps)
    if (missing.length === 0) return ""
    const many = missing.length > 1
    return missing.join(", ").replace(/, ([^,]*)$/, " and $1")
        + (many ? " are" : " is") + " not installed. Finish setup to install " + (many ? "them." : "it.")
}

export function stagingDir(downloadDir, name) {
    return downloadDir + "/" + CACHE_NAME + "/" + name
}

export function unitName(tag, jobId) {
    return "omatube-" + tag + "-" + jobId
}

export function execWord(value) {
    return '"' + String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
        .replace(/%/g, "%%").replace(/\$/g, "$$$$") + '"'
}

export function downloadCommand(o) {
    const cmd = [
        "systemd-run", "--user", "--pipe", "--wait", "--collect", "--quiet",
        "--service-type=exec", "--expand-environment=no",
        "--unit", o.unit,
        "-p", "KillMode=control-group",
        "-p", "TimeoutStopSec=5",
        "--setenv", "OMATUBE_STAGING=" + o.staging,
        "--setenv", "OMATUBE_DIR=" + o.dir,
        "-p", "ExecStopPost=" + execWord(o.helper) + " cleanup",
        "--", o.helper, "download",
        "--quality", o.quality,
        "--staging", o.staging,
        "--dir", o.dir
    ]
    if (o.cookies) cmd.push("--cookies", o.cookies)
    return cmd.concat(["--", o.url])
}

export function playlistCommand(o) {
    const cmd = [o.helper, "playlist", "--limit", String(o.limit)]
    if (o.cookies) cmd.push("--cookies", o.cookies)
    return cmd.concat(["--", o.url])
}
