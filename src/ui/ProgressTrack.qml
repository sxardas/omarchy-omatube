import QtQuick
import qs.Commons

Item {
    id: meter

    required property color foreground
    property real progress: 0
    property bool indeterminate: false

    implicitHeight: Style.space(10)

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Style.space(28)
        anchors.rightMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        height: Math.max(4, Math.round(Style.spacing.controlHeight * 0.11))
        radius: height / 2
        color: Style.selectedFillFor(meter.foreground, Color.accent)
        clip: true

        Rectangle {
            visible: !meter.indeterminate
            height: parent.height
            radius: parent.radius
            color: meter.foreground
            width: parent.width * Math.max(0, Math.min(1, meter.progress))

            Behavior on width {
                NumberAnimation {
                    duration: 320
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            id: runner
            visible: meter.indeterminate
            height: parent.height
            radius: parent.radius
            width: parent.width * 0.25
            color: meter.foreground

            SequentialAnimation on x {
                running: meter.indeterminate && meter.visible
                loops: Animation.Infinite
                NumberAnimation {
                    from: 0
                    to: track.width - runner.width
                    duration: 900
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    from: track.width - runner.width
                    to: 0
                    duration: 900
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }
}
