import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    property string category: "all"
    property string repository: ""
    property string searchText: ""

    function runSearch(query) {
        searchText = query
        if (bridge.search)
            bridge.search(query.trim(), searchBar.source, repository, category)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: theme.space_xl
        spacing: theme.space_lg

        // Page header
        ColumnLayout {
            Layout.fillWidth: true
            spacing: theme.space_sm

            Text {
                text: "Install"
                color: theme.foreground
                font.family: theme.font_family
                font.pixelSize: theme.title_size
                font.weight: theme.weight_bold
            }
            Text {
                text: "Search names, descriptions, and versions across enabled sources"
                color: theme.foreground_muted
                font.family: theme.font_family
                font.pixelSize: theme.body_size
            }
        }

        // Search bar
        SearchBar {
            id: searchBar
            Layout.fillWidth: true
            onQueryChanged: (query) => searchTimer.restart()
            onFilterChanged: (src) => {
                if (src === "aur") {
                    root.repository = ""
                    root.category = "all"
                }
                root.runSearch(searchBar.text)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: theme.space_md

            Text {
                text: "REPOSITORY"
                color: theme.foreground_subtle
                font.family: theme.font_family
                font.pixelSize: theme.caption_size
                font.weight: theme.weight_bold
            }
            FilterComboBox {
                id: repositoryFilter
                Layout.preferredWidth: 176
                model: ["All repositories"].concat(bridge.repositories || [])
                currentIndex: Math.max(0, model.indexOf(root.repository || "All repositories"))
                enabled: searchBar.source !== "aur"
                onActivated: {
                    root.repository = currentIndex === 0 ? "" : currentText
                    root.category = "all"
                    root.runSearch(searchBar.text)
                }
            }

            Text {
                text: "CATEGORY"
                color: theme.foreground_subtle
                font.family: theme.font_family
                font.pixelSize: theme.caption_size
                font.weight: theme.weight_bold
            }
            FilterComboBox {
                id: categoryFilter
                Layout.preferredWidth: 190
                model: ["All categories"].concat(bridge.categories || [])
                currentIndex: Math.max(0, model.indexOf(root.category === "all" ? "All categories" : root.category))
                enabled: searchBar.source !== "aur"
                onActivated: {
                    root.category = currentIndex === 0 ? "all" : currentText
                    root.runSearch(searchBar.text)
                }
            }
        }

        Text {
            text: bridge.status || "Search package names, descriptions, and versions"
            color: theme.foreground_dim
            font.family: theme.font_family
            font.pixelSize: theme.small_size
            Layout.fillWidth: true
        }

        // Results list
        PackageList {
            id: packageList
            model: bridge.rows
            loading: bridge.busy || false
            showHeader: false
            loadingTitle: "Loading packages"
            emptyTitle: bridge.busy ? "Loading packages" : (searchBar.text.length > 0 ? "No matching packages" : "Browse repository packages")
            emptyMessage: searchBar.source === "aur" && searchBar.text.length === 0
                ? "Enter a package name to search the AUR."
                : searchBar.text.length > 0
                    ? "Try another name or change the repository or category filters."
                    : "Search package names, descriptions, and versions across your enabled repositories."
            emptySymbol: "⌕"
            Layout.fillWidth: true
            Layout.fillHeight: true
            onPackageDoubleClicked: function(name, source) {
                if (source === "aur") return
                bridge.queueInstall([name], [source])
            }
        }
    }

    // Bring the user back to the top of the search results whenever a
    // package action completes on this view — so the package they just
    // installed (or the refresh after an update) is visible at once.
    Connections {
        target: bridge
        ignoreUnknownSignals: true
        function onOperationFinished(action, packages, message) {
            if ((action === "install" || action === "update") && packageList)
                packageList.scrollToTop()
        }
    }

    Timer { id: searchTimer; interval: 300; repeat: false; onTriggered: root.runSearch(searchBar.text) }
}
