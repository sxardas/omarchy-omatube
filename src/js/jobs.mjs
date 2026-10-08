import {qualityLabel} from "./quality.mjs"
import {formatBytes, formatDuration} from "./format.mjs"

export const QUEUED = "queued"
export const DOWNLOADING = "downloading"
export const PROCESSING = "processing"
export const DONE = "done"
export const FAILED = "failed"
export const CANCELLED = "cancelled"

export const BAR_ICON = "󰗃"

const ICONS = {
    [QUEUED]: "󰔟",
    [DOWNLOADING]: "󰇚",
    [PROCESSING]: "󰑓",
    [DONE]: "󰄬",
    [CANCELLED]: "󰜺",
    [FAILED]: "󰅚"
}

export function newJob(fields) {
    return Object.assign({
        groupId: 0,
        status: QUEUED,
        title: "",
        label: "",
        streams: 1,
        streamIndex: 0,
        percent: null,
        speed: null,
        eta: null,
        size: 0,
        file: "",
        error: "",
        skipped: false,
        unit: "",
        cancelRequested: false
    }, fields)
}

export function isActive(job) {
    return !!job && (job.status === DOWNLOADING || job.status === PROCESSING)
}

export function isOpen(job) {
    return !!job && (job.status === QUEUED || isActive(job))
}

export function counts(jobs) {
    const c = {active: 0, queued: 0}
    for (const j of jobs) {
        if (isActive(j)) c.active++
        else if (j.status === QUEUED) c.queued++
    }
    return c
}

export function indexById(jobs) {
    const map = {}
    for (const j of jobs) map[j.id] = j
    return map
}

export function findDuplicate(jobs, id, quality) {
    if (!id) return null
    return (jobs || []).find(j => j.videoId === id && j.quality === quality && isOpen(j)) || null
}

function overallPercent(streamIndex, streams, downloaded, total) {
    const n = Math.max(1, streams || 1)
    const frac = total > 0 && downloaded !== null ? Math.min(1, downloaded / total) : 0
    const done = Math.min(n, Math.max(0, streamIndex || 0))
    return Math.max(0, Math.min(100, ((done + frac) / n) * 100))
}

export function eventPatch(job, ev) {
    switch (ev.kind) {
        case "item":
            return {title: ev.title || job.title, label: ev.label, streams: ev.streams, streamIndex: 0, percent: 0}
        case "progress": {
            const finished = ev.status === "finished"
            const streamIndex = job.streamIndex + (finished ? 1 : 0)
            const patch = {
                streamIndex: streamIndex,
                size: job.size + (finished ? ev.total || ev.downloaded || 0 : 0),
                speed: ev.speed,
                eta: ev.eta,
                percent: finished
                    ? overallPercent(streamIndex, job.streams, 0, 0)
                    : overallPercent(streamIndex, job.streams, ev.downloaded, ev.total)
            }
            if (finished && streamIndex >= job.streams && job.streams > 1) patch.status = PROCESSING
            else if (ev.status === "downloading") patch.status = DOWNLOADING
            return patch
        }
        case "exists":
            return {file: ev.path, skipped: true, percent: 100}
        case "file":
            return {file: ev.path, percent: 100}
    }
    return null
}

export function jobTitle(job) {
    return job ? job.title || job.url || "" : ""
}

export function qualityNote(job) {
    if (!job) return ""
    if (job.quality === "audio") return "Audio"
    const label = String(job.label || "")
    if (!label) return qualityLabel(job.quality)
    if (job.quality === "best" || label === job.quality + "p") return label
    return label + " (no " + job.quality + "p)"
}

export function jobDetail(job) {
    if (!job) return ""
    if (job.cancelRequested && isOpen(job)) return "Cancelling…"
    switch (job.status) {
        case QUEUED:
            return "Queued · " + qualityLabel(job.quality)
        case DOWNLOADING: {
            if (job.percent === null || job.percent === undefined) return "Starting · " + qualityLabel(job.quality)
            const parts = [Math.floor(job.percent) + "%", qualityNote(job)]
            if (job.speed) parts.push(formatBytes(job.speed) + "/s")
            if (job.eta > 0) parts.push(formatDuration(job.eta) + " left")
            return parts.join(" · ")
        }
        case PROCESSING:
            return "Merging video and audio · " + qualityNote(job)
        case DONE: {
            const parts = [job.skipped ? "Already downloaded" : "Saved", qualityNote(job)]
            if (job.size) parts.push(formatBytes(job.size))
            return parts.join(" · ")
        }
        case CANCELLED:
            return "Cancelled"
        case FAILED:
            return job.error || "Download failed"
    }
    return ""
}

export function statusIcon(status) {
    return ICONS[status] || ""
}

export function groupSummaries(jobs, groups) {
    const out = {}
    for (const id in groups) {
        const g = groups[id]
        out[id] = {total: g.total || 0, done: g.done || 0, failed: g.failed || 0, active: 0, queued: 0, sum: 0}
    }
    for (const j of jobs) {
        const s = out[j.groupId]
        if (!s) continue
        if (isActive(j)) {
            s.active++
            s.sum += j.percent || 0
        } else if (j.status === QUEUED) s.queued++
    }
    for (const id in out) {
        const s = out[id]
        s.percent = s.total ? ((s.done + s.failed) * 100 + s.sum) / s.total : 0
        delete s.sum
    }
    return out
}

export function groupDetail(s) {
    const parts = [(s.done + s.failed) + "/" + s.total]
    if (s.active) parts.push(s.active + " downloading")
    if (s.failed) parts.push(s.failed + " failed")
    return parts.join(" · ")
}

export function countOutcome(group, outcome) {
    const g = Object.assign({}, group)
    if (outcome === DONE) g.done++
    else if (outcome === FAILED) g.failed++
    else g.total = Math.max(0, g.total - 1)
    return g
}

export function barTooltip(jobs) {
    const c = counts(jobs)
    if (c.active + c.queued === 0) return "OmaTube · Right click downloads the copied link · Middle click opens the folder"
    const lines = ["OmaTube · " + c.active + " downloading" + (c.queued ? ", " + c.queued + " queued" : "")]
    for (const j of jobs.filter(isActive).slice(0, 3)) {
        const p = j.percent
        lines.push((p === null || p === undefined ? "…" : Math.floor(p) + "%") + "  " + jobTitle(j))
    }
    return lines.join("\n")
}
