import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: theme.background
    radius: 12

    // ── Drag region ────────────────────────────────────────────────────────────
    MouseArea {
        id: dragArea
        anchors.fill: parent
        property point press
        onPressed: press = Qt.point(mouseX, mouseY)
        onMouseYChanged: {
            if (pressed && Math.abs(mouseY - press.y) > 4)
                mainWindow.startSystemMove()
        }
    }

    // ── Title bar ─────────────────────────────────────────────────────────────
    RowLayout {
        id: titleBar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 40
        spacing: 8

        Image {
            source: "omarchy-logo.svg"
            Layout.preferredWidth: 20; Layout.preferredHeight: 20
            Layout.leftMargin: 12
        }

        Text {
            text: "Software"
            color: theme.foreground
            font.family: "monospace"
            font.pixelSize: 14
            font.weight: Font.Medium
            Layout.fillWidth: true
        }

        TabBar {
            id: tabBar
            Layout.preferredWidth: contentWidth + 16
            background: Rectangle { color: "transparent" }

            TabButton { text: "Updates"; tab: "updates" }
            TabButton { text: "Browse"; tab: "browse" }
            TabButton { text: "Installed"; tab: "installed" }
            TabButton { text: "Cache"; tab: "cache" }
        }

        Button {
            text: "×"
            flat: true
            onClicked: Qt.quit()
            Layout.rightMargin: 8
            contentItem: Text {
                text: parent.text
                color: theme.foreground
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    // ── Source legend ─────────────────────────────────────────────────────────
    Row {
        id: legend
        anchors { top: titleBar.bottom; left: parent.left; right: parent.right }
        topPadding: 6
        bottomPadding: 4
        leftPadding: 12
        spacing: 16

        Repeater {
            model: [
                { color: "#89b4fa", label: "Repository" },
                { color: "#cba6f7", label: "AUR" },
                { color: "#94e2d5", label: "CachyOS" },
            ]

            Row { spacing: 4
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: modelData.color; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: modelData.label
                    color: theme.dark_foreground
                    font.family: "monospace"; font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // ── Search ────────────────────────────────────────────────────────────────
    SearchBar {
        id: searchBar
        anchors {
            top: legend.bottom
            left: parent.left; right: parent.right
        }
        visible: tabBar.currentIndex === 1 // Browse tab
    }

    // ── Content stack ─────────────────────────────────────────────────────────
    StackLayout {
        anchors {
            top: searchBar.bottom; bottom: previewPane.top
            left: parent.left; right: parent.right
        }
        topPadding: 8; bottomPadding: 8
        currentIndex: tabBar.currentIndex

        UpdatesView  { id: updatesView }
        BrowseView  { id: browseView  }
        InstalledView { id: installedView }
        CacheView   { id: cacheView   }
    }

    // ── Preview pane ──────────────────────────────────────────────────────────
    PreviewPane {
        id: previewPane
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: previewPane.visible ? implicitHeight : 0
        visible: height > 0
    }

    // ── Progress panel ────────────────────────────────────────────────────────
    ProgressPanel {
        id: progressPanel
        anchors.fill: parent
        z: 10
        visible: false
    }

    // ── Error banner ──────────────────────────────────────────────────────────
    ErrorBanner {
        id: errorBanner
        anchors { top: titleBar.bottom; left: parent.left; right: parent.right }
        z: 9
        visible: false
    }

    // ── Theme ────────────────────────────────────────────────────────────────
    Theme { id: themeJS }
}
