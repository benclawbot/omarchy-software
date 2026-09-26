import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Window {
    id: root
    width: 920
    height: 640
    minimumWidth: 720
    minimumHeight: 480
    visible: true
    flags: Qt.FramelessWindowHint
    title: "Omarchy Software"
    color: theme.background

    Component.onCompleted: {
        if (bridge.page !== undefined) bridge.page = "installed"
        if (bridge.loadInstalled) bridge.loadInstalled("all")
    }

    // ── Title bar ─────────────────────────────────────────────────────────────
    Rectangle {
        id: titleBar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: theme.titlebar_height
        color: theme.surface

        // Bottom border
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1; color: theme.divider
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
            anchors.leftMargin: theme.space_lg
            anchors.rightMargin: theme.space_sm
            spacing: theme.space_md

            Image {
                source: "omarchy-logo.svg"
                sourceSize.width: 22
                sourceSize.height: 22
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
            }

            Text {
                text: "Software"
                color: theme.foreground
                font.family: theme.font_family
                font.pixelSize: theme.subhead_size
                font.weight: theme.weight_medium
            }

            Item { Layout.fillWidth: true; Layout.preferredWidth: 20 }

            TabBar {
                id: tabBar
                currentIndex: 2
                Layout.fillWidth: false
                height: 36
                padding: 3
                background: Rectangle {
                    radius: theme.radius_md
                    color: theme.background
                    border.width: 1
                    border.color: theme.divider
                }

                TabButton {
                    text: "Updates"
                    width: 88
                    height: 30
                    contentItem: Text {
                        text: parent.text
                        color: tabBar.currentIndex === 0 ? theme.foreground : theme.foreground_dim
                        font.family: theme.font_family
                        font.pixelSize: theme.body_size
                        font.weight: tabBar.currentIndex === 0 ? theme.weight_medium : theme.weight_normal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: theme.radius_sm
                        color: tabBar.currentIndex === 0 ? theme.surface_elevated : "transparent"
                    }
                }
                TabButton {
                    text: "Install"
                    width: 88
                    height: 30
                    contentItem: Text {
                        text: parent.text
                        color: tabBar.currentIndex === 1 ? theme.foreground : theme.foreground_dim
                        font.family: theme.font_family
                        font.pixelSize: theme.body_size
                        font.weight: tabBar.currentIndex === 1 ? theme.weight_medium : theme.weight_normal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: theme.radius_sm
                        color: tabBar.currentIndex === 1 ? theme.surface_elevated : "transparent"
                    }
                }
                TabButton {
                    text: "Remove"
                    width: 100
                    height: 30
                    contentItem: Text {
                        text: parent.text
                        color: tabBar.currentIndex === 2 ? theme.foreground : theme.foreground_dim
                        font.family: theme.font_family
                        font.pixelSize: theme.body_size
                        font.weight: tabBar.currentIndex === 2 ? theme.weight_medium : theme.weight_normal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: theme.radius_sm
                        color: tabBar.currentIndex === 2 ? theme.surface_elevated : "transparent"
                    }
                }
            }

            Item { Layout.fillWidth: true; Layout.preferredWidth: 20 }

            // Close button
            Rectangle {
                id: closeButton
                width: 28; height: 28
                radius: theme.radius_md
                color: closeMouse.containsMouse ? theme.danger : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: closeMouse.containsMouse ? "#1e1e2e" : theme.foreground_dim
                    font.family: theme.font_family
                    font.pixelSize: theme.body_size
                    font.weight: theme.weight_bold
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
            anchors.topMargin: theme.space_sm
            currentIndex: tabBar.currentIndex

            UpdatesView  { id: updatesView }
            BrowseView   { id: browseView }
            InstalledView { id: installedView }
        }

        Connections {
            target: bridge
            ignoreUnknownSignals: true
            function onPreviewReady(preview) { previewPane.show(preview) }
            function onOperationFinished(action, packages, message) {
                previewPane.hide()
                progressPanel.visible = false
                toast.showAction(action, packages, message)
            }
            function onError(message) { errorBanner.visible = true; errorBanner.message = message }
        }

        Connections {
            target: previewPane
            function onApplyRequested(preview) { bridge.commit(preview) }
            function onCancelRequested() { bridge.cancelPreview() }
        }

        Connections {
            target: tabBar
            function onCurrentIndexChanged() {
                if (bridge.page !== undefined) bridge.page = ["updates", "browse", "installed"][tabBar.currentIndex]
                if (bridge.setSelected) bridge.setSelected([])
                installedView.selectedNames = []
                if (tabBar.currentIndex === 0 && bridge.checkUpdates) bridge.checkUpdates()
                if (tabBar.currentIndex === 2) installedView.refreshPackages()
                if (tabBar.currentIndex === 1) browseView.runSearch(browseView.searchText)
            }
        }

        // Preview pane (overlays content)
        PreviewPane {
            id: previewPane
            anchors {
                bottom: parent.bottom
                left: parent.left; right: parent.right
            }
            anchors.leftMargin: theme.space_md
            anchors.rightMargin: theme.space_md
            anchors.bottomMargin: theme.space_md
        }

        // Error banner (overlays content)
        ErrorBanner {
            id: errorBanner
            anchors {
                top: parent.top
                left: parent.left; right: parent.right
            }
            anchors.leftMargin: theme.space_md
            anchors.rightMargin: theme.space_md
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

        // Toast — transient confirmation after a package action.
        Toast {
            id: toast
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                topMargin: theme.space_lg
            }
            z: 11
            // Wire the action-aware formatter from the parent scope.
            formatActionMessageFn: function(action, packages, rawOutput) {
                return formatActionMessage(action, packages, rawOutput)
            }
            onDismissed: { /* auto-handled by Timer inside Toast */ }
        }
    }

    // Translate an action kind + package list into a human-readable
    // toast message. The detail line carries the raw pacman output
    // for transparency when it is meaningful.
    function formatActionMessage(action, packages, rawOutput) {
        var names = packages || []
        var count = names.length
        var variant = "success"
        if (action === "install") {
            if (count === 0) return { text: qsTr("Package installed"), variant: variant }
            if (count === 1) return { text: qsTr("Installed ") + names[0], variant: variant }
            var preview = names.slice(0, 3).join(", ")
            if (count > 3) preview += " (+" + (count - 3) + " more)"
            return { text: qsTr("Installed ") + count + " packages", detail: preview, variant: variant }
        }
        if (action === "update") {
            if (count === 0) return { text: qsTr("System is up to date"), variant: variant }
            if (count === 1) return { text: qsTr("Updated ") + names[0], variant: variant }
            var previewU = names.slice(0, 3).join(", ")
            if (count > 3) previewU += " (+" + (count - 3) + " more)"
            return { text: qsTr("Updated ") + count + " packages", detail: previewU, variant: variant }
        }
        if (action === "remove") {
            if (count === 0) return { text: qsTr("Package removed"), variant: variant }
            if (count === 1) return { text: qsTr("Removed ") + names[0], variant: variant }
            var previewR = names.slice(0, 3).join(", ")
            if (count > 3) previewR += " (+" + (count - 3) + " more)"
            return { text: qsTr("Removed ") + count + " packages", detail: previewR, variant: variant }
        }
        if (rawOutput && rawOutput.length > 0) return { text: rawOutput, variant: variant }
        return { text: qsTr("Done"), variant: variant }
    }
}
