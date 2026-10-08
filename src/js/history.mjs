import { DONE, FAILED, jobDetail } from "./jobs.mjs"
import { LIMITS } from "./settings.mjs"

export function historyEntry(job, now) {
  return {
    videoId: job.videoId || "",
    url: job.url || "",
    title: job.title || "",
    quality: job.quality || "",
    label: job.label || "",
    status: job.status,
    file: job.file || "",
    size: job.size || 0,
    error: job.error || "",
    skipped: !!job.skipped,
    dir: job.dir || "",
    finishedAt: now
  }
}

export function historyKey(h) {
  return [h.status, h.file || h.url, h.quality, h.finishedAt].join("|")
}

export function historyDetail(h) {
  if (!h) return ""
  return h.status === FAILED ? (h.error || "Download failed") + " · click to retry" : jobDetail(h)
}

function cap(max) {
  const n = Number(max)
  return n > 0 ? Math.floor(n) : LIMITS.historyLimit.value
}

export function parseHistory(raw, max) {
  let parsed
  try {
    parsed = JSON.parse(String(raw || "[]"))
  } catch (e) {
    return []
  }
  if (!Array.isArray(parsed)) return []
  return parsed.filter(h => h && typeof h === "object" && (h.status === DONE || h.status === FAILED) && h.url)
    .slice(0, cap(max))
}

export function addToHistory(history, entry, max) {
  const rest = (history || []).filter(h => !(entry.file && h.file === entry.file)
    && !(h.status === FAILED && h.videoId === entry.videoId && h.quality === entry.quality))
  return [entry].concat(rest).slice(0, cap(max))
}

export function serializeHistory(history, max) {
  return JSON.stringify((history || []).slice(0, cap(max)), null, 1) + "\n"
}

export function doneFiles(history) {
  return history.filter(h => h.status === DONE && h.file).map(h => h.file)
}

export function withoutFiles(history, missing) {
  return history.filter(h => !(h.status === DONE && missing.indexOf(h.file) >= 0))
}
