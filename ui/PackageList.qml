import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    color: "transparent"

    // ── Column headers ────────────────────────────────────────────────────────
    Row {
        id: colHeaders
        anchors { top: parent.top; left: parent.left; right: parent.right }
        x: 12; width: parent.width - 24
        height: 24
        spacing: 8

        Rectangle {
            width: 20; height: 20; radius: 4
            anchors.verticalCenter: parent.verticalCenter
            color: theme.selection
            CheckBox {
                id: selectAll
                anchors.centerIn: parent
                onCheckedChanged: {
                    for (let i = 0; i < packageModel.count; ++i)
                        packageModel.setProperty(i, "selected", checked)
                }
            }
        }

        ThinLabel { text: "Package";  flex: 3; isHeader: true }
        ThinLabel { text: "Version";  flex: 2; isHeader: true }
        ThinLabel { text: "Source";   flex: 1; isHeader: true }
        ThinLabel { text: "Size";     flex: 1; isHeader: true; horizontalAlignment: Text.AlignRight }
    }

    Rectangle {
        anchors { top: colHeaders.bottom; left: parent.left; right: parent.right }
        height: 1; color: theme.muted; opacity: 0.3
    }

    // ── Package list ─────────────────────────────────────────────────────────
    ListView {
        id: view
        anchors {
            top: colHeaders.bottom; bottom: parent.bottom
            left: parent.left; right: parent.right
        }
        anchors.topMargin: 4
        clip: true

        // Stagger-in animation when list loads
        populate: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
            NumberAnimation { property: "y"; from: delegate.ListView.view.contentY + 40; duration: 200 }
        }

        model: ListModel { id: packageModel }

        delegate: PackageCard {
            width: view.width
            onSelectedChanged: {
                if (selected) {
                    if (!delegate.ListView.view.selection.contains(index))
                        delegate.ListView.view.selection.append(index)
                } else {
                    delegate.ListView.view.selection.remove(index)
                }
            }
        }

        highlight: Rectangle {
            color: theme.selection; radius: 4
        }

        ScrollBar.vertical: ScrollBar {
            width: 6
            policy: ScrollBar.AsNeeded
        }
    }

    // ── Empty state ───────────────────────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        text: "No packages found"
        color: theme.muted
        font.family: "monospace"; font.pixelSize: 13
        visible: packageModel.count === 0
    }
}
