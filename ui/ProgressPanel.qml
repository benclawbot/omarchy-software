import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// ProgressPanel — modal overlay while a transaction is running.
Rectangle {
    id: root

    property string title: "Working…"
    property string detail: ""
    property real progress: -1  // -1 = indeterminate

    color: Qt.rgba(0.07, 0.07, 0.10, 0.7)

    Rectangle {
        anchors.centerIn: parent
        width: 360; height: 140
        radius: theme.radius_xl
        color: theme.surface_elevated
        border.width: 1
        border.color: theme.divider

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: theme.space_lg
            spacing: theme.space_md

            Text {
                text: root.title
                color: theme.foreground
                font.family: theme.font_family
                font.pixelSize: theme.subhead_size
                font.weight: theme.weight_bold
            }

            ProgressBar {
                id: progressBar
                Layout.fillWidth: true
                from: 0; to: 1
                indeterminate: root.progress < 0
                value: root.progress >= 0 ? root.progress : 0

                background: Rectangle {
                    implicitHeight: 4
                    color: theme.surface
                    radius: 2
                }
                contentItem: Item {
                    Rectangle {
                        width: parent.width * (progressBar.indeterminate
                                                ? 0.3
                                                : progressBar.visualPosition)
                        height: 4
                        radius: 2
                        color: theme.accent

                        SequentialAnimation on x {
                            loops: Animation.Infinite
                            running: progressBar.indeterminate
                            PropertyAnimation { to: parent.width * 0.7; duration: 800 }
                            PropertyAnimation { to: 0;              duration: 0 }
                        }
                    }
                }
            }

            Text {
                text: root.detail
                color: theme.foreground_muted
                font.family: theme.font_family
                font.pixelSize: theme.small_size
                Layout.fillWidth: true
                elide: Text.ElideMiddle
            }
        }
    }
}
