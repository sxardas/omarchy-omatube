import QtQuick
import qs.Commons
import qs.Ui

Column {
    id: notice

    required property var bar
    property string text: ""

    signal setupClicked()

    visible: text !== ""
    spacing: Style.space(10)

    Text {
        textFormat: Text.PlainText
        text: notice.text
        color: Qt.darker(notice.bar.foreground, 1.5)
        font.family: notice.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
        width: parent.width
    }

    Button {
        iconText: "󰒓"
        text: "Finish setup"
        tooltipText: "Install yt-dlp, ffmpeg and deno (asks for your password)"
        foreground: notice.bar.foreground
        fontFamily: notice.bar.fontFamily
        fontSize: Style.font.bodySmall
        bordered: true
        onClicked: notice.setupClicked()
    }
}
