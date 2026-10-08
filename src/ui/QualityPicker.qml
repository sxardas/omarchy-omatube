import QtQuick
import qs.Commons
import qs.Ui
import "../js/quality.mjs" as Quality

Column {
    id: picker

    required property var bar
    property string current: "best"
    readonly property real cellWidth: (width - cells.spacing * (Quality.QUALITIES.length - 1)) / Quality.QUALITIES.length

    signal picked(string key)

    spacing: Style.space(10)

    PanelSectionHeader {
        text: "QUALITY"
        foreground: picker.bar.foreground
        fontFamily: picker.bar.fontFamily
    }

    Row {
        id: cells
        width: parent.width
        spacing: Style.space(6)

        Repeater {
            model: Quality.QUALITIES

            Button {
                required property var modelData
                width: picker.cellWidth
                text: modelData.label
                tooltipText: Quality.qualityTip(modelData)
                fontSize: Style.font.bodySmall
                foreground: picker.bar.foreground
                fontFamily: picker.bar.fontFamily
                horizontalPadding: Style.space(4)
                verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                bordered: true
                active: picker.current === modelData.key
                onClicked: picker.picked(modelData.key)
            }
        }
    }
}
