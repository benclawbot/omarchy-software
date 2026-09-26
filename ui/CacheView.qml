import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: theme.space_xl
        spacing: theme.space_lg

        // Page header
        ColumnLayout {
            Layout.fillWidth: true
            spacing: theme.space_sm

            Text {
                text: "Package cache"
                color: theme.foreground
                font.family: theme.font_family
                font.pixelSize: theme.title_size
                font.weight: theme.weight_bold
            }
            Text {
                text: "Downloaded .pkg.tar files kept by pacman"
                color: theme.foreground_muted
                font.family: theme.font_family
                font.pixelSize: theme.body_size
            }
        }

        // Stats card
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 96
            radius: theme.radius_lg
            color: theme.surface
            border.width: 1
            border.color: theme.divider

            RowLayout {
                anchors.fill: parent
                anchors.margins: theme.space_lg
                spacing: theme.space_xl

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    Text {
                        text: "Cached packages"
                        color: theme.foreground_muted
                        font.family: theme.font_family
                        font.pixelSize: theme.caption_size
                        font.weight: theme.weight_bold
                    }
                    Text {
                        text: "—"
                        color: theme.foreground
                        font.family: theme.font_family
                        font.pixelSize: theme.title_size
                        font.weight: theme.weight_bold
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    Text {
                        text: "Disk usage"
                        color: theme.foreground_muted
                        font.family: theme.font_family
                        font.pixelSize: theme.caption_size
                        font.weight: theme.weight_bold
                    }
                    Text {
                        text: "—"
                        color: theme.foreground
                        font.family: theme.font_family
                        font.pixelSize: theme.title_size
                        font.weight: theme.weight_bold
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: theme.space_sm

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
            emptySymbol: "✓"
            emptyTitle: "No cached packages"
            emptyMessage: "Your package cache is empty."
            emptyAccent: theme.success
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
