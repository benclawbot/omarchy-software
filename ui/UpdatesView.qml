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
        RowLayout {
            Layout.fillWidth: true
            spacing: T.space_md

            ColumnLayout {
                spacing: T.space_xs
                Layout.fillWidth: true

                Text {
                    text: "Updates"
                    color: T.foreground
                    font.family: T.font_family
                    font.pixelSize: T.headline_size
                    font.weight: T.weight_bold
                }
                Text {
                    text: "Available upgrades for your system"
                    color: T.foreground_muted
                    font.family: T.font_family
                    font.pixelSize: T.small_size
                }
            }

            StyledButton {
                text: "Refresh"
                variant: "secondary"
            }
            StyledButton {
                text: "Update all"
                variant: "primary"
            }
        }

        PackageList {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
