import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    color: "transparent"

    Column {
        anchors.fill: parent
        leftPadding: 12; rightPadding: 12; spacing: 8

        // Filter bar
        Row {
            width: parent.width; spacing: 8

            // Filter chips
            Row {
                spacing: 6
                Repeater {
                    model: ["All", "Explicit", "Dependencies", "Orphans"]
                    delegate: Rectangle {
                        radius: 4; height: 24
                        color: installedFilter === modelData ? theme.accent : theme.muted
                        opacity: installedFilter === modelData ? 0.2 : 1.0
                        anchors.verticalCenter: parent.verticalCenter
                        leftPadding: 8; rightPadding: 8

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: installedFilter === modelData ? theme.accent : theme.dark_foreground
                            font.family: "monospace"; font.pixelSize: 11
                            font.weight: installedFilter === modelData ? Font.Bold : Font.Normal
                        }

                        MouseArea { anchors.fill: parent; onClicked: installedFilter = modelData }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Total size
            Text {
                text: installedCount + " installed · " + installedSize
                color: theme.dark_foreground; font.family: "monospace"; font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }

            // Sort
            Button {
                text: "▼ Size"
                flat: true; anchors.verticalCenter: parent.verticalCenter
                onClicked: sortMenu.open()
                contentItem: Text {
                    text: parent.text; color: theme.dark_foreground
                    font.family: "monospace"; font.pixelSize: 11
                }
                Menu {
                    id: sortMenu
                    MenuItem { text: "Sort by Name"; onClicked: bridge.sortInstalled("name") }
                    MenuItem { text: "Sort by Size"; onClicked: bridge.sortInstalled("size") }
                    MenuItem { text: "Sort by Date"; onClicked: bridge.sortInstalled("date") }
                }
            }

            // Remove selected button
            Button {
                text: "Remove selected"
                enabled: selectedCount > 0
                visible: selectionMode
                onClicked: bridge.queueRemove(selectedPackages)
                contentItem: Text {
                    text: parent.text; color: parent.enabled ? theme.red : theme.muted
                    font.family: "monospace"; font.pixelSize: 11
                }
            }

            // Toggle selection mode
            Button {
                text: selectionMode ? "Done" : "Select…"
                flat: true; anchors.verticalCenter: parent.verticalCenter
                onClicked: selectionMode = !selectionMode
                contentItem: Text {
                    text: parent.text; color: theme.accent
                    font.family: "monospace"; font.pixelSize: 11
                }
            }
        }

        // Package list (same component as Browse)
        PackageList {
            id: installedList
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.topMargin: 36
        }
    }

    property string installedFilter: "All"
    property int installedCount: 0
    property string installedSize: ""
    property int selectedCount: 0
    property var selectedPackages: []
    property bool selectionMode: false
}
