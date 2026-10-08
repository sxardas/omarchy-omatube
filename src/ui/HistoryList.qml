import QtQuick
import qs.Commons
import qs.Ui
import "../js/history.mjs" as History
import "../js/jobs.mjs" as Jobs
import "../js/rows.mjs" as Rows

Column {
    id: list

    required property var bar
    property var entries: []
    property int maxRows: 10
    readonly property bool hasRows: rowModel.count > 0

    readonly property var shown: entries.slice(0, maxRows)
    readonly property var byKey: {
        const map = {}
        for (const h of shown) map[History.historyKey(h)] = h
        return map
    }

    signal open(var entry)

    signal remove(var entry)

    signal clear()

    function refresh() {
        Rows.syncModel(rowModel, shown.map(History.historyKey))
    }

    onShownChanged: refresh()
    Component.onCompleted: refresh()

    visible: hasRows
    spacing: Style.space(6)

    ListModel {
        id: rowModel
    }

    Item {
        width: parent.width
        implicitHeight: Math.max(header.implicitHeight, clearButton.implicitHeight)

        PanelSectionHeader {
            id: header
            text: "HISTORY"
            foreground: list.bar.foreground
            fontFamily: list.bar.fontFamily
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        Button {
            id: clearButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Clear history"
            tooltipText: "Empties the list; the videos stay in the folder"
            fontSize: Style.font.caption
            foreground: list.bar.foreground
            fontFamily: list.bar.fontFamily
            horizontalPadding: Style.space(8)
            verticalPadding: Style.space(2)
            onClicked: list.clear()
        }
    }

    Repeater {
        model: rowModel

        ListRow {
            required property string key
            readonly property var entry: list.byKey[key] || null

            width: list.width
            bar: list.bar
            icon: entry ? Jobs.statusIcon(entry.status) : ""
            urgent: !!entry && entry.status === Jobs.FAILED
            title: entry ? entry.title || entry.url : ""
            detail: History.historyDetail(entry)
            actionIcon: "󰆴"
            actionTip: "Remove from history"
            clickable: true
            onClicked: if (entry) list.open(entry)
            onActionClicked: if (entry) list.remove(entry)
        }
    }
}
