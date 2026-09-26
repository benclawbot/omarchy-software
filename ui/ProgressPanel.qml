import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "Theme.js" as T

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
        radius: T.radius_xl
        color: T.surface_elevated
        border.width: 1
        border.color: T.divider

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: T.space_lg
            spacing: T.space_md

            Text {
                text: root.title
                color: T.foreground
                font.family: T.font_family
                font.pixelSize: T.subhead_size
                font.weight: T.weight_bold
            }

            ProgressBar {
                Layout.fillWidth: true
                from: 0; to: 1
                indeterminate: root.progress < 0
                value: root.progress >= 0 ? root.progress : 0

                background: Rectangle {
                    implicitHeight: 4
                    color: T.surface
                    radius: 2
                }
                contentItem: Item {
                    Rectangle {
                        width: parent.width * (parent.indeterminate
                                                ? 0.3
                                                : (parent.visualPosition * parent.width))
                        height: 4
                        radius: 2
                        color: T.accent

                        SequentialAnimation on x {
                            loops: Animation.Infinite
                            running: parent.parent.indeterminate
                            PropertyAnimation { to: parent.width * 0.7; duration: 800 }
                            PropertyAnimation { to: 0;              duration: 0 }
                        }
                    }
                }
            }

            Text {
                text: root.detail
                color: T.foreground_muted
                font.family: T.font_family
                font.pixelSize: T.small_size
                Layout.fillWidth: true
                elide: Text.ElideMiddle
            }
        }
    }
}
