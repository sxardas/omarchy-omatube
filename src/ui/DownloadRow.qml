import QtQuick
import qs.Commons
import "../js/jobs.mjs" as Jobs
import "../js/quality.mjs" as Quality

ListRow {
    id: row

    property string kind: ""
    property var job: null
    property var group: null
    property var summary: null
    property string pendingUrl: ""
    property bool collapsed: false

    readonly property bool isGroup: kind === "group"
    readonly property bool isReading: kind === "reading"
    readonly property bool running: Jobs.isActive(job)
    readonly property bool cancelling: !!job && !!job.cancelRequested

    signal cancel()

    indent: job && job.groupId ? Style.space(20) : 0
    icon: isReading ? "󰲸" : isGroup ? (collapsed ? "󰅂" : "󰅀") : job ? Jobs.statusIcon(job.status) : ""
    title: isReading ? "Reading playlist" : isGroup ? (group ? group.title : "Playlist") : Jobs.jobTitle(job)
    detail: isReading ? pendingUrl
        : isGroup ? (summary ? Jobs.groupDetail(summary) + " · " + Quality.qualityLabel(group ? group.quality : "") : "")
            : Jobs.jobDetail(job)
    bold: isGroup || (running && !cancelling)
    showProgress: isReading || (isGroup ? !!summary && summary.total > 0 : running)
    progress: isGroup ? (summary ? summary.percent / 100 : 0) : job && job.percent ? job.percent / 100 : 0
    indeterminate: isReading || (!!job && (job.status === Jobs.PROCESSING || job.percent === null || cancelling))
    actionIcon: isGroup || (Jobs.isOpen(job) && !cancelling) ? "󰅖" : ""
    actionTip: isGroup ? "Cancel the whole playlist" : "Cancel"
    clickable: isGroup
    onActionClicked: row.cancel()
}
