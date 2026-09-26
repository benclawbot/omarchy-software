import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: card
    property bool selected: false
    property string name: model ? model.name : ""
    property string version: model ? model.version : ""
    property string description: model ? (model.description || "") : ""
    property string source: model ? (model.source || "repo") : "repo"
    property string size: model ? model.size_human : ""
    property string repo: model ? (model.repo || "") : ""

    color: selected ? theme.selection : "transparent"
    radius: 6
    height: 38

    // Highlight on hover even when not selected
    Rectangle {
        anchors.fill: parent
        color: theme.selection
        opacity: mouseArea.containsMouse ? 0.5 : 0
        radius: parent.radius
        z: -1
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            // Toggle selection on click
            if (selectionMode) {
                card.selected = !card.selected
            } else {
                // Single-click inspect
                root.inspectPackage(name)
            }
        }
        onDoubleClicked: {
            if (!selectionMode) {
                // Double-click to install / remove depending on state
                if (model && model.installed) {
                    root.queueRemove([name])
                } else {
                    root.queueInstall([name], [source])
                }
            }
        }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12; anchors.rightMargin: 12
        spacing: 8
        y: (parent.height - this.height) / 2

        // Checkbox
        Rectangle {
            width: 20; height: 20; radius: 4
            color: theme.lighter_background
            visible: selectionMode
            anchors.verticalCenter: parent.verticalCenter
            CheckBox {
                id: cb
                checked: card.selected
                anchors.centerIn: parent
                onToggled: card.selected = checked
            }
        }

        // Package name + description
        Column {
            flex: 3
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Row {
                Text {
                    text: card.name
                    color: theme.foreground
                    font.family: "monospace"; font.pixelSize: 13; font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    text: model && model.installed ? " ●" : ""
                    color: theme.green; font.family: "monospace"; font.pixelSize: 11
                    visible: model && model.installed
                }
            }
            Text {
                text: card.description
                color: theme.dark_foreground; font.family: "monospace"; font.pixelSize: 10
                elide: Text.ElideRight; maximumLineCount: 1
                visible: card.description.length > 0
            }
        }

        // Version
        Text {
            text: card.version
            color: theme.dark_foreground; font.family: "monospace"; font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter; flex: 2
            elide: Text.ElideRight
        }

        // Source badge
        SourceBadge {
            source: card.source; repo: card.repo
            anchors.verticalCenter: parent.verticalCenter; flex: 1
        }

        // Size
        Text {
            text: card.size
            color: theme.dark_foreground; font.family: "monospace"; font.pixelSize: 12
            anchors.verticalCenter: parent.verticalCenter; flex: 1
            horizontalAlignment: Text.AlignRight
        }
    }
}
