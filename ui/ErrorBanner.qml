import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ErrorBanner — non-intrusive error notification at the top.
Rectangle {
    id: root

    property string message: ""

    implicitHeight: 44
    radius: theme.radius_md
    color: Qt.rgba(0.953, 0.545, 0.659, 0.18)
    border.width: 1
    border.color: theme.danger

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: theme.space_md
        anchors.rightMargin: theme.space_xs
        spacing: theme.space_sm

        Text {
            text: "⚠"
            color: theme.danger
            font.family: theme.font_family
            font.pixelSize: theme.subhead_size
            font.weight: theme.weight_bold
        }

        Text {
            text: message
            color: theme.danger
            font.family: theme.font_family
            font.pixelSize: theme.small_size
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Rectangle {
            width: 28; height: 28
            radius: theme.radius_md
            color: closeHover.containsMouse ? Qt.rgba(0.953, 0.545, 0.659, 0.3) : "transparent"

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: theme.danger
                font.family: theme.font_family
                font.pixelSize: theme.body_size
                font.weight: theme.weight_bold
            }
            MouseArea {
                id: closeHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.visible = false
            }
        }
    }
}
