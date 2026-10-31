/*
 * Xenoglyph Runes v2: small glowing Daedric runes haunt the active window.
 *
 * One transparent, click-through overlay follows the active window's frame.
 * Three kinds of motes share it:
 *   orbit   runes gliding slowly along rings at different distances
 *   rise    embers that lift off the edge, drift, and burn out, then respawn
 *   twinkle tiny sparks and ghost runes that flare in place and move on
 * Each comes in one of three looks (ember, ink, ghost) at 12-26 px. All
 * positions are pure functions of one 20 fps clock, so the overlay redraws
 * at most 20 times a second and only while visible. Hidden for maximised,
 * fullscreen and non-normal windows.
 */
import QtQuick
import QtQuick.Window
import org.kde.kwin

Item {
    id: root
    readonly property var target: Workspace.activeWindow
    readonly property int margin: 50            // overlay reaches this far outside the frame
    readonly property string letters: "ABCDEGHKLMNORSTVXYZ"
    readonly property bool wanted: {
        if (!target || !target.normalWindow || target.fullScreen || target.minimized) return false
        const g = target.frameGeometry, o = target.output ? target.output.geometry : null
        if (o && g.width >= o.width - 4 && g.height >= o.height - 64) return false   // maximised
        return g.width > 140 && g.height > 90
    }
    property real t: 0
    onWantedChanged: wanted ? overlay.show() : overlay.hide()
    Component.onCompleted: if (wanted) overlay.show()

    Timer {
        interval: 50; repeat: true; running: overlay.visible
        onTriggered: root.t += 0.05
    }

    // stable pseudo-random in [0,1)
    function hash(n) { const s = Math.sin(n * 12.9898 + 78.233) * 43758.5453; return s - Math.floor(s) }

    // motes: [kind, look]  kind 0 orbit, 1 rise, 2 twinkle; look 0 ember, 1 ink, 2 ghost, 3 spark
    readonly property var motes: [
        [0, 0], [0, 1], [0, 2], [0, 0], [0, 1], [0, 2], [0, 0],
        [1, 0], [1, 0], [1, 3], [1, 0], [1, 3], [1, 2],
        [2, 3], [2, 3], [2, 2], [2, 3], [2, 1], [2, 3]
    ]

    Window {
        id: overlay
        // KWin's frameGeometry is its own RectF type: read the fields, not the rect
        readonly property real gx: root.target ? root.target.frameGeometry.x : 0
        readonly property real gy: root.target ? root.target.frameGeometry.y : 0
        readonly property real gw: root.target ? root.target.frameGeometry.width : 0
        readonly property real gh: root.target ? root.target.frameGeometry.height : 0
        x: gx - root.margin
        y: gy - root.margin
        width: Math.max(1, gw + 2 * root.margin)
        height: Math.max(1, gh + 2 * root.margin)
        visible: false
        color: "transparent"
        flags: Qt.FramelessWindowHint | Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus
               | Qt.WindowStaysOnTopHint | Qt.BypassWindowManagerHint | Qt.Tool

        // perimeter walk on a ring `out` px outside the frame; returns point + outward normal
        function along(p, out) {
            const m = root.margin - out, w = width - 2 * m, h = height - 2 * m
            const L = 2 * (w + h)
            let d = ((p % 1) + 1) % 1 * L
            if (d < w) return [m + d, m, 0, -1]
            d -= w; if (d < h) return [m + w, m + d, 1, 0]
            d -= h; if (d < w) return [m + w - d, m + h, 0, 1]
            d -= w; return [m, m + h - d, -1, 0]
        }

        Repeater {
            model: root.motes.length
            delegate: Image {
                id: mote
                readonly property int kind: root.motes[index][0]
                readonly property int look: root.motes[index][1]
                readonly property real seed: root.hash(index + 1.7)
                // rise / twinkle motes live in cycles; each cycle re-seeds the spot
                readonly property real period: kind === 1 ? 5.5 + 4 * seed : 3.2 + 3 * seed
                readonly property real clock: root.t + seed * period
                readonly property int cycle: Math.floor(clock / period)
                readonly property real life: clock / period - cycle                    // 0..1
                readonly property real spot: root.hash(index * 31 + cycle * 7.13)
                readonly property real glyphPx: look === 3 ? 10 + 8 * seed
                                              : look === 2 ? 11 + 7 * seed
                                              : 12 + 14 * root.hash(index * 3.3)      // 12-26 px
                readonly property var p: kind === 0
                    ? overlay.along(index / 7 + seed * 0.3 + root.t * (0.003 + 0.004 * seed) * (index % 2 ? 1 : -1),
                                    8 + 22 * root.hash(index * 5.1))
                    : overlay.along(spot, kind === 1 ? 2 + 6 * seed : 6 + 24 * root.hash(cycle + index))
                // rise: lift outward along the edge normal and drift sideways
                readonly property real lift: kind === 1 ? life * (12 + 12 * seed) : 0
                readonly property real sway: Math.sin(root.t * (0.7 + seed) + index * 1.9)
                readonly property real fade: kind === 0
                    ? 0.35 + 0.65 * Math.pow(0.5 + 0.5 * Math.sin(root.t * (0.3 + 0.25 * seed) + index * 2.3), 2)
                    : kind === 1 ? Math.sin(Math.PI * life) * (1 - 0.4 * life)
                    : Math.pow(Math.sin(Math.PI * life), 3)

                source: look === 3 ? "runes/spark.png"
                      : "runes/" + ["ember_", "ink_", "ghost_"][look]
                        + root.letters.charAt(Math.floor(root.hash(index * 9 + (kind ? cycle : 0)) * root.letters.length)) + ".png"
                // sprites are 96 px with the glyph spanning ~40%
                width: glyphPx / 0.4; height: width
                sourceSize.width: 96; sourceSize.height: 96
                mipmap: true; smooth: true
                x: p[0] + p[2] * lift + (kind === 1 ? p[3] * sway * 6 : sway * 2) - width / 2
                y: p[1] + p[3] * lift + (kind === 1 ? p[2] * sway * 6 : Math.cos(root.t * (0.5 + seed) + index) * 2) - height / 2
                rotation: kind === 2 ? 0 : sway * (kind === 1 ? 14 : 7)
                scale: kind === 2 ? 0.6 + 0.4 * fade : 1
                opacity: fade * (look === 2 ? 0.75 : 1)
            }
        }
    }
}
