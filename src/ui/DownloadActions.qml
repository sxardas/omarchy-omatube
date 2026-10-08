import QtQuick
import qs.Commons
import qs.Ui

Row {
    id: actions

    required property var bar
    property real folderWidth: 0
    property bool canDownload: false
    property bool queueing: false
    property string folder: ""

    signal download()

    signal openFolder()

    spacing: Style.space(6)

    Button {
        width: actions.width - folderButton.width - actions.spacing
        iconText: "󰇚"
        iconSize: Style.font.title
        text: actions.queueing ? "Add to queue" : "Download"
        fontSize: Style.font.bodySmall
        foreground: actions.bar.foreground
        fontFamily: actions.bar.fontFamily
        verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
        bordered: true
        opacity: actions.canDownload ? 1 : 0.5
        onClicked: actions.download()
    }

    Button {
        id: folderButton
        width: actions.folderWidth
        iconText: "󰉋"
        iconSize: Style.font.title
        text: "Open"
        tooltipText: actions.folder
        fontSize: Style.font.bodySmall
        foreground: actions.bar.foreground
        fontFamily: actions.bar.fontFamily
        verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
        bordered: true
        onClicked: actions.openFolder()
    }
}
