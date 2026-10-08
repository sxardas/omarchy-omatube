import QtQuick
import Quickshell.Io

Process {
    id: proc

    signal output(string text)

    function run(argv) {
        if (running) return false
        if (argv) command = argv
        running = true
        return true
    }

    stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: proc.output(text)
    }
}
