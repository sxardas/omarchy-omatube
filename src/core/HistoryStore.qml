import QtQuick
import Quickshell
import Quickshell.Io
import "../js/helper.mjs" as Helper
import "../js/history.mjs" as History
import "../js/settings.mjs" as Settings

Item {
    id: store

    required property string helperPath
    property int limit: Settings.LIMITS.historyLimit.value
    property var entries: []
    property bool loaded: false
    readonly property string dir: (Quickshell.env("HOME") || "") + "/.local/state/omatube"

    function save(list) {
        entries = list
        if (loaded) file.setText(History.serializeHistory(list, limit))
    }

    function remember(job) {
        save(History.addToHistory(entries, History.historyEntry(job, Date.now()), limit))
    }

    function remove(entry) {
        save(entries.filter(h => h !== entry))
    }

    function clear() {
        save([])
    }

    function prune() {
        const files = History.doneFiles(entries)
        if (files.length) pruneCall.run([helperPath, "prune"].concat(files))
    }

    onLimitChanged: if (loaded && entries.length > limit) save(entries.slice(0, limit))

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", dir])

    OutputProcess {
        id: pruneCall
        onOutput: text => {
            const missing = Helper.parseJson(text)
            if (Array.isArray(missing) && missing.length) store.save(History.withoutFiles(store.entries, missing))
        }
    }

    FileView {
        id: file
        path: store.dir + "/history.json"
        atomicWrites: true
        printErrors: false

        onLoaded: {
            store.entries = History.parseHistory(text(), Settings.LIMITS.historyLimit.max)
            store.loaded = true
        }

        onLoadFailed: store.loaded = true
    }
}
