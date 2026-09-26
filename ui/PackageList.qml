import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "Theme.js" as T

Item {
    id: root

    property var model: []
    property bool loading: false

    signal packageClicked(string name)
    signal packageToggled(string name)

    // Column header
    Rectangle {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 32
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: T.space_md
            anchors.rightMargin: T.space_md
            spacing: T.space_md

            // Checkbox column (matches card checkbox width)
            Item { width: 18; Layout.preferredWidth: 18 }

            // Source column
            Text {
                text: "Source"
                color: T.foreground_subtle
                font.family: T.font_family
                font.pixelSize: T.caption_size
                font.weight: T.weight_bold
                Layout.preferredWidth: 60
            }

            // Name column
            Text {
                text: "Package"
                color: T.foreground_subtle
                font.family: T.font_family
                font.pixelSize: T.caption_size
                font.weight: T.weight_bold
                Layout.fillWidth: true
            }

            // Version column
            Text {
                text: "Version"
                color: T.foreground_subtle
                font.family: T.font_family
                font.pixelSize: T.caption_size
                font.weight: T.weight_bold
                Layout.preferredWidth: 110
                horizontalAlignment: Text.AlignRight
            }

            // Status column
            Text {
                text: "Status"
                color: T.foreground_subtle
                font.family: T.font_family
                font.pixelSize: T.caption_size
                font.weight: T.weight_bold
                Layout.preferredWidth: 120
                horizontalAlignment: Text.AlignRight
            }
        }

        // Bottom border
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: T.divider
        }
    }

    // ListView of packages
    ListView {
        id: listView
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        anchors.topMargin: T.space_xs
        clip: true
        spacing: T.space_xs
        model: root.model

        delegate: PackageCard {
            width: listView.width - 2 * T.space_md
            x: T.space_md
            name: modelData.name || ""
            description: modelData.description || ""
            version: modelData.version || ""
            source: modelData.source || "repo"
            repo: modelData.repo || ""
            installed: modelData.installed || false
            updateAvailable: modelData.update_available || modelData.updateAvailable || false
            onClicked: root.packageClicked(modelData.name)
            onToggleSelection: root.packageToggled(modelData.name)
        }

        // Empty state
        Rectangle {
            anchors.centerIn: parent
            visible: root.model.length === 0 && !root.loading
            width: 280; height: 80
            color: "transparent"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: T.space_sm

                Text {
                    text: root.loading ? "⏳" : "◌"
                    color: T.foreground_subtle
                    font.family: T.font_family
                    font.pixelSize: 28
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: root.loading ? "Searching…" : "No packages found"
                    color: T.foreground_muted
                    font.family: T.font_family
                    font.pixelSize: T.body_size
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: root.loading ? "" : "Try a different search or filter"
                    color: T.foreground_subtle
                    font.family: T.font_family
                    font.pixelSize: T.small_size
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    }
}
