import QtQuick 2.15
import QtQuick.Controls 2.15

// StyledButton — consistent button styling.
// Variants: "primary" (accent fill), "secondary" (muted fill),
//           "danger" (red fill), "ghost" (transparent, hover only)
Rectangle {
    id: root
    property string text: ""
    property string variant: "secondary"  // primary | secondary | danger | ghost
    property bool primary: variant === "primary"
    property bool danger:  variant === "danger"
    property bool ghost:   variant === "ghost"
    signal clicked()

    implicitWidth: Math.max(80, label.implicitWidth + 28)
    implicitHeight: theme.button_height
    radius: theme.radius_md
    opacity: enabled ? 1 : 0.45
    color: {
        if (ghost)   return hover.containsMouse ? theme.surface_elevated : "transparent"
        if (primary) return hover.containsMouse ? theme.accent_hover : theme.accent
        if (danger)  return hover.containsMouse ? theme.danger  : theme.surface_strong
        return hover.containsMouse ? theme.surface_elevated : theme.surface
    }
    border.width: ghost ? 1 : 0
    border.color: ghost ? theme.divider : "transparent"

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: theme.font_family
        font.pixelSize: theme.body_size
        font.weight: root.primary || root.danger ? theme.weight_bold : theme.weight_medium
        color: {
            if (root.ghost)   return hover.containsMouse ? theme.foreground : theme.foreground_muted
            if (root.primary) return theme.background
            if (root.danger)  return theme.foreground
            return theme.foreground
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.enabled) root.clicked()
    }
}
