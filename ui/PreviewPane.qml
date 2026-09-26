import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "Theme.js" as T

// PreviewPane — staged transaction preview shown before applying.
// Shows install list, remove list, cascade and required-by deps.
Rectangle {
    id: root

    property var preview: ({ install: [], remove: [], cascade: [], required_by: {} })

    function show(previewObj) { preview = previewObj || preview; height = 240 }
    function hide() { height = 0 }

    implicitHeight: 240
    radius: T.radius_xl
    color: T.surface_elevated
    border.width: 1
    border.color: T.divider

    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    // Header
    RowLayout {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors.margins: T.space_md
        spacing: T.space_md

        Text {
            text: "Review changes"
            color: T.foreground
            font.family: T.font_family
            font.pixelSize: T.subhead_size
            font.weight: T.weight_bold
            Layout.fillWidth: true
        }

        // Counts
        Row {
            spacing: T.space_sm

            Rectangle {
                visible: root.preview.install && root.preview.install.length > 0
                implicitWidth: installCount.implicitWidth + 14
                implicitHeight: 22
                radius: T.radius_sm
                color: Qt.rgba(0.651, 0.890, 0.631, 0.18)
                Text {
                    id: installCount
                    anchors.centerIn: parent
                    text: "+" + (root.preview.install ? root.preview.install.length : 0)
                    color: T.success
                    font.family: T.font_family
                    font.pixelSize: T.caption_size
                    font.weight: T.weight_bold
                }
            }
            Rectangle {
                visible: root.preview.remove && root.preview.remove.length > 0
                implicitWidth: removeCount.implicitWidth + 14
                implicitHeight: 22
                radius: T.radius_sm
                color: Qt.rgba(0.953, 0.545, 0.659, 0.18)
                Text {
                    id: removeCount
                    anchors.centerIn: parent
                    text: "−" + (root.preview.remove ? root.preview.remove.length : 0)
                    color: T.danger
                    font.family: T.font_family
                    font.pixelSize: T.caption_size
                    font.weight: T.weight_bold
                }
            }
        }

        StyledButton { text: "Cancel"; variant: "ghost"; onClicked: root.hide() }
        StyledButton { text: "Apply";  variant: "primary"; onClicked: root.hide() }
    }

    // Body
    Rectangle {
        anchors {
            top: header.bottom
            left: parent.left; right: parent.right
            bottom: parent.bottom
        }
        anchors.topMargin: T.space_sm
        anchors.bottomMargin: T.space_md
        anchors.leftMargin: T.space_md
        anchors.rightMargin: T.space_md
        color: T.background
        radius: T.radius_md
        border.width: 1
        border.color: T.divider

        ScrollView {
            anchors.fill: parent
            anchors.margins: 1

            ColumnLayout {
                width: parent.width
                spacing: T.space_xs

                // Install list
                Repeater {
                    model: root.preview.install || []
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: T.space_sm
                        Rectangle {
                            width: 4
                            Layout.preferredHeight: 20
                            radius: 2
                            color: T.success
                        }
                        Text {
                            text: modelData.name || modelData
                            color: T.foreground
                            font.family: T.font_family
                            font.pixelSize: T.small_size
                            font.weight: T.weight_medium
                            Layout.fillWidth: true
                        }
                        Text {
                            text: modelData.version || ""
                            color: T.foreground_dim
                            font.family: T.font_family
                            font.pixelSize: T.small_size
                        }
                    }
                }

                // Remove list
                Repeater {
                    model: root.preview.remove || []
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: T.space_sm
                        Rectangle {
                            width: 4
                            Layout.preferredHeight: 20
                            radius: 2
                            color: T.danger
                        }
                        Text {
                            text: modelData.name || modelData
                            color: T.foreground
                            font.family: T.font_family
                            font.pixelSize: T.small_size
                            font.weight: T.weight_medium
                            Layout.fillWidth: true
                        }
                        Text {
                            text: modelData.version || ""
                            color: T.foreground_dim
                            font.family: T.font_family
                            font.pixelSize: T.small_size
                        }
                    }
                }

                // Cascade (orphans to be removed)
                Repeater {
                    model: root.preview.cascade || []
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: T.space_sm
                        Rectangle {
                            width: 4
                            Layout.preferredHeight: 20
                            radius: 2
                            color: T.warning
                        }
                        Text {
                            text: modelData.name || modelData
                            color: T.foreground_muted
                            font.family: T.font_family
                            font.pixelSize: T.small_size
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "cascade"
                            color: T.warning
                            font.family: T.font_family
                            font.pixelSize: T.caption_size
                            font.weight: T.weight_bold
                        }
                    }
                }
            }
        }
    }
}
