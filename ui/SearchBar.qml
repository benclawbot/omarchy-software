import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    height: 38
    color: theme.darker_background
    radius: 8
    anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }

    property string text: input.text
    property string sourceFilter: sourceChips.current

    // Source filter chips
    Row {
        id: sourceChips
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        x: 10; spacing: 6
        property string current: "all"

        Repeater {
            model: ["all", "repo", "aur"]
            delegate: Rectangle {
                id: chip
                radius: 4; height: 22
                width: label.implicitWidth + 16
                color: sourceChips.current === modelData ? theme.accent : theme.muted
                opacity: sourceChips.current === modelData ? 0.2 : 1.0
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData === "all" ? "All" : modelData === "repo" ? "Repos" : "AUR"
                    color: sourceChips.current === modelData ? theme.accent : theme.dark_foreground
                    font.family: "monospace"; font.pixelSize: 11
                    font.weight: sourceChips.current === modelData ? Font.Bold : Font.Normal
                }

                MouseArea { anchors.fill: parent; onClicked: sourceChips.current = modelData }
            }
        }
    }

    Rectangle {
        anchors.left: sourceChips.right; anchors.right: clearButton.left
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height - 8
        color: theme.background; radius: 4

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 10
            font.family: "monospace"; font.pixelSize: 13
            color: theme.foreground; selectionColor: theme.selection
            verticalAlignment: Text.AlignVCenter
            focus: true
            inputMethodHints: Qt.ImhNoPredictiveText

            // Debounce search
            onTextChanged: searchTimer.restart()
        }
    }

    Timer {
        id: searchTimer
        interval: 250; repeat: false
        onTriggered: root.doSearch()
    }

    Button {
        id: clearButton
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        rightPadding: 8
        visible: input.text.length > 0
        flat: true
        onClicked: { input.text = ""; root.doSearch() }
        contentItem: Text {
            text: "✕"
            color: theme.muted; font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
    }

    function doSearch() {
        bridge.search(input.text, sourceChips.current)
    }
}
