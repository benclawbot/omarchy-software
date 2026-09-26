import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    property string filter: "all"  // all | explicit | dependency | orphan
    property var selectedNames: []

    function togglePackage(name) {
        var next = selectedNames.slice()
        var index = next.indexOf(name)
        if (index < 0) next.push(name); else next.splice(index, 1)
        selectedNames = next
        if (bridge.setSelected) bridge.setSelected(next)
    }

    function refreshPackages() { if (bridge.loadInstalled) bridge.loadInstalled(filter) }

    onFilterChanged: {
        selectedNames = []
        if (bridge.setSelected) bridge.setSelected([])
        if (bridge.loadInstalled) bridge.loadInstalled(filter)
    }

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
                    text: "Remove"
                    color: theme.foreground
                    font.family: theme.font_family
                    font.pixelSize: theme.title_size
                    font.weight: theme.weight_bold
                }
                Text {
                    text: "Manage packages currently on this system"
                    color: theme.foreground_muted
                    font.family: theme.font_family
                    font.pixelSize: theme.body_size
                }
            }

            // Filter chips
            Row {
                spacing: theme.space_xs
                StyledChip {
                    text: "All"
                    selected: root.filter === "all"
                    onClicked: { if (root.filter !== "all") root.filter = "all"; else root.refreshPackages() }
                }
                StyledChip {
                    text: "Explicit"
                    selected: root.filter === "explicit"
                    onClicked: { if (root.filter !== "explicit") root.filter = "explicit"; else root.refreshPackages() }
                }
                StyledChip {
                    text: "Dependencies"
                    selected: root.filter === "dependency"
                    onClicked: { if (root.filter !== "dependency") root.filter = "dependency"; else root.refreshPackages() }
                }
                StyledChip {
                    text: "Orphans"
                    accent: theme.warning
                    selected: root.filter === "orphan"
                    onClicked: { if (root.filter !== "orphan") root.filter = "orphan"; else root.refreshPackages() }
                }
            }
        }

        PackageList {
            model: bridge.rows
            loading: bridge.busy || false
            selectable: true
            selectedNames: root.selectedNames
            showActions: true
            installedOnly: true
            actionLabel: selectedNames.length + " selected · removal is reviewed before applying"
            onPackageToggled: (name) => root.togglePackage(name)
            onActionClicked: if (bridge.stageSelectedRemoval) bridge.stageSelectedRemoval()
            loadingTitle: "Loading installed packages"
            emptySymbol: root.filter === "orphan" ? "✓" : "⌕"
            emptyTitle: root.filter === "orphan" ? "No orphaned packages" : "No packages to show"
            emptyMessage: root.filter === "orphan"
                ? "All installed packages are in use."
                : "Try another filter to change the list."
            emptyAccent: root.filter === "orphan" ? theme.success : theme.accent
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

}
