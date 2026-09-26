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
                text: "Browse"
                color: T.foreground
                font.family: T.font_family
                font.pixelSize: T.headline_size
                font.weight: T.weight_bold
            }
            Text {
                text: "Search official repos and the AUR"
                color: T.foreground_muted
                font.family: T.font_family
                font.pixelSize: T.small_size
            }
        }

        // Search bar
        SearchBar {
            Layout.fillWidth: true
            onSearch: (query) => console.log("search:", query)
            onSourceChanged: (src) => console.log("source:", src)
        }

        // Results list
        PackageList {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
