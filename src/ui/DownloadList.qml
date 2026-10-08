import QtQuick
import qs.Commons
import qs.Ui
import "../js/jobs.mjs" as Jobs
import "../js/rows.mjs" as Rows

Column {
    id: list

    required property var bar
    property var service: null
    property int maxRows: 10
    property int playlistRows: 5
    readonly property bool hasRows: rowModel.count > 0

    readonly property var jobs: service ? service.jobs : []
    readonly property var groups: service ? service.groups : ({})
    readonly property var pending: service ? service.pendingPlaylists : []
    readonly property var jobsById: Jobs.indexById(jobs)
    readonly property var summaries: Jobs.groupSummaries(jobs, groups)
    readonly property var pendingById: {
        const map = {}
        for (const p of pending) map[p.id] = p
        return map
    }
    property var collapsed: ({})
    property int hidden: 0

    function toggle(groupId) {
        const next = Object.assign({}, collapsed)
        if (next[groupId]) delete next[groupId]
        else next[groupId] = true
        collapsed = next
    }

    function refresh() {
        const rows = Rows.openRowKeys({
            pending: pending, jobs: jobs, collapsed: collapsed, playlistRows: playlistRows, maxRows: maxRows
        })
        hidden = rows.hidden
        Rows.syncModel(rowModel, rows.keys)
    }

    onJobsChanged: refresh()
    onPendingChanged: refresh()
    onCollapsedChanged: refresh()
    onMaxRowsChanged: refresh()
    onPlaylistRowsChanged: refresh()
    Component.onCompleted: refresh()

    visible: hasRows
    spacing: Style.space(6)

    ListModel {
        id: rowModel
    }

    PanelSectionHeader {
        text: "DOWNLOADS"
        foreground: list.bar.foreground
        fontFamily: list.bar.fontFamily
    }

    Repeater {
        model: rowModel

        DownloadRow {
            required property string key
            readonly property var ref: Rows.parseKey(key)

            width: list.width
            bar: list.bar
            kind: ref.kind
            job: ref.kind === "job" ? list.jobsById[ref.id] || null : null
            group: ref.kind === "group" ? list.groups[ref.id] || null : null
            summary: ref.kind === "group" ? list.summaries[ref.id] || null : null
            pendingUrl: ref.kind === "reading" && list.pendingById[ref.id] ? list.pendingById[ref.id].url : ""
            collapsed: !!list.collapsed[ref.id]
            onClicked: if (isGroup) list.toggle(ref.id)
            onCancel: {
                if (!list.service) return
                if (isGroup) list.service.cancelGroup(ref.id)
                else if (job) list.service.cancelJob(job.id)
            }
        }
    }

    Text {
        visible: list.hidden > 0
        textFormat: Text.PlainText
        text: "and " + list.hidden + " more in the queue"
        color: Qt.darker(list.bar.foreground, 1.5)
        font.family: list.bar.fontFamily
        font.pixelSize: Style.font.caption
        leftPadding: Style.space(36)
    }
}
