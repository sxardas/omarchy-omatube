import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
    id: row

    required property var bar
    property string icon: ""
    property bool urgent: false
    property string title: ""
    property string detail: ""
    property bool bold: false
    property bool showProgress: false
    property real progress: 0
    property bool indeterminate: false
    property string actionIcon: ""
    property string actionTip: ""
    property bool clickable: false
    property real indent: 0
    readonly property bool hot: rowHover.hovered

    signal clicked()

    signal actionClicked()

    implicitHeight: rowColumn.implicitHeight + Style.space(12)
    radius: Style.cornerRadius
    color: hot ? Style.hoverFillFor(bar.foreground, Color.accent) : "transparent"

    HoverHandler {
        id: rowHover
        cursorShape: row.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    MouseArea {
        anchors.fill: parent
        enabled: row.clickable
        onClicked: row.clicked()
    }

    Column {
        id: rowColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(8) + row.indent
        anchors.rightMargin: Style.space(4)
        spacing: Style.space(4)

        Item {
            width: parent.width
            implicitHeight: Math.max(glyph.implicitHeight, labels.implicitHeight, actionButton.implicitHeight)

            Text {
                id: glyph
                textFormat: Text.PlainText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(20)
                text: row.icon
                color: row.urgent ? row.bar.urgent : row.bar.foreground
                font.family: row.bar.fontFamily
                font.pixelSize: Style.font.title
            }

            Column {
                id: labels
                anchors.left: glyph.right
                anchors.leftMargin: Style.space(8)
                anchors.right: actionButton.visible ? actionButton.left : parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(1)

                Text {
                    textFormat: Text.PlainText
                    text: row.title
                    color: row.bar.foreground
                    font.family: row.bar.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: row.bold
                    elide: Text.ElideRight
                    width: parent.width
                }

                Text {
                    textFormat: Text.PlainText
                    text: row.detail
                    color: row.urgent ? row.bar.urgent : Qt.darker(row.bar.foreground, 1.4)
                    font.family: row.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            Button {
                id: actionButton
                visible: row.actionIcon !== ""
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconText: row.actionIcon
                tooltipText: row.actionTip
                iconSize: Style.font.bodySmall
                foreground: row.bar.foreground
                fontFamily: row.bar.fontFamily
                horizontalPadding: Style.space(6)
                verticalPadding: Style.space(3)
                opacity: row.hot ? 1 : 0.55
                onClicked: row.actionClicked()
            }
        }

        ProgressTrack {
            visible: row.showProgress
            width: parent.width
            foreground: row.bar.foreground
            progress: row.progress
            indeterminate: row.indeterminate
        }
    }
}
