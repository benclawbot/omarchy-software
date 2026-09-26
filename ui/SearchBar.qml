import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "Theme.js" as T

Rectangle {
    id: root
    color: "transparent"
    implicitHeight: T.input_height

    property alias text: input.text
    property alias placeholder: input.placeholderText
    property string source: "all"  // "all" | "repo" | "aur" | "cachyos"

    signal search(string query)
    signal sourceChanged(string source)

    RowLayout {
        anchors.fill: parent
        spacing: T.space_md

        // Search input
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: T.input_height
            radius: T.radius_md
            color: T.surface
            border.width: input.activeFocus ? 1 : 0
            border.color: T.accent

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: T.space_md
                anchors.rightMargin: T.space_md
                spacing: T.space_sm

                Text {
                    text: "⌕"
                    color: T.foreground_dim
                    font.family: T.font_family
                    font.pixelSize: T.body_size
                }

                TextField {
                    id: input
                    Layout.fillWidth: true
                    placeholderText: "Search packages…"
                    placeholderTextColor: T.foreground_subtle
                    background: Item {}  // strip default
                    color: T.foreground
                    font.family: T.font_family
                    font.pixelSize: T.body_size
                    selectByMouse: true
                    onAccepted: root.search(text)

                    Keys.onEscapePressed: text = ""
                }

                Text {
                    visible: text.length > 0
                    text: "✕"
                    color: T.foreground_dim
                    font.family: T.font_family
                    font.pixelSize: T.body_size
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: input.text = ""
                    }
                }
            }
        }

        // Source filter chips
        StyledChip {
            text: "All"
            selected: root.source === "all"
            onClicked: { root.source = "all"; root.sourceChanged("all") }
        }
        StyledChip {
            text: "Repo"
            accent: T.source_repo
            selected: root.source === "repo"
            onClicked: { root.source = "repo"; root.sourceChanged("repo") }
        }
        StyledChip {
            text: "AUR"
            accent: T.source_aur
            selected: root.source === "aur"
            onClicked: { root.source = "aur"; root.sourceChanged("aur") }
        }
        StyledChip {
            text: "CachyOS"
            accent: T.source_cachyos
            selected: root.source === "cachyos"
            onClicked: { root.source = "cachyos"; root.sourceChanged("cachyos") }
        }
    }
}
