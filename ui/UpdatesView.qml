import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    color: "transparent"

    Column {
        anchors.fill: parent
        x: 12; width: parent.width - 24
        spacing: 12

        // Summary card
        Rectangle {
            width: parent.width; height: 64
            color: theme.lighter_background; radius: 8

            Row {
                anchors.fill: parent; anchors.margins: 14; spacing: 12

                Column {
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: updatesCount + " updates available"
                        color: theme.foreground; font.family: "monospace"
                        font.pixelSize: 16; font.weight: Font.Bold
                    }
                    Text {
                        text: lastChecked
                        color: theme.dark_foreground; font.family: "monospace"; font.pixelSize: 11
                    }
                }

                Item { Layout.fillWidth: true }

                Button {
                    id: refreshButton
                    text: "Refresh"
                    flat: true; anchors.verticalCenter: parent.verticalCenter
                    onClicked: bridge.refresh()
                    contentItem: Text {
                        text: refreshButton.text; color: theme.accent
                        font.family: "monospace"; font.pixelSize: 12
                    }
                }

                Button {
                    id: installAllButton
                    text: "Install all"
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: updatesCount > 0
                    onClicked: queueAllUpdates()
                    contentItem: Text {
                        text: installAllButton.text; color: theme.background
                        font.family: "monospace"; font.pixelSize: 12; font.weight: Font.Bold
                    }
                    background: Rectangle {
                        color: parent.enabled ? theme.green : theme.muted
                        radius: 4; anchors.fill: parent
                    }
                }
            }
        }

        // Updates list
        ListView {
            width: parent.width; height: parent.height - 76
            clip: true

            model: ListModel { id: updatesModel }

            delegate: Row {
                width: parent.width - 24
                height: 44; spacing: 8

                Rectangle {
                    width: 20; height: 20; radius: 4
                    color: theme.lighter_background
                    anchors.verticalCenter: parent.verticalCenter
                    CheckBox { anchors.centerIn: parent }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 180
                    spacing: 2

                    Text {
                        text: model.name
                        color: theme.foreground; font.family: "monospace"
                        font.pixelSize: 13; font.weight: Font.Medium
                    }
                    Row { spacing: 6
                        Text {
                            text: model.old_version + " → " + model.new_version
                            color: theme.dark_foreground; font.family: "monospace"; font.pixelSize: 11
                        }
                        SourceBadge { source: model.source; repo: model.repo }
                    }
                }

                Text {
                    text: model.size
                    color: theme.dark_foreground; font.family: "monospace"; font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            ScrollBar.vertical: ScrollBar { width: 6 }
        }
    }

    property int updatesCount: 0
    property string lastChecked: "Never checked"
}
