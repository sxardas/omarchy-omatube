import QtQuick
import qs.Commons
import qs.Ui
import "../js/jobs.mjs" as Jobs

Item {
    id: hero

    required property var bar
    property string status: ""
    property bool showUpdate: false
    property bool updateAvailable: false
    property bool checking: false
    property string latest: ""

    signal updateClicked()

    implicitHeight: Math.max(logo.implicitHeight, labels.implicitHeight, updateButton.height)

    Text {
        id: logo
        textFormat: Text.PlainText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: Jobs.BAR_ICON
        color: hero.bar.foreground
        font.family: hero.bar.fontFamily
        font.pixelSize: Style.font.display
    }

    Column {
        id: labels
        anchors.left: logo.right
        anchors.leftMargin: Style.space(14)
        anchors.right: updateButton.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(2)

        Text {
            textFormat: Text.PlainText
            text: "OmaTube"
            color: hero.bar.foreground
            font.family: hero.bar.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
        }

        Text {
            textFormat: Text.PlainText
            text: hero.status.toUpperCase()
            color: Qt.darker(hero.bar.foreground, 1.4)
            font.family: hero.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.2
            elide: Text.ElideRight
            width: parent.width
        }
    }

    Button {
        id: updateButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: hero.showUpdate
        width: height
        iconText: hero.updateAvailable ? "󰅢" : "󰑓"
        iconSize: Style.font.title
        tooltipText: hero.updateAvailable
            ? "Install yt-dlp " + hero.latest + " (runs pacman -Syu in a terminal)"
            : hero.checking ? "Checking for yt-dlp updates" : "Check for yt-dlp updates"
        foreground: hero.bar.foreground
        fontFamily: hero.bar.fontFamily
        horizontalPadding: 0
        verticalPadding: Style.spacing.controlPaddingY + Style.space(4)
        bordered: true
        active: hero.updateAvailable
        onClicked: hero.updateClicked()
    }
}
