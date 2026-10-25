import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Entry point. Everything configurable arrives through BGSEL_* environment
// variables set by the qs-bgselector launcher.
ShellRoot {
    id: shell
    settings.watchFiles: false

    function env(name, fallback) {
        const v = Quickshell.env(name)
        return (v !== undefined && v !== null && v !== "") ? v : fallback
    }

    readonly property string listPath: env("BGSEL_LIST", "")
    readonly property string applyScript: env("BGSEL_APPLY", "")
    readonly property string currentPath: env("BGSEL_CURRENT", "")
    readonly property string wallDir: env("BGSEL_DIR", "")
    readonly property bool showLoader: env("BGSEL_LOADER", "1") !== "0"

    FileView {
        id: listFile
        path: shell.listPath
        blockLoading: true
    }

    function parseList() {
        const out = []
        const lines = listFile.text().split("\n")
        for (let i = 0; i < lines.length; i++) {
            if (lines[i] === "") continue
            const p = lines[i].split("\t")
            if (p.length < 3) continue
            out.push({ name: p[0], thumb: p[1], path: p[2] })
        }
        return out
    }

    Process {
        id: applyProc
        onExited: (exitCode) => {
            picker.finishAndQuit()
        }
    }

    PanelWindow {
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.namespace: "bgselector"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Picker {
            id: picker
            anchors.fill: parent
            focus: true
            entries: shell.parseList()
            startPath: shell.currentPath

            accent: shell.env("BGSEL_ACCENT", "#84d6c3")
            tickColor: shell.env("BGSEL_TICK", "#00382f")
            textColor: shell.env("BGSEL_TEXT", "#dee4e1")
            textMuted: shell.env("BGSEL_TEXT_MUTED", "#bec9c5")
            fontFamily: shell.env("BGSEL_FONT", "JetBrains Mono")
            showLoader: shell.showLoader
            emptyText: shell.wallDir !== "" ? "No wallpapers found in " + shell.wallDir : "No wallpapers found"

            onPicked: (path) => {
                picker.busy = true
                if (shell.showLoader) {
                    applyProc.command = ["bash", shell.applyScript, path]
                    applyProc.running = true
                } else {
                    // no spinner: apply in the background and fade out right away
                    Quickshell.execDetached(["bash", shell.applyScript, path])
                    picker.finishAndQuit()
                }
            }
            onDismissed: Qt.quit()
        }
    }
}
