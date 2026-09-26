import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    property var model: []
    property var selectedNames: []
    property bool selectable: false
    property bool showActions: false
    property bool showHeader: true
    property string actionLabel: ""
    property string actionText: "Remove selected"
    property bool installedOnly: false
    property bool loading: false
    property string emptySymbol: "⌕"
    property string emptyTitle: "No packages found"
    property string emptyMessage: "Try another search or change the filters"
    property color emptyAccent: theme.accent
    property string loadingTitle: "Searching packages"
    property string loadingMessage: "Results will appear here"

    signal packageClicked(string name)
    signal packageDoubleClicked(string name, string source)
    signal packageToggled(string name)
    signal actionClicked()

    function itemCount() {
        if (!root.model) return 0
        if (typeof root.model.count === "number") return root.model.count
        if (typeof root.model.length === "number") return root.model.length
        return 0
    }

    // Bring the list back to the top after a refresh (e.g. after an
    // install commits — the user wants to see the package they just
    // installed now sitting at the top of the search results).
    function scrollToTop() {
        if (listView) listView.positionViewAtBeginning()
    }

    // Column header
    Rectangle {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 36
        visible: root.showHeader
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: theme.space_md
            anchors.rightMargin: theme.space_md
            spacing: theme.space_md

            // Checkbox column (matches card checkbox width)
            Item {
                width: root.selectable ? 18 : 0
                Layout.preferredWidth: width
            }

            // Source column
            Text {
                text: "SOURCE"
                color: theme.foreground_subtle
                font.family: theme.font_family
                font.pixelSize: theme.caption_size
                font.weight: theme.weight_bold
                Layout.preferredWidth: 60
            }

            // Name column
            Text {
                text: "PACKAGE"
                color: theme.foreground_subtle
                font.family: theme.font_family
                font.pixelSize: theme.caption_size
                font.weight: theme.weight_bold
                Layout.fillWidth: true
            }

            // Version column
            Text {
                text: "VERSION"
                color: theme.foreground_subtle
                font.family: theme.font_family
                font.pixelSize: theme.caption_size
                font.weight: theme.weight_bold
                Layout.preferredWidth: 110
                horizontalAlignment: Text.AlignRight
            }

            // Status column
            Text {
                text: "STATUS"
                color: theme.foreground_subtle
                font.family: theme.font_family
                font.pixelSize: theme.caption_size
                font.weight: theme.weight_bold
                Layout.preferredWidth: 120
                horizontalAlignment: Text.AlignRight
            }
        }

        // Bottom border
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 1
            color: theme.divider
        }
    }

    RowLayout {
        id: actionRow
        anchors {
            top: root.showHeader ? header.bottom : parent.top
            left: parent.left
            right: parent.right
        }
        anchors.leftMargin: theme.space_md
        anchors.rightMargin: theme.space_md
        height: 42
        visible: root.showActions
        spacing: theme.space_sm
        Text {
            text: root.actionLabel
            color: theme.foreground_muted
            font.family: theme.font_family
            font.pixelSize: theme.small_size
            Layout.fillWidth: true
        }
        StyledButton {
            text: root.actionText
            variant: "danger"
            enabled: root.selectedNames.length > 0
            onClicked: root.actionClicked()
        }
    }

    // ListView of packages
    ListView {
        id: listView
        anchors {
            top: root.showActions ? actionRow.bottom : (root.showHeader ? header.bottom : parent.top)
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        anchors.topMargin: root.showHeader ? theme.space_xs : 0
        clip: true
        spacing: theme.space_sm
        model: root.model

        // ── Smooth scrolling tuning ────────────────────────────────────────
        // Render at integer pixel offsets to avoid sub-pixel blur while
        // scrolling, and pre-instantiate delegates one viewport above and
        // below the visible region so items are already laid out when they
        // come into view (no first-frame hitch on long lists).
        pixelAligned: true
        cacheBuffer: Math.max(listView.height * 2, 800)
        reuseItems: true
        // Slightly longer inertia + faster flick peaks feels closer to a
        // native GTK/KDE panel than the Qt default.
        flickDeceleration: 1500
        maximumFlickVelocity: 5500
        // Stop at bounds rather than rubber-banding; rubber-banding on a
        // package manager panel feels jittery under Wayland.
        boundsBehavior: Flickable.StopAtBounds
        // Keyboard scroll stepping. Mouse wheels are always handled by
        // Flickable in Qt 6.
        keyNavigationEnabled: true
        keyNavigationWraps: false

        delegate: PackageCard {
            width: listView.width - 2 * theme.space_md
            x: theme.space_md
            name: modelData.name || ""
            description: modelData.description || ""
            version: modelData.version || ""
            source: modelData.source || "repo"
            repo: modelData.repo || ""
            installed: modelData.installed || false
            updateAvailable: modelData.update_available || modelData.updateAvailable || false
            protectedPackage: modelData.protected || false
            installable: modelData.source !== "aur"
            selectionEnabled: root.selectable
            selectionAllowed: !protectedPackage
            selected: root.selectedNames.indexOf(modelData.name) !== -1
            onClicked: root.packageClicked(modelData.name)
            onDoubleClicked: root.packageDoubleClicked(modelData.name, modelData.source || "repo")
            onToggleSelection: if (root.selectable && selectionAllowed) root.packageToggled(modelData.name)
        }

        // Empty state
        Rectangle {
            anchors.centerIn: parent
            visible: root.itemCount() === 0
            width: Math.min(parent.width - 32, 360); height: 150
            radius: theme.radius_lg
            color: theme.surface
            border.width: 1
            border.color: theme.divider

            ColumnLayout {
                anchors.centerIn: parent
                spacing: theme.space_sm

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 44
                    height: 44
                    radius: 22
                    color: Qt.rgba(root.emptyAccent.r, root.emptyAccent.g, root.emptyAccent.b, 0.14)

                    Text {
                        anchors.centerIn: parent
                        text: root.loading ? "…" : root.emptySymbol
                        color: root.emptyAccent
                        font.family: theme.font_family
                        font.pixelSize: 24
                        font.weight: theme.weight_medium
                    }
                }
                Text {
                    text: root.loading ? root.loadingTitle : root.emptyTitle
                    color: theme.foreground
                    font.family: theme.font_family
                    font.pixelSize: theme.subhead_size
                    font.weight: theme.weight_medium
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: root.loading ? root.loadingMessage : root.emptyMessage
                    color: theme.foreground_muted
                    font.family: theme.font_family
                    font.pixelSize: theme.small_size
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: 300
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }

        ScrollBar.vertical: StyledScrollBar { policy: ScrollBar.AsNeeded }
    }
}
