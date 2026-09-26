import QtQuick 2.15
import QtQuick.Controls 2.15

ComboBox {
    id: root

    implicitHeight: theme.input_height

    background: Rectangle {
        radius: theme.radius_md
        color: root.enabled ? theme.surface : theme.background
        border.width: root.activeFocus ? 1 : 0
        border.color: theme.accent
    }

    contentItem: Text {
        leftPadding: theme.space_md
        rightPadding: theme.space_xl
        text: root.displayText
        color: root.enabled ? theme.foreground : theme.foreground_dim
        font.family: theme.font_family
        font.pixelSize: theme.small_size
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        anchors.right: parent.right
        anchors.rightMargin: theme.space_sm
        anchors.verticalCenter: parent.verticalCenter
        text: "⌄"
        color: theme.foreground_muted
        font.pixelSize: theme.body_size
    }

    delegate: ItemDelegate {
        width: root.width
        contentItem: Text {
            text: modelData
            color: theme.foreground
            font.family: theme.font_family
            font.pixelSize: theme.small_size
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            color: highlighted ? theme.surface_strong : theme.surface
        }
    }

    popup: Popup {
        y: root.height - 1
        width: root.width
        implicitHeight: Math.min(contentItem.implicitHeight, 320)
        padding: 4

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator { }
        }

        background: Rectangle {
            color: theme.surface
            border.width: 1
            border.color: theme.divider
            radius: theme.radius_md
        }
    }
}
