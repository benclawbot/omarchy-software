import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: theme.glass
    radius: 12
    anchors.fill: parent
    z: 10
    visible: false

    // Frosted overlay
    Rectangle {
        anchors.fill: parent
        color: theme.background
        opacity: 0.7
        radius: parent.radius
    }

    Column {
        anchors.centerIn: parent
        spacing: 16

        Text {
            text: "Working…"
            color: theme.foreground; font.family: "monospace"
            font.pixelSize: 15; font.weight: Font.Medium
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Per-package progress dots
        Row {
            spacing: 6; layoutDirection: Qt.LeftToRight
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                id: dotRepeater
                model: ListModel { id: progressDots }

                Rectangle {
                    width: 10; height: 10; radius: 5
                    color: {
                        if (model.state === "done")    return theme.green
                        if (model.state === "error")   return theme.red
                        if (model.state === "running")  return theme.accent
                        return theme.muted
                    }

                    NumberAnimation on opacity {
                        running: model.state === "running"
                        loops: Animation.Infinite
                        from: 1.0; to: 0.3; duration: 600
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }

        // Current operation label
        Text {
            text: progressLabel
            color: theme.dark_foreground; font.family: "monospace"; font.pixelSize: 12
            anchors.horizontalCenter: parent.horizontalCenter
            visible: progressLabel.length > 0
        }

        // Terminal-style log output (collapsible)
        Rectangle {
            width: 480; height: Math.min(120, logArea.contentHeight + 16)
            color: theme.darker_background; radius: 6
            clip: true

            Flickable {
                id: logArea
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: width
                contentHeight: logText.height
                Text {
                    id: logText
                    text: logOutput
                    color: theme.foreground; font.family: "monospace"
                    font.pixelSize: 11; wrapMode: Text.Wrap
                    width: parent.width
                }
                ScrollBar.vertical: ScrollBar { width: 4 }
            }
        }

        // Cancel button
        Button {
            text: "Cancel operation"
            anchors.horizontalCenter: parent.horizontalCenter
            flat: true
            onClicked: bridge.cancel()
            contentItem: Text {
                text: parent.text; color: theme.red
                font.family: "monospace"; font.pixelSize: 12
            }
        }
    }

    property string progressLabel: ""
    property string logOutput: ""
    property bool visible: false
}
