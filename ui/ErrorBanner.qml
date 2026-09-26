import QtQuick 2.15
import QtQuick.Controls 2.15
import "Theme.js" as T

// ErrorBanner — non-intrusive error notification at the top.
Rectangle {
    id: root

    property string message: ""

    implicitHeight: 44
    radius: T.radius_md
    color: Qt.rgba(0.953, 0.545, 0.659, 0.18)
    border.width: 1
    border.color: T.danger

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: T.space_md
        anchors.rightMargin: T.space_xs
        spacing: T.space_sm

        Text {
            text: "⚠"
            color: T.danger
            font.family: T.font_family
            font.pixelSize: T.subhead_size
            font.weight: T.weight_bold
        }

        Text {
            text: message
            color: T.danger
            font.family: T.font_family
            font.pixelSize: T.small_size
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Rectangle {
            width: 28; height: 28
            radius: T.radius_md
            color: closeHover.containsMouse ? Qt.rgba(0.953, 0.545, 0.659, 0.3) : "transparent"

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: T.danger
                font.family: T.font_family
                font.pixelSize: T.body_size
                font.weight: T.weight_bold
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
