import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "Theme.js" as T

Window {
    id: root
    width: 920
    height: 640
    minimumWidth: 720
    minimumHeight: 480
    visible: true
    flags: Qt.FramelessWindowHint
    title: "Omarchy Software"
    color: T.background

    // ── Title bar ─────────────────────────────────────────────────────────────
    Rectangle {
        id: titleBar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: T.titlebar_height
        color: T.surface

        // Bottom border
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1; color: T.divider
        }

        // Drag region — middle of title bar
        MouseArea {
            anchors.fill: parent
            anchors.leftMargin: 140
            anchors.rightMargin: closeButton.width + 16
            property point press
            onPressed: press = Qt.point(mouseX, mouseY)
            onPositionChanged: {
                if (pressed) {
                    root.x += mouseX - press.x
                    root.y += mouseY - press.y
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: T.space_lg
            anchors.rightMargin: T.space_sm
            spacing: T.space_md

            Image {
                source: "omarchy-logo.svg"
                sourceSize.width: 22
                sourceSize.height: 22
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
            }

            Text {
                text: "Software"
                color: T.foreground
                font.family: T.font_family
                font.pixelSize: T.subhead_size
                font.weight: T.weight_medium
            }

            Item { Layout.fillWidth: true; Layout.preferredWidth: 20 }

            TabBar {
                id: tabBar
                Layout.fillWidth: false
                background: Rectangle { color: "transparent" }

                TabButton {
                    text: "Updates"
                    width: 90
                    contentItem: Text {
                        text: parent.text
                        color: tabBar.currentIndex === 0 ? T.foreground : T.foreground_dim
                        font.family: T.font_family
                        font.pixelSize: T.body_size
                        font.weight: tabBar.currentIndex === 0 ? T.weight_medium : T.weight_normal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: "transparent"
                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 2
                            color: T.accent
                            visible: tabBar.currentIndex === 0
                        }
                    }
                }
                TabButton {
                    text: "Browse"
                    width: 90
                    contentItem: Text {
                        text: parent.text
                        color: tabBar.currentIndex === 1 ? T.foreground : T.foreground_dim
                        font.family: T.font_family
                        font.pixelSize: T.body_size
                        font.weight: tabBar.currentIndex === 1 ? T.weight_medium : T.weight_normal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: "transparent"
                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 2
                            color: T.accent
                            visible: tabBar.currentIndex === 1
                        }
                    }
                }
                TabButton {
                    text: "Installed"
                    width: 100
                    contentItem: Text {
                        text: parent.text
                        color: tabBar.currentIndex === 2 ? T.foreground : T.foreground_dim
                        font.family: T.font_family
                        font.pixelSize: T.body_size
                        font.weight: tabBar.currentIndex === 2 ? T.weight_medium : T.weight_normal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: "transparent"
                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 2
                            color: T.accent
                            visible: tabBar.currentIndex === 2
                        }
                    }
                }
                TabButton {
                    text: "Cache"
                    width: 90
                    contentItem: Text {
                        text: parent.text
                        color: tabBar.currentIndex === 3 ? T.foreground : T.foreground_dim
                        font.family: T.font_family
                        font.pixelSize: T.body_size
                        font.weight: tabBar.currentIndex === 3 ? T.weight_medium : T.weight_normal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: "transparent"
                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 2
                            color: T.accent
                            visible: tabBar.currentIndex === 3
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true; Layout.preferredWidth: 20 }

            // Close button
            Rectangle {
                id: closeButton
                width: 28; height: 28
                radius: T.radius_md
                color: closeMouse.containsMouse ? T.danger : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: closeMouse.containsMouse ? "#1e1e2e" : T.foreground_dim
                    font.family: T.font_family
                    font.pixelSize: T.body_size
                    font.weight: T.weight_bold
                }
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.quit()
                }
            }
        }
    }

    // ── Main content area ─────────────────────────────────────────────────────
    Item {
        anchors {
            top: titleBar.bottom
            left: parent.left; right: parent.right
            bottom: parent.bottom
        }

        // Content stack
        StackLayout {
            anchors.fill: parent
            anchors.topMargin: T.space_md
            currentIndex: tabBar.currentIndex

            UpdatesView  { id: updatesView }
            BrowseView   { id: browseView }
            InstalledView { id: installedView }
            CacheView    { id: cacheView }
        }

        // Preview pane (overlays content)
        PreviewPane {
            id: previewPane
            anchors {
                bottom: parent.bottom
                left: parent.left; right: parent.right
            }
            anchors.leftMargin: T.space_md
            anchors.rightMargin: T.space_md
            anchors.bottomMargin: T.space_md
            height: visible ? implicitHeight : 0
            visible: height > 0
        }

        // Error banner (overlays content)
        ErrorBanner {
            id: errorBanner
            anchors {
                top: parent.top
                left: parent.left; right: parent.right
            }
            anchors.leftMargin: T.space_md
            anchors.rightMargin: T.space_md
            z: 9
            visible: false
        }

        // Progress panel (modal overlay)
        ProgressPanel {
            id: progressPanel
            anchors.fill: parent
            z: 10
            visible: false
        }
    }
}
