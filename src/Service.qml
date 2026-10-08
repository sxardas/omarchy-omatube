import QtQuick
import Quickshell
import qs.Commons
import "core"
import "js/format.mjs" as Format
import "js/helper.mjs" as Helper
import "js/jobs.mjs" as Jobs
import "js/links.mjs" as Links
import "js/quality.mjs" as Quality
import "js/settings.mjs" as Settings

Item {
    id: root

    readonly property string helperPath: Format.localPath(Qt.resolvedUrl("../bin/omatube"))
    readonly property string installPath: Format.localPath(Qt.resolvedUrl("../install.sh"))
    readonly property string home: Quickshell.env("HOME") || ""

    readonly property string sessionTag: Date.now().toString(36)

    property bool configured: false
    property string downloadDir: Settings.expandDir("", home)
    property string quality: "best"
    property int maxParallel: Settings.LIMITS.maxParallel.value
    property int playlistLimit: Settings.LIMITS.playlistLimit.value
    property string cookies: ""

    function configure(s) {
        s = s || {}
        downloadDir = Settings.expandDir(s.downloadDir, home)
        quality = Quality.normalizeQuality(s.quality) || "best"
        maxParallel = Settings.limit("maxParallel", s.maxParallel)
        playlistLimit = Settings.limit("playlistLimit", s.playlistLimit)
        cookies = Settings.cookiesBrowser(s.cookiesBrowser)
        historyStore.limit = Settings.limit("historyLimit", s.historyLimit)
        if (configured) {
            runNext()
        } else {
            configured = true
            sweepCall.run([helperPath, "sweep", downloadDir])
        }
    }

    property var deps: null
    readonly property bool depsLoaded: deps !== null
    readonly property string setupText: Helper.setupText(deps)
    readonly property bool needsSetup: setupText !== ""
    readonly property bool hasYtdlp: depsLoaded && deps.ytdlp !== ""
    property var updateInfo: null
    readonly property bool checkingUpdate: updateCall.running
    readonly property string updateError: updateInfo && updateInfo.error ? String(updateInfo.error) : ""
    readonly property bool updateChecked: !!updateInfo && !updateError

    readonly property bool updateAvailable: updateChecked && updateInfo.available === true
        && hasYtdlp && deps.ytdlp !== String(updateInfo.latest)

    function checkDeps() {
        checkCall.run()
    }

    function checkUpdate() {
        updateCall.run()
    }

    property var jobs: []

    property var groups: ({})
    property var pendingPlaylists: []
    property int nextId: 1
    property bool swept: false

    property var procs: ({})
    property var lastErrors: ({})

    readonly property var counts: Jobs.counts(jobs)
    readonly property int activeCount: counts.active
    readonly property int queuedCount: counts.queued
    readonly property int openCount: activeCount + queuedCount

    property alias history: historyStore.entries

    function findJob(id) {
        return jobs.find(j => j.id === id) || null
    }

    function patchJob(id, patch) {
        jobs = jobs.map(j => j.id === id ? Object.assign({}, j, patch) : j)
    }

    function dropJob(id) {
        jobs = jobs.filter(j => j.id !== id)
    }

    function add(text, source, qualityKey, dir) {
        const url = Links.youtubeUrl(text)
        if (!url) {
            notify("No YouTube link", source === "clipboard"
                ? "Copy a YouTube link, then right click OmaTube again." : String(text || "").slice(0, 200))
            return false
        }
        const q = Quality.normalizeQuality(qualityKey) || quality
        if (Links.isPlaylistUrl(url)) {
            readPlaylist(url, q)
            return true
        }
        const id = Links.videoId(url)
        if (!id) {
            notify("Not a video link", url)
            return false
        }
        const dup = Jobs.findDuplicate(jobs, id, q)
        if (dup) {
            notify("Already downloading", Jobs.jobTitle(dup))
            return false
        }
        jobs = jobs.concat([Jobs.newJob({
            id: nextId++, url: Links.watchUrl(id), videoId: id, quality: q, root: downloadDir, dir: dir || downloadDir
        })])
        if (source !== "panel") notify("Queued for download", url + " · " + Quality.qualityLabel(q))
        runNext()
        return true
    }

    function runNext() {
        if (!swept || !hasYtdlp) return
        let running = activeCount
        for (const job of jobs) {
            if (running >= maxParallel) break
            if (job.status !== Jobs.QUEUED) continue
            start(job)
            running++
        }
    }

    function start(job) {
        const unit = Helper.unitName(sessionTag, job.id)
        const proc = downloadComponent.createObject(root, {
            jobId: job.id,
            command: Helper.downloadCommand({
                unit: unit,
                helper: helperPath,
                quality: job.quality,
                // Same filesystem as the folder, so the final move is a rename.
                staging: Helper.stagingDir(job.root, sessionTag + "-" + job.id),
                dir: job.dir,
                cookies: cookies,
                url: job.url
            })
        })
        procs[job.id] = proc
        delete lastErrors[job.id]
        patchJob(job.id, {status: Jobs.DOWNLOADING, unit: unit, percent: null})
        proc.running = true
    }

    function stopUnit(unit) {
        if (unit) Util.execArgv(["systemctl", "--user", "stop", unit + ".service"])
    }

    function cancelJob(id) {
        const job = findJob(id)
        if (!job) return
        if (job.status === Jobs.QUEUED) {
            dropJob(id)
            countInGroup(job.groupId, Jobs.CANCELLED)
        } else if (Jobs.isActive(job) && !job.cancelRequested) {
            patchJob(id, {cancelRequested: true})
            stopUnit(job.unit)
        }
    }

    function cancelGroup(groupId) {
        jobs.filter(j => j.groupId === groupId && Jobs.isOpen(j)).forEach(j => cancelJob(j.id))
    }

    function handleLine(jobId, line) {
        const job = findJob(jobId)
        const ev = Helper.parseLine(line)
        if (!job || !ev) return

        if (job.cancelRequested && !job.stopResent) {
            patchJob(jobId, {stopResent: true})
            stopUnit(job.unit)
        }
        if (ev.kind === "error") {
            lastErrors[jobId] = ev.message
            return
        }
        const patch = Jobs.eventPatch(job, ev)
        if (patch) patchJob(jobId, patch)
    }

    function handleExit(jobId, exitCode) {
        const proc = procs[jobId]
        delete procs[jobId]
        if (proc) proc.destroy()

        const job = findJob(jobId)
        if (!job) {
            runNext()
            return
        }
        const inGroup = job.groupId !== 0
        const error = lastErrors[jobId]
        delete lastErrors[jobId]
        let outcome

        if (exitCode === 0 && job.file) {
            outcome = Jobs.DONE
            historyStore.remember(Object.assign({}, job, {status: outcome, percent: 100}))
            if (!inGroup) notify(job.skipped ? "Already downloaded" : "Downloaded", Format.basename(job.file))
        } else {
            stopUnit(job.unit)
            if (job.cancelRequested) {
                outcome = Jobs.CANCELLED
            } else {
                outcome = Jobs.FAILED
                const message = error || (exitCode === 0 ? "Nothing was downloaded" : "yt-dlp stopped with code " + exitCode)
                historyStore.remember(Object.assign({}, job, {status: outcome, error: message}))
                if (!inGroup) notify("Download failed", (job.title ? job.title + "\n" : "") + message, true)
            }
        }
        dropJob(jobId)
        if (inGroup) countInGroup(job.groupId, outcome)
        Qt.callLater(root.runNext)
    }

    function countInGroup(groupId, outcome) {
        if (!groups[groupId]) return
        const g = Jobs.countOutcome(groups[groupId], outcome)
        const next = Object.assign({}, groups)
        next[groupId] = g
        if (!jobs.some(j => j.groupId === groupId && Jobs.isOpen(j))) {
            if (g.done + g.failed > 0) {
                notify(g.failed ? "Playlist finished with errors" : "Playlist downloaded",
                    g.title + "\n" + g.done + " saved" + (g.failed ? ", " + g.failed + " failed" : ""), g.failed > 0)
            }
            delete next[groupId]
        }
        groups = next
    }

    function readPlaylist(url, q) {
        const pendingId = nextId++
        pendingPlaylists = pendingPlaylists.concat([{id: pendingId, url: url}])
        playlistComponent.createObject(root, {quality: q, pendingId: pendingId}).run(Helper.playlistCommand({
            helper: helperPath, url: url, cookies: cookies, limit: playlistLimit
        }))
    }

    function handlePlaylist(raw, q, pendingId) {
        pendingPlaylists = pendingPlaylists.filter(p => p.id !== pendingId)
        const parsed = Helper.parseJson(raw)
        if (!parsed || !Array.isArray(parsed.entries)) {
            notify("Could not read the playlist", Helper.lastError(raw) || "yt-dlp gave no answer", true)
            return
        }
        const fresh = parsed.entries.filter(e => !Jobs.findDuplicate(jobs, e.id, q))
        if (fresh.length === 0) {
            notify("Nothing to add", parsed.title + (parsed.entries.length ? " is already downloading" : " has no videos"))
            return
        }
        const groupId = nextId++
        const dir = downloadDir + "/" + parsed.folder
        const next = Object.assign({}, groups)
        next[groupId] = {title: parsed.title, quality: q, total: fresh.length, done: 0, failed: 0}
        groups = next
        jobs = jobs.concat(fresh.map(e => Jobs.newJob({
            id: nextId++,
            url: e.url,
            videoId: e.id,
            title: e.title,
            quality: q,
            root: downloadDir,
            dir: dir,
            groupId: groupId
        })))
        notify("Playlist queued", parsed.title + "\n" + fresh.length + " videos · " + Quality.qualityLabel(q))
        runNext()
    }

    function removeHistory(entry) {
        historyStore.remove(entry)
    }

    function clearHistory() {
        historyStore.clear()
    }

    function pruneHistory() {
        historyStore.prune()
    }

    function retry(entry) {
        if (entry && add(entry.url, "panel", entry.quality, entry.dir)) historyStore.remove(entry)
    }

    function downloadClipboard() {
        clipboard.run()
    }

    function openFolder() {
        Util.execArgv(["sh", "-c", 'mkdir -p -- "$1" && exec xdg-open "$1"', "sh", downloadDir])
    }

    function openFile(path) {
        if (path) Util.execArgv(["xdg-open", path])
    }

    function notify(summary, body, urgent) {
        Util.execArgv(["notify-send", "-a", "OmaTube", "-i", urgent ? "dialog-error" : "folder-videos",
            "-u", urgent ? "critical" : "normal", summary, body])
    }

    Component.onCompleted: {
        checkDeps()
        configTimeout.start()
    }

    Component.onDestruction: Quickshell.execDetached(["systemctl", "--user", "stop", "omatube-" + sessionTag + "-*.service"])

    Timer {
        id: configTimeout
        interval: 3000
        onTriggered: if (!root.configured) root.configure({})
    }

    HistoryStore {
        id: historyStore
        helperPath: root.helperPath
    }

    Component {
        id: downloadComponent
        DownloadProcess {
            id: download
            onLine: text => root.handleLine(download.jobId, text)
            onProblem: text => {
                if (!root.lastErrors[download.jobId]) root.lastErrors[download.jobId] = text
            }
            onDone: exitCode => root.handleExit(download.jobId, exitCode)
        }
    }

    Component {
        id: playlistComponent
        OutputProcess {
            id: playlistCall
            property string quality: ""
            property int pendingId: 0
            onOutput: text => {
                root.handlePlaylist(text, playlistCall.quality, playlistCall.pendingId)
                playlistCall.destroy()
            }
        }
    }

    OutputProcess {
        id: sweepCall
        onExited: {
            root.swept = true
            root.runNext()
        }
    }

    OutputProcess {
        id: checkCall
        command: [root.helperPath, "check"]
        onOutput: text => {
            root.deps = Helper.parseDeps(text)
            root.runNext()
        }
    }

    OutputProcess {
        id: updateCall
        command: [root.helperPath, "update-check"]
        onOutput: text => root.updateInfo = Helper.parseJson(text) || {error: "Update check failed"}
    }

    OutputProcess {
        id: clipboard
        command: ["wl-paste", "--no-newline", "--type", "text"]
        onOutput: text => root.add(text, "clipboard")
    }
}
