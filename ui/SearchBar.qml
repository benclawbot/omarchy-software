import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    color: "transparent"
    implicitHeight: theme.input_height

    property alias text: input.text
    property alias placeholder: input.placeholderText
    property string source: "all"  // all sources | repositories | AUR

    signal queryChanged(string query)
    signal filterChanged(string filter)

    onSourceChanged: filterChanged(source)

    RowLayout {
        anchors.fill: parent
        spacing: theme.space_md

        // Search input
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: theme.input_height
            radius: theme.radius_md
            color: theme.surface
            border.width: input.activeFocus ? 1 : 0
            border.color: theme.accent

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: theme.space_md
                anchors.rightMargin: theme.space_md
                spacing: theme.space_sm

                Text {
                    text: "⌕"
                    color: theme.foreground_dim
                    font.family: theme.font_family
                    font.pixelSize: theme.body_size
                }

                TextField {
                    id: input
                    Layout.fillWidth: true
                    placeholderText: "Search packages…"
                    placeholderTextColor: theme.foreground_subtle
                    background: Item {}  // strip default
                    color: theme.foreground
                    font.family: theme.font_family
                    font.pixelSize: theme.body_size
                    selectByMouse: true
                    onAccepted: root.queryChanged(text)
                    onTextChanged: root.queryChanged(text)

                    Keys.onEscapePressed: text = ""
                }

                Text {
                    visible: input.text.length > 0
                    text: "✕"
                    color: theme.foreground_dim
                    font.family: theme.font_family
                    font.pixelSize: theme.body_size
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
            onClicked: root.source = "all"
        }
        StyledChip {
            text: "Repos"
            accent: theme.source_repo
            selected: root.source === "repo"
            onClicked: root.source = "repo"
        }
        StyledChip {
            text: "AUR"
            accent: theme.source_aur
            selected: root.source === "aur"
            onClicked: root.source = "aur"
        }
    }
}
