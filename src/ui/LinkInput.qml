import QtQuick
import qs.Commons
import qs.Ui
import "../js/links.mjs" as Links

Column {
    id: input

    required property var bar
    property alias text: field.text
    readonly property alias field: field
    readonly property string problem: Links.linkProblem(field.text)

    function prefill(text) {
        const url = Links.youtubeUrl(text)
        if (!url || field.text !== "") return
        field.text = url
        field.selectAll()
    }

    spacing: Style.space(10)

    PanelSectionHeader {
        text: "LINK"
        foreground: input.bar.foreground
        fontFamily: input.bar.fontFamily
    }

    TextField {
        id: field
        width: parent.width
        placeholderText: "Paste a YouTube video or playlist link"
        foreground: input.bar.foreground
        font.family: input.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
        selectByMouse: true
    }

    Text {
        visible: input.problem !== ""
        textFormat: Text.PlainText
        text: input.problem
        color: input.bar.urgent
        font.family: input.bar.fontFamily
        font.pixelSize: Style.font.caption
        width: parent.width
        elide: Text.ElideRight
    }
}
