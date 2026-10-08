import test from "node:test"
import assert from "node:assert/strict"
import * as Q from "../src/js/quality.mjs"
import * as S from "../src/js/settings.mjs"
import * as L from "../src/js/links.mjs"
import * as H from "../src/js/helper.mjs"
import * as J from "../src/js/jobs.mjs"
import * as Hist from "../src/js/history.mjs"
import * as R from "../src/js/rows.mjs"

test("quality keys and labels", () => {
    assert.equal(Q.normalizeQuality("1080p"), "1080")
    assert.equal(Q.normalizeQuality("Best"), "best")
    assert.equal(Q.normalizeQuality("Audio"), "audio")
    assert.equal(Q.normalizeQuality("MP3"), "audio")
    assert.equal(Q.normalizeQuality("2160"), "")
    assert.equal(Q.qualityTip(Q.QUALITIES[2]), "At most 720p; less when the video has no 720p")
})

test("only YouTube links are accepted", () => {
    assert.ok(L.isYouTubeUrl("https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
    assert.ok(L.isYouTubeUrl("youtu.be/dQw4w9WgXcQ"))
    assert.ok(L.isYouTubeUrl("https://music.youtube.com/watch?v=dQw4w9WgXcQ"))
    assert.ok(L.isYouTubeUrl("https://m.youtube.com/shorts/dQw4w9WgXcQ"))
    assert.ok(!L.isYouTubeUrl("https://vimeo.com/12345"))
    assert.ok(!L.isYouTubeUrl("https://youtube.com.evil.example/watch?v=dQw4w9WgXcQ"))
    assert.ok(!L.isYouTubeUrl("file:///etc/passwd"))
    assert.ok(!L.isYouTubeUrl("two words"))
    assert.equal(L.youtubeUrl("  youtu.be/dQw4w9WgXcQ "), "https://youtu.be/dQw4w9WgXcQ")
})

test("video ids from every link shape", () => {
    const id = "dQw4w9WgXcQ"
    assert.equal(L.videoId("https://www.youtube.com/watch?v=" + id), id)
    assert.equal(L.videoId("https://www.youtube.com/watch?feature=share&v=" + id + "&t=42"), id)
    assert.equal(L.videoId("https://youtu.be/" + id + "?si=abc"), id)
    assert.equal(L.videoId("https://www.youtube.com/shorts/" + id), id)
    assert.equal(L.videoId("https://www.youtube.com/live/" + id), id)
    assert.equal(L.videoId("https://www.youtube.com/playlist?list=PL123"), "")
    assert.equal(L.videoId("https://www.youtube.com/watch?v=short"), "")
})

test("a watch link with list= is the one video, not a playlist", () => {
    const mix = "https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=RDdQw4w9WgXcQ&start_radio=1"
    assert.ok(!L.isPlaylistUrl(mix))
    assert.equal(L.videoId(mix), "dQw4w9WgXcQ")
    assert.ok(L.isPlaylistUrl("https://www.youtube.com/playlist?list=PLabc"))
    assert.ok(!L.isPlaylistUrl("https://www.youtube.com/playlist"))
})

test("links the panel can download", () => {
    assert.ok(L.isDownloadable("https://youtu.be/dQw4w9WgXcQ"))
    assert.ok(L.isDownloadable("https://www.youtube.com/playlist?list=PLabc"))
    assert.ok(!L.isDownloadable("https://www.youtube.com/@BlenderStudio"))
    assert.ok(!L.isDownloadable("https://vimeo.com/1"))
    assert.equal(L.linkProblem(""), "")
    assert.equal(L.linkProblem("https://vimeo.com/1"), "Not a YouTube link")
    assert.equal(L.linkProblem("https://www.youtube.com/@BlenderStudio"), "Not a video or playlist link")
})

test("helper lines", () => {
    const p = H.parseLine("OMATUBE_PROGRESS downloading|100|NA|400|50.5|3")
    assert.deepEqual(p, {kind: "progress", status: "downloading", downloaded: 100, total: 400, speed: 50.5, eta: 3})
    const item = H.parseLine('OMATUBE_ITEM {"id":"x","title":"T","label":"720p","streams":2,"duration":19}')
    assert.equal(item.label, "720p")
    assert.equal(item.streams, 2)
    assert.deepEqual(H.parseLine("OMATUBE_EXISTS /a/b (720p) [x].mp4"), {kind: "exists", path: "/a/b (720p) [x].mp4"})
    assert.equal(H.parseLine("ERROR: [youtube] abc: Video unavailable").message, "Video unavailable")
    assert.equal(H.parseLine("[download] something"), null)
    assert.equal(H.parseLine("noise"), null)
    assert.equal(H.lastError("warning\nERROR: [youtube] abc: Private video"), "Private video")
})

test("progress events move a job through its streams", () => {
    let job = J.newJob({id: 1, status: J.DOWNLOADING})
    const apply = line => {
        job = Object.assign({}, job, J.eventPatch(job, H.parseLine(line)))
    }
    apply('OMATUBE_ITEM {"id":"x","title":"T","label":"720p","streams":2}')
    apply("OMATUBE_PROGRESS downloading|50|100|NA|10|5")
    assert.equal(job.percent, 25)
    apply("OMATUBE_PROGRESS finished|100|100|NA|NA|NA")
    assert.equal(job.percent, 50)
    assert.equal(job.size, 100)
    apply("OMATUBE_PROGRESS finished|20|20|NA|NA|NA")
    assert.equal(job.status, J.PROCESSING)
    apply("OMATUBE_FILE /v/T (720p).mp4")
    assert.equal(job.file, "/v/T (720p).mp4")
    assert.equal(J.eventPatch(job, {kind: "error", message: "x"}), null)
})

test("quality note shows a fallback", () => {
    assert.equal(J.qualityNote({quality: "1080", label: "720p"}), "720p (no 1080p)")
    assert.equal(J.qualityNote({quality: "1080", label: "1080p"}), "1080p")
    assert.equal(J.qualityNote({quality: "best", label: "2160p"}), "2160p")
    assert.equal(J.qualityNote({quality: "audio", label: "audio"}), "Audio")
    assert.equal(J.qualityNote({quality: "720", label: ""}), "720p")
})

test("duplicates are open jobs with the same video and quality", () => {
    const jobs = [
        {videoId: "a", quality: "720", status: J.DOWNLOADING},
        {videoId: "b", quality: "720", status: J.DONE}
    ]
    assert.ok(J.findDuplicate(jobs, "a", "720"))
    assert.equal(J.findDuplicate(jobs, "a", "1080"), null)
    assert.equal(J.findDuplicate(jobs, "b", "720"), null)
})

test("download folder expansion", () => {
    assert.equal(S.expandDir("~/Videos/OmaTube", "/home/u"), "/home/u/Videos/OmaTube")
    assert.equal(S.expandDir("", "/home/u"), "/home/u/Videos/OmaTube")
    assert.equal(S.expandDir("Movies/", "/home/u"), "/home/u/Movies")
    assert.equal(S.expandDir("/mnt/media", "/home/u"), "/mnt/media")
})

test("systemd command keeps paths literal", () => {
    assert.equal(H.execWord('/a b/100%/$x"'), '"/a b/100%%/$$x\\""')
    const cmd = H.downloadCommand({
        unit: "omatube-t-1", helper: "/p/bin/omatube", quality: "720",
        staging: "/v/.omatube.cache/t-1", dir: "/v", url: "https://youtu.be/x", cookies: ""
    })
    assert.ok(cmd.includes("--expand-environment=no"))
    assert.ok(cmd.includes('ExecStopPost="/p/bin/omatube" cleanup'))
    assert.ok(cmd.includes("OMATUBE_DIR=/v"))
    assert.deepEqual(cmd.slice(-2), ["--", "https://youtu.be/x"])
    assert.ok(!cmd.includes("--cookies"))
    assert.deepEqual(H.playlistCommand({helper: "/h", url: "u", cookies: "firefox", limit: 10}),
        ["/h", "playlist", "--limit", "10", "--cookies", "firefox", "--", "u"])
})

test("playlist summaries count finished videos from the group", () => {
    const jobs = [
        {groupId: 1, status: J.DOWNLOADING, percent: 50},
        {groupId: 1, status: J.QUEUED},
        {groupId: 2, status: J.QUEUED}
    ]
    const s = J.groupSummaries(jobs, {1: {total: 4, done: 1, failed: 1}})[1]
    assert.equal(s.active, 1)
    assert.equal(s.queued, 1)
    assert.equal(s.percent, (200 + 50) / 4)
    assert.equal(J.groupDetail(s), "2/4 · 1 downloading · 1 failed")
    const g = {total: 3, done: 0, failed: 0}
    assert.deepEqual(J.countOutcome(g, J.CANCELLED), {total: 2, done: 0, failed: 0})
    assert.deepEqual(J.countOutcome(g, J.DONE), {total: 3, done: 1, failed: 0})
    assert.deepEqual(J.counts(jobs), {active: 1, queued: 2})
})

test("a cancel shows at once", () => {
    assert.equal(J.jobDetail({status: J.DOWNLOADING, cancelRequested: true, quality: "720"}), "Cancelling…")
    assert.equal(J.jobDetail({status: J.CANCELLED, cancelRequested: true}), "Cancelled")
})

test("history keeps done and failed, newest first, capped", () => {
    const max = S.LIMITS.historyLimit.value
    let h = []
    for (let i = 0; i < max + 5; i++) {
        h = Hist.addToHistory(h, {videoId: "v" + i, quality: "720", status: J.DONE, url: "u", file: "/f" + i})
    }
    assert.equal(h.length, max)
    assert.equal(h[0].file, "/f" + (max + 4))
    h = Hist.addToHistory([{videoId: "a", quality: "720", status: J.FAILED, url: "u"}],
        {videoId: "a", quality: "720", status: J.DONE, url: "u", file: "/a"})
    assert.equal(h.length, 1)
    assert.equal(Hist.parseHistory('[{"status":"cancelled","url":"u"},{"status":"done","url":"u"}]').length, 1)
    assert.deepEqual(Hist.parseHistory("not json"), [])
    const five = h.slice(0, 1).concat([1, 2, 3, 4, 5, 6].map(i => ({
        videoId: "x" + i,
        quality: "720",
        status: J.DONE,
        url: "u",
        file: "/x" + i
    })))
    assert.equal(Hist.addToHistory(five, {
        videoId: "n",
        quality: "720",
        status: J.DONE,
        url: "u",
        file: "/n"
    }, 5).length, 5)
    assert.equal(JSON.parse(Hist.serializeHistory(five, 3)).length, 3)
    assert.equal(Hist.historyEntry({status: J.FAILED, dir: "/v/List"}, 1).dir, "/v/List")
    assert.notEqual(Hist.historyKey({status: "done", file: "/a", quality: "720", finishedAt: 1}),
        Hist.historyKey({status: "done", file: "/a", quality: "720", finishedAt: 2}))
    assert.deepEqual(Hist.withoutFiles(five, ["/x1", "/x2"]).map(e => e.file), ["/a", "/x3", "/x4", "/x5", "/x6"])
    assert.equal(Hist.historyDetail({status: J.FAILED, error: "Gone"}), "Gone · click to retry")
})

test("setup text names what is missing", () => {
    assert.equal(H.setupText({ytdlp: "1", ffmpeg: true, deno: true}), "")
    assert.equal(H.setupText({ytdlp: "", ffmpeg: true, deno: false}),
        "yt-dlp and deno are not installed. Finish setup to install them.")
    assert.equal(H.setupText(null), "")
    assert.deepEqual(H.parseDeps("garbage"), {ytdlp: "", ffmpeg: false, deno: false})
})

test("numeric settings default, clamp and land on their steps", () => {
    assert.equal(S.limit("maxParallel", undefined), 5)
    assert.equal(S.limit("maxParallel", "abc"), 5)
    assert.equal(S.limit("maxParallel", 50), 10)
    assert.equal(S.limit("maxParallel", 0), 1)
    assert.equal(S.limit("playlistLimit", 0), 10)
    assert.equal(S.limit("playlistLimit", 123), 120)
    assert.equal(S.limit("historyRows", 12), 10)
    assert.equal(S.limit("historyLimit", 205), 200)
    for (const [name, l] of Object.entries(S.LIMITS)) {
        for (const v of [l.min, l.value, l.max]) assert.equal(S.limit(name, v), v, name + " " + v)
        for (let v = l.min - 3; v <= l.max + 3; v++) assert.equal(S.limit(name, v) % l.step, 0, name + " " + v)
    }
})

test("download rows: playlists first videos, collapsed groups, the cap", () => {
    const jobs = [
        {id: 1, groupId: 0, status: J.DOWNLOADING},
        {id: 2, groupId: 9, status: J.DOWNLOADING},
        {id: 3, groupId: 9, status: J.QUEUED},
        {id: 4, groupId: 9, status: J.QUEUED}
    ]
    const o = {pending: [{id: 7}], jobs: jobs, collapsed: {}, playlistRows: 2, maxRows: 10}
    assert.deepEqual(R.openRowKeys(o).keys, ["reading:7", "job:1", "group:9", "job:2", "job:3"])
    assert.deepEqual(R.openRowKeys(Object.assign({}, o, {collapsed: {9: true}})).keys, ["reading:7", "job:1", "group:9"])
    assert.deepEqual(R.openRowKeys(Object.assign({}, o, {maxRows: 3})), {
        keys: ["reading:7", "job:1", "group:9"],
        hidden: 2
    })
    assert.deepEqual(R.parseKey("group:9"), {kind: "group", id: 9})
})

test("list model sync keeps, moves, inserts and removes", () => {
    const rows = [{key: "a"}, {key: "b"}, {key: "c"}]
    const model = {
        get count() {
            return rows.length
        },
        get: i => rows[i],
        remove: i => rows.splice(i, 1),
        move: (from, to) => rows.splice(to, 0, rows.splice(from, 1)[0]),
        insert: (i, row) => rows.splice(i, 0, row)
    }
    R.syncModel(model, ["c", "d", "a"])
    assert.deepEqual(rows.map(r => r.key), ["c", "d", "a"])
})
