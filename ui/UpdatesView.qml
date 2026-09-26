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
        RowLayout {
            Layout.fillWidth: true
            spacing: theme.space_md

            ColumnLayout {
                spacing: theme.space_sm
                Layout.fillWidth: true

                Text {
                    text: "Updates"
                    color: theme.foreground
                    font.family: theme.font_family
                    font.pixelSize: theme.title_size
                    font.weight: theme.weight_bold
                }
                Text {
                    text: "Available upgrades for your system"
                    color: theme.foreground_muted
                    font.family: theme.font_family
                    font.pixelSize: theme.body_size
                }
            }

            StyledButton {
                text: "Refresh"
                variant: "secondary"
                onClicked: bridge.refresh()
            }
            StyledButton {
                text: "Update all"
                variant: "primary"
                enabled: bridge.rows && bridge.rows.count > 0 && !bridge.busy
                onClicked: bridge.previewUpdates()
            }
        }

        PackageList {
            model: bridge.rows
            loading: bridge.busy || false
            emptySymbol: "✓"
            emptyTitle: bridge.busy ? "Checking for updates" : "You're up to date"
            emptyMessage: bridge.busy
                ? "Comparing installed packages with enabled repositories."
                : "No package updates are available."
            emptyAccent: theme.success
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
