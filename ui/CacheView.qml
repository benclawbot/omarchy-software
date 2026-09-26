import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "Theme.js" as T

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: T.space_lg
        spacing: T.space_md

        // Page header
        ColumnLayout {
            Layout.fillWidth: true
            spacing: T.space_xs

            Text {
                text: "Package cache"
                color: T.foreground
                font.family: T.font_family
                font.pixelSize: T.headline_size
                font.weight: T.weight_bold
            }
            Text {
                text: "Downloaded .pkg.tar files kept by pacman"
                color: T.foreground_muted
                font.family: T.font_family
                font.pixelSize: T.small_size
            }
        }

        // Stats card
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 84
            radius: T.radius_lg
            color: T.surface
            border.width: 1
            border.color: T.divider

            RowLayout {
                anchors.fill: parent
                anchors.margins: T.space_lg
                spacing: T.space_xl

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    Text {
                        text: "Cached packages"
                        color: T.foreground_subtle
                        font.family: T.font_family
                        font.pixelSize: T.caption_size
                        font.weight: T.weight_bold
                    }
                    Text {
                        text: "—"
                        color: T.foreground
                        font.family: T.font_family
                        font.pixelSize: T.title_size
                        font.weight: T.weight_bold
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    Text {
                        text: "Disk usage"
                        color: T.foreground_subtle
                        font.family: T.font_family
                        font.pixelSize: T.caption_size
                        font.weight: T.weight_bold
                    }
                    Text {
                        text: "—"
                        color: T.foreground
                        font.family: T.font_family
                        font.pixelSize: T.title_size
                        font.weight: T.weight_bold
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: T.space_sm

                    StyledButton {
                        text: "Keep last 3"
                        variant: "secondary"
                    }
                    StyledButton {
                        text: "Clear cache"
                        variant: "danger"
                    }
                }
            }
        }

        PackageList {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
