import QtQuick 2.15
import QtQuick.Controls 2.15
import "Theme.js" as T

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
    implicitHeight: T.button_height
    radius: T.radius_md
    color: {
        if (ghost)   return hover.containsMouse ? T.surface_elevated : "transparent"
        if (primary) return hover.containsMouse ? T.accent_hover : T.accent
        if (danger)  return hover.containsMouse ? T.danger  : T.surface_strong
        return hover.containsMouse ? T.surface_elevated : T.surface
    }
    border.width: ghost ? 1 : 0
    border.color: ghost ? T.divider : "transparent"

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.family: T.font_family
        font.pixelSize: T.body_size
        font.weight: root.primary || root.danger ? T.weight_bold : T.weight_medium
        color: {
            if (root.ghost)   return hover.containsMouse ? T.foreground : T.foreground_muted
            if (root.primary) return T.background
            if (root.danger)  return T.foreground
            return T.foreground
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
