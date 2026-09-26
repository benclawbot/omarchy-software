import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "Theme.js" as T

Rectangle {
    id: root

    property bool selected: false
    property bool hovered: hover.containsMouse
    property string name: ""
    property string description: ""
    property string version: ""
    property string source: "repo"   // repo | aur | cachyos
    property string repo: ""
    property bool installed: false
    property bool updateAvailable: false

    signal clicked()
    signal toggleSelection()

    implicitHeight: 64
    radius: T.radius_lg
    color: {
        if (selected)        return T.surface_strong
        if (hover.containsMouse) return T.surface_elevated
        return T.surface
    }
    border.width: selected ? 1 : (hover.containsMouse ? 1 : 0)
    border.color: selected ? T.accent : T.divider

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.clicked()
            root.toggleSelection()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: T.space_md
        anchors.rightMargin: T.space_md
        anchors.topMargin: T.space_sm
        anchors.bottomMargin: T.space_sm
        spacing: T.space_md

        // Selection checkbox indicator
        Rectangle {
            width: 18; height: 18
            radius: T.radius_sm
            color: root.selected ? T.accent : "transparent"
            border.width: 1
            border.color: root.selected ? T.accent : T.foreground_subtle

            Text {
                anchors.centerIn: parent
                text: "✓"
                color: T.background
                font.family: T.font_family
                font.pixelSize: T.caption_size
                font.weight: T.weight_bold
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
                spacing: T.space_sm

                Text {
                    text: root.name
                    color: T.foreground
                    font.family: T.font_family
                    font.pixelSize: T.body_size
                    font.weight: T.weight_bold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.preferredWidth: 100
                }

                Text {
                    visible: root.version.length > 0
                    text: root.version
                    color: T.foreground_dim
                    font.family: T.font_family
                    font.pixelSize: T.small_size
                }
            }

            Text {
                text: root.description
                color: T.foreground_muted
                font.family: T.font_family
                font.pixelSize: T.small_size
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.maximumLineCount: 1
                wrapMode: Text.NoWrap
                Layout.preferredWidth: 100
            }
        }

        // Right-side status pill
        Rectangle {
            visible: root.installed || root.updateAvailable
            implicitWidth: statusLabel.implicitWidth + 12
            implicitHeight: 20
            radius: T.radius_sm
            color: root.updateAvailable ? Qt.rgba(0.949, 0.886, 0.686, 0.18)
                                          : Qt.rgba(0.651, 0.890, 0.631, 0.18)
            Text {
                id: statusLabel
                anchors.centerIn: parent
                text: root.updateAvailable ? "Update available" : "Installed"
                color: root.updateAvailable ? T.warning : T.success
                font.family: T.font_family
                font.pixelSize: T.caption_size
                font.weight: T.weight_bold
            }
        }
    }
}
