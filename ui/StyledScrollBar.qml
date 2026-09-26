import QtQuick 2.15
import QtQuick.Controls 2.15

// StyledScrollBar — overlay-style scroll bar that floats above content
// without resizing it. Auto-hides after a short idle window; expands subtly
// on hover so it remains grabbable without dominating the UI.
//
// Attach as `ScrollBar.vertical: StyledScrollBar { }` on a Flickable.
// The parent is expected to be the Flickable itself.
ScrollBar {
    id: control

    // Idle window before the bar fades out (ms). The bar also fades out
    // shortly after the Flickable stops moving.
    property int hideDelayMs: 700

    // Resting state: invisible. The thumb fades in only while interacting.
    opacity: 0
    implicitWidth: 8
    padding: 0

    Behavior on opacity       { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on implicitWidth { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    function showBar() {
        hideTimer.stop()
        opacity = 1
    }
    function hideBarSoon() {
        // Don't fight the user if they're actively hovering or dragging.
        if (control.hovered || control.pressed) return
        hideTimer.restart()
    }
    Timer {
        id: hideTimer
        interval: control.hideDelayMs
        repeat: false
        onTriggered: control.opacity = 0
    }

    // Hover expansion — slightly wider so it remains easy to grab.
    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: {
            if (hovered) {
                control.showBar()
                control.implicitWidth = 10
            } else {
                control.implicitWidth = 8
                control.hideBarSoon()
            }
        }
    }

    background: null

    contentItem: Rectangle {
        id: thumb
        implicitWidth: control.width
        implicitHeight: 28
        radius: width / 2
        color: control.pressed
                ? Qt.rgba(1, 1, 1, 0.42)
                : (control.hovered ? Qt.rgba(1, 1, 1, 0.36) : Qt.rgba(1, 1, 1, 0.28))
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // React to the surrounding Flickable's motion. The ScrollBar's parent
    // is the Flickable when attached via ScrollBar.vertical, but qmllint
    // sees it as a generic Item — silence the false positive.
    Connections {
        target: control.parent
        ignoreUnknownSignals: true
        // qmllint disable missing-property
        function onMovingChanged() {
            if (control.parent.moving) control.showBar()
            else control.hideBarSoon()
        }
        function onFlickingChanged() {
            if (control.parent.flicking) control.showBar()
            else control.hideBarSoon()
        }
        // qmllint enable missing-property
    }
}