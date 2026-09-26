import QtQuick 2.15

// StyledChip — small pill / filter chip.
//   selected = true → highlighted
Rectangle {
    id: root
    property string text: ""
    property bool selected: false
    property color accent: theme.accent

    signal clicked()

    implicitWidth: label.implicitWidth + 16
    implicitHeight: theme.chip_height
    radius: theme.chip_height / 2

    color: {
        if (selected) return Qt.rgba(accent.r, accent.g, accent.b, 0.18)
        return hover.containsMouse ? theme.surface_elevated : "transparent"
    }
    border.width: 1
    border.color: selected ? accent : theme.divider

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: selected ? root.accent : theme.foreground_muted
        font.family: theme.font_family
        font.pixelSize: theme.small_size
        font.weight: selected ? theme.weight_bold : theme.weight_medium
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
