import QtQuick 2.15
import "Theme.js" as T

// StyledChip — small pill / filter chip.
//   selected = true → highlighted
Rectangle {
    id: root
    property string text: ""
    property bool selected: false
    property color accent: T.accent

    signal clicked()

    implicitWidth: label.implicitWidth + 16
    implicitHeight: T.chip_height
    radius: T.chip_height / 2

    color: {
        if (selected) return Qt.rgba(accent.r, accent.g, accent.b, 0.18)
        return hover.containsMouse ? T.surface_elevated : "transparent"
    }
    border.width: 1
    border.color: selected ? accent : T.divider

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: selected ? root.accent : T.foreground_muted
        font.family: T.font_family
        font.pixelSize: T.small_size
        font.weight: selected ? T.weight_bold : T.weight_medium
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
