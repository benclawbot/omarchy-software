import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// PreviewPane — staged transaction preview shown before applying.
// Shows install list, remove list, cascade and required-by deps.
Rectangle {
    id: root

    property var preview: ({ install: [], remove: [], cascade: [], required_by: {} })
    property bool expanded: false
    signal applyRequested(var preview)
    signal cancelRequested()

    function show(previewObj) {
        preview = previewObj || preview
        expanded = true
    }
    function hide() { expanded = false }

    implicitHeight: 240
    height: expanded ? implicitHeight : 0
    visible: expanded
    radius: theme.radius_xl
    color: theme.surface_elevated
    border.width: 1
    border.color: theme.divider

    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    // Header
    RowLayout {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.margins: theme.space_md
        spacing: theme.space_md

        Text {
            text: "Review changes"
            color: theme.foreground
            font.family: theme.font_family
            font.pixelSize: theme.subhead_size
            font.weight: theme.weight_bold
            Layout.fillWidth: true
        }

        // Counts
        Row {
            spacing: theme.space_sm

            Rectangle {
                visible: root.preview.install && root.preview.install.length > 0
                implicitWidth: installCount.implicitWidth + 14
                implicitHeight: 22
                radius: theme.radius_sm
                color: Qt.rgba(0.651, 0.890, 0.631, 0.18)
                Text {
                    id: installCount
                    anchors.centerIn: parent
                    text: "+" + (root.preview.install ? root.preview.install.length : 0)
                    color: theme.success
                    font.family: theme.font_family
                    font.pixelSize: theme.caption_size
                    font.weight: theme.weight_bold
                }
            }
            Rectangle {
                visible: root.preview.remove && root.preview.remove.length > 0
                implicitWidth: removeCount.implicitWidth + 14
                implicitHeight: 22
                radius: theme.radius_sm
                color: Qt.rgba(0.953, 0.545, 0.659, 0.18)
                Text {
                    id: removeCount
                    anchors.centerIn: parent
                    text: "−" + (root.preview.remove ? root.preview.remove.length : 0)
                    color: theme.danger
                    font.family: theme.font_family
                    font.pixelSize: theme.caption_size
                    font.weight: theme.weight_bold
                }
            }
        }

        StyledButton { text: "Cancel"; variant: "ghost"; onClicked: { root.cancelRequested(); root.hide() } }
        StyledButton { text: "Apply";  variant: "primary"; onClicked: root.applyRequested(root.preview) }
    }

    // Body
    Rectangle {
        anchors {
            top: header.bottom
            left: parent.left; right: parent.right
            bottom: parent.bottom
        }
        anchors.topMargin: theme.space_sm
        anchors.bottomMargin: theme.space_md
        anchors.leftMargin: theme.space_md
        anchors.rightMargin: theme.space_md
        color: theme.background
        radius: theme.radius_md
        border.width: 1
        border.color: theme.divider

        ScrollView {
            id: previewScroll
            anchors.fill: parent
            anchors.margins: 1
            clip: true

            // Overlay scrollbar that doesn't shift content when it appears.
            ScrollBar.vertical: StyledScrollBar { policy: ScrollBar.AsNeeded }

            ColumnLayout {
                width: parent.width
                spacing: theme.space_xs

                // Install list
                Repeater {
                    model: root.preview.install || []
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: theme.space_sm
                        Rectangle {
                            width: 4
                            Layout.preferredHeight: 20
                            radius: 2
                            color: theme.success
                        }
                        Text {
                            text: modelData.name || modelData
                            color: theme.foreground
                            font.family: theme.font_family
                            font.pixelSize: theme.small_size
                            font.weight: theme.weight_medium
                            Layout.fillWidth: true
                        }
                        Text {
                            text: modelData.version || ""
                            color: theme.foreground_dim
                            font.family: theme.font_family
                            font.pixelSize: theme.small_size
                        }
                    }
                }

                // Remove list
                Repeater {
                    model: root.preview.remove || []
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: theme.space_sm
                        Rectangle {
                            width: 4
                            Layout.preferredHeight: 20
                            radius: 2
                            color: theme.danger
                        }
                        Text {
                            text: modelData.name || modelData
                            color: theme.foreground
                            font.family: theme.font_family
                            font.pixelSize: theme.small_size
                            font.weight: theme.weight_medium
                            Layout.fillWidth: true
                        }
                        Text {
                            text: modelData.version || ""
                            color: theme.foreground_dim
                            font.family: theme.font_family
                            font.pixelSize: theme.small_size
                        }
                    }
                }

                // Cascade (orphans to be removed)
                Repeater {
                    model: root.preview.cascade || []
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: theme.space_sm
                        Rectangle {
                            width: 4
                            Layout.preferredHeight: 20
                            radius: 2
                            color: theme.warning
                        }
                        Text {
                            text: modelData.name || modelData
                            color: theme.foreground_muted
                            font.family: theme.font_family
                            font.pixelSize: theme.small_size
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "cascade"
                            color: theme.warning
                            font.family: theme.font_family
                            font.pixelSize: theme.caption_size
                            font.weight: theme.weight_bold
                        }
                    }
                }
            }
        }
    }
}
