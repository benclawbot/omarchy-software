import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    property bool selected: false
    property bool hovered: hover.containsMouse
    property bool selectionEnabled: false
    property bool selectionAllowed: true
    property string name: ""
    property string description: ""
    property string version: ""
    property string source: "repo"   // repo | aur | cachyos
    property string repo: ""
    property bool installed: false
    property bool updateAvailable: false
    property bool protectedPackage: false
    property bool installable: true

    signal clicked()
    signal doubleClicked()
    signal toggleSelection()

    implicitHeight: 72
    radius: theme.radius_lg
    color: {
        if (selected)        return theme.surface_strong
        if (hover.containsMouse && root.installable) return theme.surface_elevated
        return theme.surface
    }
    border.width: selected ? 1 : (hover.containsMouse ? 1 : 0)
    border.color: selected ? theme.accent : theme.divider

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: (root.selectionEnabled && root.selectionAllowed) || root.installable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onDoubleClicked: if (root.installable && !root.selectionEnabled) root.doubleClicked()
        onClicked: {
            root.clicked()
            if (root.selectionEnabled && root.selectionAllowed)
                root.toggleSelection()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: theme.space_md
        anchors.rightMargin: theme.space_md
        anchors.topMargin: theme.space_sm
        anchors.bottomMargin: theme.space_sm
        spacing: theme.space_md

        // Selection checkbox indicator
        Rectangle {
            width: root.selectionEnabled ? 18 : 0
            height: 18
            visible: root.selectionEnabled
            radius: theme.radius_sm
            color: root.selected ? theme.accent : "transparent"
            border.width: 1
            border.color: root.selectionAllowed ? (root.selected ? theme.accent : theme.foreground_subtle) : theme.divider
            opacity: root.selectionAllowed ? 1 : 0.42

            Text {
                anchors.centerIn: parent
                text: "✓"
                color: theme.background
                font.family: theme.font_family
                font.pixelSize: theme.caption_size
                font.weight: theme.weight_bold
                visible: root.selected
            }
        }

        // Source badge
        SourceBadge {
            source: root.source
            repo: root.repo
        }

        // Name + description
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                spacing: theme.space_sm

                Text {
                    text: root.name
                    color: theme.foreground
                    font.family: theme.font_family
                    font.pixelSize: theme.body_size
                    font.weight: theme.weight_bold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.preferredWidth: 100
                }

                Text {
                    visible: root.version.length > 0
                    text: root.version
                    color: theme.foreground_dim
                    font.family: theme.font_family
                    font.pixelSize: theme.small_size
                }
            }

            Text {
                text: root.description
                color: theme.foreground_muted
                font.family: theme.font_family
                font.pixelSize: theme.small_size
                elide: Text.ElideRight
                Layout.fillWidth: true
                wrapMode: Text.NoWrap
                Layout.preferredWidth: 100
            }
        }

        // Right-side status pill
        Rectangle {
            visible: !root.installable && root.source === "aur"
            implicitWidth: unsupportedLabel.implicitWidth + 12
            implicitHeight: 20
            radius: theme.radius_sm
            color: Qt.rgba(theme.warning.r, theme.warning.g, theme.warning.b, 0.14)
            Text {
                id: unsupportedLabel
                anchors.centerIn: parent
                text: "AUR unavailable"
                color: theme.warning
                font.family: theme.font_family
                font.pixelSize: theme.caption_size
                font.weight: theme.weight_bold
            }
        }
        Rectangle {
            visible: root.installed || root.updateAvailable || root.protectedPackage
            implicitWidth: statusLabel.implicitWidth + 12
            implicitHeight: 20
            radius: theme.radius_sm
            color: root.protectedPackage ? Qt.rgba(0.651, 0.678, 0.792, 0.12)
                  : root.updateAvailable ? Qt.rgba(0.949, 0.886, 0.686, 0.18)
                  : Qt.rgba(0.651, 0.890, 0.631, 0.18)
            Text {
                id: statusLabel
                anchors.centerIn: parent
                text: root.protectedPackage ? "Protected" : (root.updateAvailable ? "Update available" : "Installed")
                color: root.protectedPackage ? theme.foreground_dim : (root.updateAvailable ? theme.warning : theme.success)
                font.family: theme.font_family
                font.pixelSize: theme.caption_size
                font.weight: theme.weight_bold
            }
        }
    }
}
