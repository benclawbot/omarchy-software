import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: theme.dark_background
    radius: 8
    anchors { left: parent.left; right: parent.right }
    anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.bottomMargin: 8

    // ── Header ─────────────────────────────────────────────────────────────
    Row {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.margins: 12
        height: 38

        Text {
            text: "Review changes"
            color: theme.foreground; font.family: "monospace"
            font.pixelSize: 13; font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }

        Item { Layout.fillWidth: true }

        Button {
            id: cancelPreviewButton
            text: "Cancel"
            flat: true; anchors.verticalCenter: parent.verticalCenter
            onClicked: bridge.cancelPreview()
            contentItem: Text {
                text: cancelPreviewButton.text; color: theme.dark_foreground
                font.family: "monospace"; font.pixelSize: 12
            }
        }

        Button {
            id: applyPreviewButton
            text: "Apply"
            anchors.verticalCenter: parent.verticalCenter
            rightPadding: 4
            onClicked: bridge.commit(previewData)
            contentItem: Text {
                text: applyPreviewButton.text; color: theme.background
                font.family: "monospace"; font.pixelSize: 12; font.weight: Font.Bold
            }
            background: Rectangle {
                color: theme.accent; radius: 4
                anchors.fill: parent
            }
        }
    }

    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: theme.muted; opacity: 0.3 }

    // ── Change list ─────────────────────────────────────────────────────────
    ListView {
        id: changeList
        anchors {
            top: parent.top; bottom: actionBar.top
            left: parent.left; right: parent.right
        }
        anchors.topMargin: 38
        clip: true

        model: ListModel { id: previewModel }

        delegate: Row {
            width: changeList.width - 24
            spacing: 8
            height: 28

            property string kind: model.kind // "install" | "update" | "remove" | "cascade" | "warning"

            Rectangle {
                width: 8; height: 8; radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: {
                    if (kind === "install" || kind === "reinstall") return theme.green
                    if (kind === "update") return theme.blue
                    if (kind === "remove") return theme.red
                    if (kind === "cascade") return theme.orange
                    return theme.yellow
                }
            }

            Text {
                text: model.name
                color: theme.foreground; font.family: "monospace"; font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
                width: changeList.width * 0.55
                elide: Text.ElideRight
            }

            Text {
                text: model.detail
                color: theme.dark_foreground; font.family: "monospace"; font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
            }

            // Checkbox to deselect before applying
            CheckBox {
                checked: model.selected !== false
                anchors.verticalCenter: parent.verticalCenter
                onToggled: model.selected = checked
            }
        }
    }

    // ── Summary bar ─────────────────────────────────────────────────────────
    Row {
        id: actionBar
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        anchors.leftMargin: 12; anchors.rightMargin: 12
        height: 34

        Text {
            text: {
                const n = previewModel.count
                if (n === 0) return "Nothing to do"
                const installing = previewModel.count(model => model.kind === "install" || model.kind === "reinstall")
                const removing = previewModel.count(model => model.kind === "remove")
                const parts = []
                if (installing > 0) parts.push(`+${installing} install`)
                if (removing > 0) parts.push(`-${removing} remove`)
                return parts.join("  ·  ") + `  (${n} total)`
            }
            color: theme.dark_foreground; font.family: "monospace"; font.pixelSize: 11
            anchors.verticalCenter: parent.verticalCenter
        }

        Item { Layout.fillWidth: true }

        Text {
            text: "Select individual items to exclude them"
            color: theme.muted; font.family: "monospace"; font.pixelSize: 10
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
