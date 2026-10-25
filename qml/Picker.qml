import QtQuick
import Quickshell.Widgets

FocusScope {
    id: root
    focus: true

    // ---- inputs ----------------------------------------------------------
    property var entries: []
    property string startPath: ""
    property string backdropPath: ""
    property color accent: "#84d6c3"
    property color tickColor: "#00382f"
    property color textColor: "#dee4e1"
    property color textMuted: "#bec9c5"
    property string fontFamily: "JetBrains Mono"
    property bool busy: false
    // false: no spinner, the picker fades out and the wallpaper is applied in the background
    property bool showLoader: true
    // Shown instead of "No matches" when the wallpaper directory is empty
    property string emptyText: ""

    signal picked(string path)
    signal dismissed()

    function finishAndQuit() {
        exitAnim.start()
    }

    NumberAnimation {
        id: exitAnim
        target: root
        property: "opacity"
        to: 0
        duration: 300
        easing.type: Easing.OutCubic
        onFinished: Qt.quit()
    }

    // ---- tuning ----------------------------------------------------------
    readonly property real u: Math.max(0.5, height / 1080)
    readonly property real cardH: 440 * u
    readonly property real gap: 10 * u
    readonly property real radius: 26 * u
    readonly property real wSelected: 620 * u
    readonly property real wNear: 300 * u
    readonly property real wMid: 190 * u
    readonly property real wSlim: 64 * u
    readonly property real stripY: height * 0.46

    // How many cards away from the centre can still be on screen. Cards past
    // this are not drawn.
    readonly property real reach: Math.max(5,
        4 + Math.ceil((width / 2 + wSlim / 2 - centerAt(3)) / (wSlim + gap)))

    // Entrance animation (0 -> 1 once, when the picker opens)
    property real intro: 0
    NumberAnimation on intro {
        from: 0; to: 1
        duration: 420
        easing.type: Easing.OutCubic
    }

    function tierW(n) {
        return n <= 0 ? wSelected : n === 1 ? wNear : n === 2 ? wMid : wSlim
    }

    function widthAt(ad) {
        const j = Math.floor(ad)
        const f = ad - j
        return tierW(j) + (tierW(j + 1) - tierW(j)) * f
    }

    function centerAt(ad) {
        let c = 0
        const full = Math.min(Math.floor(ad), 3)
        for (let m = 0; m < full; m++)
            c += (tierW(m) + tierW(m + 1)) / 2 + gap
        return c + (ad - full) * ((tierW(full) + tierW(full + 1)) / 2 + gap)
    }

    // ---- state -----------------------------------------------------------
    property string query: ""
    property var shown: []
    property int current: 0
    property real pos: 0
    property bool animate: false
    property real wheelAcc: 0

    Behavior on pos {
        enabled: root.animate
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    function refilter(keepPath) {
        if (root.busy) return
        const tokens = query.toLowerCase().split(" ").filter(t => t !== "")
        const out = []
        for (let i = 0; i < entries.length; i++) {
            const n = entries[i].name.toLowerCase()
            let ok = true
            for (let j = 0; j < tokens.length; j++) {
                if (n.indexOf(tokens[j]) === -1) { ok = false; break }
            }
            if (ok) out.push(entries[i])
        }
        let idx = 0
        if (keepPath !== "") {
            for (let k = 0; k < out.length; k++) {
                if (out[k].path === keepPath) { idx = k; break }
            }
        }
        animate = false
        shown = out
        current = idx
        pos = idx
        animate = true
    }

    function setQuery(q) {
        if (root.busy) return
        const keep = (shown.length > 0 && current < shown.length) ? shown[current].path : ""
        query = q
        refilter(keep)
    }

    function go(i) {
        if (root.busy || shown.length === 0) return
        current = Math.max(0, Math.min(shown.length - 1, i))
        pos = current
    }

    function activate() {
        if (root.busy || shown.length === 0) return
        picked(shown[current].path)
    }

    Component.onCompleted: {
        forceActiveFocus()
        refilter(startPath)
    }

    Keys.onPressed: (e) => {
        if (root.busy) { e.accepted = true; return }

        switch (e.key) {
        case Qt.Key_Left:      go(current - 1); break
        case Qt.Key_Right:     go(current + 1); break
        case Qt.Key_Home:      go(0); break
        case Qt.Key_End:       go(shown.length - 1); break
        case Qt.Key_Return:
        case Qt.Key_Enter:     activate(); break
        case Qt.Key_Escape:
            if (query !== "") setQuery(""); else dismissed()
            break
        case Qt.Key_Backspace: setQuery(query.slice(0, -1)); break
        default:
            const typed = e.text.length === 1 && e.text >= " "
                && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            if (!typed) return
            setQuery(query + e.text)
        }
        e.accepted = true
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (ev) => {
            if (root.busy) return
            const d = Math.abs(ev.angleDelta.x) > Math.abs(ev.angleDelta.y)
                ? ev.angleDelta.x : ev.angleDelta.y
            root.wheelAcc += d
            while (root.wheelAcc >= 120)  { root.go(root.current - 1); root.wheelAcc -= 120 }
            while (root.wheelAcc <= -120) { root.go(root.current + 1); root.wheelAcc += 120 }
        }
    }

    // ---- visuals ---------------------------------------------------------
    Image {
        id: backdropImg
        anchors.fill: parent
        source: root.backdropPath !== "" ? "file://" + root.backdropPath : ""
        fillMode: Image.PreserveAspectCrop
        visible: status === Image.Ready
        asynchronous: true
        cache: true

        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.backdropPath !== ""
            ? (root.busy && root.showLoader ? "#60000000" : "#99000000")
            : (root.busy && root.showLoader ? "#40000000" : "#80000000")
        Behavior on color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }

        NumberAnimation on opacity { from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
        MouseArea {
            anchors.fill: parent
            onClicked: { if (!root.busy) root.dismissed() }
        }
    }

    Item {
        id: stage
        anchors.fill: parent
        opacity: root.busy && root.showLoader ? 0.0 : 1.0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        Repeater {
            model: root.shown.length

            delegate: Item {
                id: card
                required property int index

                readonly property var entry: root.shown[index]
                readonly property real d: index - root.pos
                readonly property real ad: Math.abs(d)

                // Fade out toward the screen edge, and fade in on open.
                opacity: Math.min(1, Math.max(0, root.reach - ad)) * root.intro
                visible: opacity > 0.01

                // Only decode thumbnails for cards that are (nearly) on screen.
                readonly property bool load: ad < root.reach + 1

                width: root.widthAt(ad)
                height: root.cardH
                x: root.width / 2 + (d < 0 ? -1 : 1) * root.centerAt(ad) - width / 2
                y: root.stripY - height / 2
                z: -ad

                ClippingRectangle {
                    anchors.fill: parent
                    radius: root.radius
                    color: "#303634"

                    Image {
                        anchors.centerIn: parent
                        width: root.wSelected
                        height: root.cardH
                        source: card.load && card.entry ? "file://" + card.entry.thumb : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        // Decode at roughly on-screen size
                        sourceSize.height: Math.ceil(root.cardH * 1.15)

                        // Fade in once loaded
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                        }
                    }
                }

                // "this is the wallpaper you have now" badge. Only shown on the
                // selected card and the two beside it.
                Loader {
                    active: card.entry !== undefined && card.entry.path === root.startPath
                    anchors.centerIn: parent
                    width: 64 * root.u
                    height: width
                    opacity: Math.max(0, Math.min(1, 2 - card.ad))
                    visible: opacity > 0.01

                    sourceComponent: Canvas {
                        property color fill: root.accent
                        property color mark: root.tickColor
                        onFillChanged: requestPaint()
                        onMarkChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const w = width
                            ctx.fillStyle = fill
                            ctx.beginPath()
                            ctx.arc(w / 2, w / 2, w / 2, 0, 2 * Math.PI)
                            ctx.fill()

                            ctx.strokeStyle = mark
                            ctx.lineWidth = w * 0.095
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            ctx.beginPath()
                            ctx.moveTo(w * 0.29, w * 0.52)
                            ctx.lineTo(w * 0.44, w * 0.66)
                            ctx.lineTo(w * 0.72, w * 0.36)
                            ctx.stroke()
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: { root.go(card.index); root.activate() }
                }
            }
        }

        Text {
            id: title
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.stripY + root.cardH / 2 + 28 * root.u
            width: parent.width * 0.8
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            color: root.accent
            opacity: root.intro
            font.family: root.fontFamily
            font.pixelSize: Math.round(26 * root.u)
            text: root.shown.length > 0 && root.current < root.shown.length
                ? root.shown[root.current].name
                : (root.entries.length === 0 && root.emptyText !== "" ? root.emptyText : "No matches")
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: title.y + title.height + 8 * root.u
            color: root.textMuted
            opacity: root.intro
            font.family: root.fontFamily
            font.pixelSize: Math.round(13 * root.u)
            text: (root.query !== "" ? "filter: " + root.query + "   ·   " : "")
                + (root.shown.length > 0 ? (root.current + 1) + " / " + root.shown.length + "   ·   " : "")
                + "← → navigate   Enter apply   Esc " + (root.query !== "" ? "clear" : "cancel")
                + "   type to filter"
        }
    }

    // ---- circular wipe loader --------------------------------------------
    Item {
        id: loaderItem
        anchors.centerIn: parent
        width: 72 * root.u
        height: 72 * root.u
        visible: root.busy && root.showLoader
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }

        property real arcStart: 0
        property real arcEnd: 0

        SequentialAnimation {
            id: ringAnim
            running: root.busy && root.showLoader
            loops: Animation.Infinite

            NumberAnimation {
                target: loaderItem
                property: "arcEnd"
                from: 0
                to: 1
                duration: 900
                easing.type: Easing.InOutCubic
            }

            NumberAnimation {
                target: loaderItem
                property: "arcStart"
                from: 0
                to: 1
                duration: 900
                easing.type: Easing.InOutCubic
            }

            ScriptAction {
                script: {
                    loaderItem.arcStart = 0
                    loaderItem.arcEnd = 0
                    ringCanvas.requestPaint()
                }
            }

            PauseAnimation { duration: 550 }
        }

        Canvas {
            id: ringCanvas
            anchors.fill: parent

            Connections {
                target: loaderItem
                function onArcStartChanged() { ringCanvas.requestPaint() }
                function onArcEndChanged() { ringCanvas.requestPaint() }
            }

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                const strokeW = 4 * root.u
                const cx = width / 2
                const cy = height / 2
                const r = (width - strokeW) / 2

                if ((loaderItem.arcEnd - loaderItem.arcStart) > 0.005) {
                    const startAngle = -Math.PI / 2 + loaderItem.arcStart * 2 * Math.PI
                    const endAngle = -Math.PI / 2 + loaderItem.arcEnd * 2 * Math.PI

                    ctx.beginPath()
                    ctx.arc(cx, cy, r, startAngle, endAngle, false)
                    ctx.lineWidth = strokeW
                    ctx.strokeStyle = root.accent
                    ctx.lineCap = "round"
                    ctx.stroke()
                }
            }
        }
    }
}
