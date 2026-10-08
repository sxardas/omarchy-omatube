import QtQuick
import qs.Commons
import qs.Ui
import "core"
import "ui"
import "js/jobs.mjs" as Jobs
import "js/links.mjs" as Links
import "js/quality.mjs" as Quality
import "js/settings.mjs" as Settings

Panel {
    id: root
    moduleName: "io.github.sxardas.omatube"

    property var service: null

    function findService() {
        if (!service && bar && bar.shell && bar.shell.serviceFor) service = bar.shell.serviceFor(moduleName)
    }

    Timer {
        interval: 300
        repeat: true
        triggeredOnStart: true
        running: !root.service
        onTriggered: root.findService()
    }

    readonly property string quality: Quality.normalizeQuality(setting("quality", "Best")) || "best"
    readonly property int historyRows: Settings.limit("historyRows", setting("historyRows"))
    readonly property int downloadRows: Settings.limit("downloadRows", setting("downloadRows"))
    readonly property int playlistRows: Settings.limit("playlistRows", setting("playlistRows"))

    function pushConfig() {
        if (!service) return
        service.configure({
            downloadDir: String(setting("downloadDir", Settings.DEFAULT_DIR)),
            quality: setting("quality", "Best"),
            maxParallel: setting("maxParallel"),
            historyLimit: setting("historyLimit"),
            playlistLimit: setting("playlistLimit"),
            cookiesBrowser: String(setting("cookiesBrowser", "None"))
        })
    }

    onServiceChanged: pushConfig()
    onSettingsChanged: pushConfig()

    function setQuality(key) {
        if (key === quality) return
        root.settings = Object.assign({}, root.settings, {quality: Quality.qualityLabel(key)})
        if (root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName, root.settings)
    }

    readonly property var jobs: service ? service.jobs : []
    readonly property int openCount: service ? service.openCount : 0
    readonly property bool canDownload: !!service && service.hasYtdlp && Links.isDownloadable(linkInput.text)

    readonly property string statusText: {
        const s = service
        if (!s) return "Starting"
        if (!s.depsLoaded) return "Checking yt-dlp"
        if (s.needsSetup) return "Setup needed"
        if (s.openCount > 0) return s.activeCount + " downloading" + (s.queuedCount > 0 ? " · " + s.queuedCount + " queued" : "")
        if (s.pendingPlaylists.length > 0) return "Reading playlist"
        if (s.checkingUpdate) return "Checking for updates"
        if (s.updateAvailable) return "yt-dlp " + s.updateInfo.latest + " available"
        if (s.updateError) return s.updateError
        if (s.updateChecked) return "yt-dlp " + s.deps.ytdlp + " · up to date"
        return "Ready · yt-dlp " + s.deps.ytdlp
    }

    function startDownload() {
        if (canDownload && service.add(linkInput.text, "panel", quality)) linkInput.text = ""
    }

    function openHistory(entry) {
        if (entry.status === Jobs.DONE) {
            service.openFile(entry.file)
            close()
        } else {
            service.retry(entry)
        }
    }

    function runInTerminal(path, arg) {
        if (root.bar) root.bar.run("omarchy-launch-floating-terminal-with-presentation " + Util.shellQuote(path) + " " + arg)
        close()
    }

    function updateClicked() {
        if (service.updateAvailable) runInTerminal(service.helperPath, "update")
        else service.checkUpdate()
    }

    onOpenedChanged: {
        if (!opened) return
        findService()
        if (service) {
            service.checkDeps()
            service.pruneHistory()
        }
        if (linkInput.text === "") clipboard.run()
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    OutputProcess {
        id: clipboard
        command: ["wl-paste", "--no-newline", "--type", "text"]
        onOutput: text => linkInput.prefill(text)
    }

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        readonly property bool showCount: root.openCount > 0 && !vertical
        text: showCount ? Jobs.BAR_ICON + " " + root.openCount : Jobs.BAR_ICON
        slotSize: Style.bar.iconSlot * (showCount ? 1.4 + 0.4 * String(root.openCount).length : 1)
        active: root.openCount > 0
        activeColor: Color.accent
        tooltipText: root.opened ? "" : Jobs.barTooltip(root.jobs)
        onPressed: function (b) {
            if (b === Qt.RightButton) {
                if (root.service) root.service.downloadClipboard()
            } else if (b === Qt.MiddleButton) {
                if (root.service) root.service.openFolder()
            } else {
                root.toggle()
            }
        }
    }

    KeyboardPanel {
        id: panel
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: linkInput.field
        contentWidth: panel.fittedContentWidth(Style.space(440))
        contentHeight: panel.fittedContentHeight(column.implicitHeight)

        Column {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Style.space(14)

            HeroHeader {
                width: parent.width
                bar: root.bar
                status: root.statusText
                showUpdate: !!root.service && root.service.hasYtdlp
                updateAvailable: !!root.service && root.service.updateAvailable
                checking: !!root.service && root.service.checkingUpdate
                latest: root.service && root.service.updateInfo ? String(root.service.updateInfo.latest || "") : ""
                onUpdateClicked: root.updateClicked()
            }

            PanelSeparator {
                foreground: root.bar.foreground
            }

            LinkInput {
                id: linkInput
                width: parent.width
                bar: root.bar
            }

            QualityPicker {
                id: qualityPicker
                width: parent.width
                bar: root.bar
                current: root.quality
                onPicked: key => root.setQuality(key)
            }

            DownloadActions {
                width: parent.width
                bar: root.bar
                folderWidth: qualityPicker.cellWidth
                canDownload: root.canDownload
                queueing: root.openCount > 0
                folder: root.service ? root.service.downloadDir : ""
                onDownload: root.startDownload()
                onOpenFolder: {
                    if (root.service) root.service.openFolder()
                    root.close()
                }
            }

            SetupNotice {
                width: parent.width
                bar: root.bar
                text: root.service ? root.service.setupText : ""
                onSetupClicked: root.runInTerminal(root.service.installPath, "--setup")
            }

            PanelSeparator {
                visible: listFlick.visible
                foreground: root.bar.foreground
            }

            Flickable {
                id: listFlick
                visible: downloadList.hasRows || historyList.hasRows
                width: parent.width
                height: Math.min(listColumn.implicitHeight, Style.space(420))
                contentHeight: listColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Column {
                    id: listColumn
                    width: listFlick.width
                    spacing: Style.space(14)

                    DownloadList {
                        id: downloadList
                        width: parent.width
                        bar: root.bar
                        service: root.service
                        maxRows: root.downloadRows
                        playlistRows: root.playlistRows
                    }

                    HistoryList {
                        id: historyList
                        width: parent.width
                        bar: root.bar
                        entries: root.service ? root.service.history : []
                        maxRows: root.historyRows
                        onOpen: entry => root.openHistory(entry)
                        onRemove: entry => root.service.removeHistory(entry)
                        onClear: root.service.clearHistory()
                    }
                }
            }
        }
    }
}
