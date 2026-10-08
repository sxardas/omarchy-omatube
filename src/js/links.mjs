const MAX_LENGTH = 4096
const ID_RE = /^[A-Za-z0-9_-]{11}$/

export function normalizeUrl(text) {
    let s = String(text || "").slice(0, MAX_LENGTH).trim()
    if (!s || /\s/.test(s)) return ""
    if (/^(www\.|m\.|music\.)?(youtube\.com|youtu\.be)\//i.test(s)) s = "https://" + s
    return /^https?:\/\/[^\/\s]+\.[^\/\s]+/i.test(s) ? s : ""
}

function urlHost(url) {
    const m = /^https?:\/\/([^\/?#:]+)/i.exec(url)
    return m ? m[1].toLowerCase() : ""
}

function urlPath(url) {
    const m = /^https?:\/\/[^\/?#]+(\/[^?#]*)?/i.exec(url)
    return m && m[1] ? m[1] : "/"
}

function queryParam(url, name) {
    const m = new RegExp("[?&]" + name + "=([^&#]*)").exec(url)
    return m ? decodeURIComponent(m[1]) : ""
}

function isYouTubeHost(host) {
    return /^((www|m|music)\.)?youtube\.com$/.test(host) || host === "youtu.be"
        || /^(www\.)?youtube-nocookie\.com$/.test(host)
}

export function youtubeUrl(text) {
    const url = normalizeUrl(text)
    return url && isYouTubeHost(urlHost(url)) ? url : ""
}

export function isYouTubeUrl(text) {
    return youtubeUrl(text) !== ""
}

export function videoId(text) {
    const url = youtubeUrl(text)
    if (!url) return ""
    const path = urlPath(url)
    let id = ""
    if (urlHost(url) === "youtu.be") id = path.split("/")[1] || ""
    else if (path === "/watch") id = queryParam(url, "v")
    else {
        const m = /^\/(shorts|live|embed|v)\/([^\/]+)/.exec(path)
        if (m) id = m[2]
    }
    return ID_RE.test(id) ? id : ""
}

export function isPlaylistUrl(text) {
    const url = youtubeUrl(text)
    return url !== "" && urlPath(url) === "/playlist" && queryParam(url, "list") !== ""
}

export function isDownloadable(text) {
    return videoId(text) !== "" || isPlaylistUrl(text)
}

export function linkProblem(text) {
    if (String(text || "").trim() === "" || isDownloadable(text)) return ""
    return isYouTubeUrl(text) ? "Not a video or playlist link" : "Not a YouTube link"
}

export function watchUrl(id) {
    return "https://www.youtube.com/watch?v=" + id
}
