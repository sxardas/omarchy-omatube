import QtQuick
import Quickshell.Io

Process {
    id: proc

    property int jobId: 0

    signal line(string text)

    signal problem(string text)

    signal done(int exitCode)

    stdout: SplitParser {
        onRead: data => proc.line(data)
    }

    stderr: SplitParser {
        onRead: data => {
            const text = String(data || "").trim()
            if (text) proc.problem(text)
        }
    }

    onExited: exitCode => Qt.callLater(() => proc.done(exitCode))
}
