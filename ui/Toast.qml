import QtQuick 2.15
import QtQuick.Layouts 1.15

// Toast — transient notification that auto-dismisses after a short
// dwell. Used to confirm package actions (installed/updated/removed)
// without competing with the main content for layout space.
//
// Variants: "success" (green), "info" (blue), "warning" (amber),
// "danger" (red). Defaults to success.
Rectangle {
    id: root

    property string message: ""
    property string detail: ""
    property string variant: "success"
    property int durationMs: 4000

    signal dismissed()

    function show(text, variantArg, detailArg, durationArg) {
        message = text
        variant = variantArg || "success"
        detail = detailArg || ""
        durationMs = (durationArg !== undefined && durationArg > 0) ? durationArg : 4000
        hideTimer.interval = durationMs
        hideTimer.restart()
        opacity = 0
        slideIn.restart()
    }

    // Convenience: format and show an action-confirmation toast.
    // action: "install" | "update" | "remove"
    // packages: array of names
    // rawOutput: pacman output (shown as detail when present)
    function showAction(action, packages, rawOutput) {
        var formatted = formatActionMessageFn(action, packages, rawOutput)
        show(formatted.text, formatted.variant, formatted.detail || "")
    }

    // QML can't define a function on a Rectangle directly without binding
    // it to the parent scope; we expose a hook so Main.qml can supply the
    // formatter. Default is a no-op fallback.
    property var formatActionMessageFn: function(action, packages, rawOutput) {
        return { text: action || qsTr("Done"), detail: rawOutput || "" }
    }

    // Geometry: anchored to the top of the parent, centred horizontally.
    width: Math.min(contentLayout.implicitWidth + 2 * theme.space_lg, parent ? parent.width - 2 * theme.space_xl : 480)
    implicitHeight: 56
    radius: theme.radius_lg

    color: variant === "danger"
        ? Qt.rgba(0.953, 0.545, 0.659, 0.18)
        : variant === "warning"
            ? Qt.rgba(0.949, 0.886, 0.686, 0.18)
            : variant === "info"
                ? Qt.rgba(0.537, 0.706, 0.980, 0.18)
                : Qt.rgba(0.651, 0.890, 0.631, 0.18)
    border.width: 1
    border.color: variant === "danger" ? theme.danger
                : variant === "warning" ? theme.warning
                : variant === "info"    ? theme.accent
                : theme.success

    opacity: 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    transform: Translate {
        id: translate
        y: -8
    }

    ParallelAnimation {
        id: slideIn
        NumberAnimation {
            target: translate
            property: "y"
            to: 0
            duration: 220
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "opacity"
            to: 1
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: hideTimer
        interval: root.durationMs
        repeat: false
        onTriggered: {
            root.opacity = 0
            root.dismissed()
        }
    }

    RowLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.leftMargin: theme.space_lg
        anchors.rightMargin: theme.space_sm
        spacing: theme.space_md

        Rectangle {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: 14
            color: variant === "danger" ? theme.danger
                 : variant === "warning" ? theme.warning
                 : variant === "info"    ? theme.accent
                 : theme.success
            Text {
                anchors.centerIn: parent
                text: variant === "danger" ? "!"
                    : variant === "warning" ? "!"
                    : variant === "info"    ? "i"
                    : "✓"
                color: theme.background
                font.family: theme.font_family
                font.pixelSize: theme.body_size
                font.weight: theme.weight_bold
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: root.message
                color: theme.foreground
                font.family: theme.font_family
                font.pixelSize: theme.body_size
                font.weight: theme.weight_bold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                visible: root.detail.length > 0
                text: root.detail
                color: theme.foreground_muted
                font.family: theme.font_family
                font.pixelSize: theme.small_size
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Rectangle {
            id: closeButton
            width: 28; height: 28
            radius: theme.radius_md
            color: closeHover.containsMouse ? theme.surface_elevated : "transparent"
            Text {
                anchors.centerIn: parent
                text: "✕"
                color: theme.foreground_dim
                font.family: theme.font_family
                font.pixelSize: theme.small_size
            }
            MouseArea {
                id: closeHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.opacity = 0
                    root.dismissed()
                }
            }
        }
    }
}