import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    color: "transparent"

    Column {
        anchors.centerIn: parent
        spacing: 20

        // Cache stats card
        Rectangle {
            width: 360; height: 100
            color: theme.lighter_background; radius: 8

            Column {
                anchors.fill: parent; anchors.margins: 16
                spacing: 8

                Text {
                    text: "Package cache"
                    color: theme.foreground; font.family: "monospace"
                    font.pixelSize: 14; font.weight: Font.Bold
                }

                Text {
                    text: cacheSize + " · " + cacheCount + " files"
                    color: theme.dark_foreground; font.family: "monospace"; font.pixelSize: 12
                }

                Text {
                    text: "Cached packages can be reinstalled without re-downloading"
                    color: theme.muted; font.family: "monospace"; font.pixelSize: 11
                    wrapMode: Text.Wrap
                }
            }
        }

        // Clean options
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Button {
                text: "Keep last install"
                onClicked: bridge.cleanCache("keep_last")
                contentItem: Text {
                    text: parent.text; color: theme.foreground
                    font.family: "monospace"; font.pixelSize: 12
                }
                background: Rectangle {
                    color: theme.muted; radius: 4; anchors.fill: parent
                    opacity: 0.3
                }
            }

            Button {
                text: "Clean all cache"
                onClicked: confirmCleanAll.open()
                contentItem: Text {
                    text: parent.text; color: theme.red
                    font.family: "monospace"; font.pixelSize: 12
                }
                background: Rectangle {
                    color: theme.red; radius: 4; anchors.fill: parent
                    opacity: 0.15
                }
            }
        }

        MessageDialog {
            id: confirmCleanAll
            title: "Clean all cache?"
            text: "This will delete all cached packages. They will need to be re-downloaded on reinstall."
            standardButtons: Dialog.Ok | Dialog.Cancel
            onAccepted: bridge.cleanCache("all")
        }
    }

    property string cacheSize: "—"
    property string cacheCount: "—"
}
