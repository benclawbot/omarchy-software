import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    color: theme.red
    opacity: 0.15
    radius: 6

    anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }

    height: implicitHeight + 16

    property string message: ""

    Row {
        anchors.fill: parent; anchors.margins: 10; spacing: 10

        Text {
            text: "⚠"
            color: theme.red; font.family: "monospace"; font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: message
            color: theme.red; font.family: "monospace"; font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.Wrap; flex: 1
        }

        Button {
            flat: true; anchors.verticalCenter: parent.verticalCenter
            onClicked: root.visible = false
            contentItem: Text {
                text: "✕"
                color: theme.red; font.family: "monospace"; font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
