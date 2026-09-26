import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "Theme.js" as T

Item {
    id: root

    property string filter: "all"  // all | explicit | dependency | orphan

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
                    text: "Installed"
                    color: T.foreground
                    font.family: T.font_family
                    font.pixelSize: T.headline_size
                    font.weight: T.weight_bold
                }
                Text {
                    text: "Manage packages currently on this system"
                    color: T.foreground_muted
                    font.family: T.font_family
                    font.pixelSize: T.small_size
                }
            }

            // Filter chips
            Row {
                spacing: T.space_xs
                StyledChip {
                    text: "All"
                    selected: root.filter === "all"
                    onClicked: root.filter = "all"
                }
                StyledChip {
                    text: "Explicit"
                    selected: root.filter === "explicit"
                    onClicked: root.filter = "explicit"
                }
                StyledChip {
                    text: "Dependencies"
                    selected: root.filter === "dependency"
                    onClicked: root.filter = "dependency"
                }
                StyledChip {
                    text: "Orphans"
                    accent: T.warning
                    selected: root.filter === "orphan"
                    onClicked: root.filter = "orphan"
                }
            }
        }

        PackageList {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
