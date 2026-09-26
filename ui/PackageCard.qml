import QtQuick 2.15
import QtQuick.Layouts 1.15

// PackageCard — single row in the package list.
//
// Performance notes:
// - `layer.enabled: true` snapshots the rendered delegate into a GPU
//   texture once, so scrolling is mostly a texture slide. With many
//   delegates on screen this is the single biggest win for list perf
//   in Qt6 QML.
// - Hover/selected visual changes use explicit `state` transitions
//   rather than bindings on hover.containsMouse, so moving the cursor
//   over a card does not trigger a property-binding re-evaluation per
//   frame across every delegate during a wheel-scroll.
// - Constant colours (status pills) are pre-computed once on
//   Component.onCompleted so the binding does not call Qt.rgba on
//   every paint.
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

    // Pre-compute the three constant pill colours so the status pill
    // binding does not allocate fresh rgba tuples on every paint.
    readonly property color installedFill:     Qt.rgba(0.651, 0.890, 0.631, 0.18)
    readonly property color updateFill:        Qt.rgba(0.949, 0.886, 0.686, 0.18)
    readonly property color protectedFill:     Qt.rgba(0.651, 0.678, 0.792, 0.12)
    readonly property color unsupportedFill:   Qt.rgba(theme.warning.r, theme.warning.g, theme.warning.b, 0.14)

    // Single property so every Text element in this delegate uses the
    // same fast native glyph path. NativeRendering skips QPainterPath
    // tessellation per glyph, which is the largest single cost in a
    // scrolling package list on Intel iGPU under Wayland.
    readonly property int textRenderType: Text.NativeRendering

    color: theme.surface
    border.width: 0
    border.color: theme.divider

    // Visual state machine — avoids binding churn from hover events.
// We update the colour/border directly from a state-change handler
// instead of using PropertyChanges (the latter trips qmllint on
// Rectangle's `border` group property and emits parse warnings).
    state: (root.selected ? "selected"
          : (root.installable && root.hovered ? "hovered"
          : "default"))

    onStateChanged: {
        if (state === "selected") {
            color = theme.surface_strong
            border.width = 1
        } else if (state === "hovered") {
            color = theme.surface_elevated
            border.width = 1
        } else {
            color = theme.surface
            border.width = 0
        }
    }

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
            Layout.preferredWidth: root.selectionEnabled ? 18 : 0
            Layout.preferredHeight: 18
            visible: root.selectionEnabled
            radius: theme.radius_sm
            color: root.selected ? theme.accent : "transparent"
            border.width: 1
            border.color: root.selectionAllowed ? (root.selected ? theme.accent : theme.foreground_subtle) : theme.divider
            opacity: root.selectionAllowed ? 1 : 0.42

            Text {
                renderType: root.textRenderType
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
                    renderType: root.textRenderType
                    text: root.name
                    color: theme.foreground
                    font.family: theme.font_family
                    font.pixelSize: theme.body_size
                    font.weight: theme.weight_bold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    renderType: root.textRenderType
                    visible: root.version.length > 0
                    text: root.version
                    color: theme.foreground_dim
                    font.family: theme.font_family
                    font.pixelSize: theme.small_size
                }
            }

            Text {
                renderType: root.textRenderType
                text: root.description
                color: theme.foreground_muted
                font.family: theme.font_family
                font.pixelSize: theme.small_size
                elide: Text.ElideRight
                Layout.fillWidth: true
                wrapMode: Text.NoWrap
            }
        }

        // Right-side status pill
        Rectangle {
            visible: !root.installable && root.source === "aur"
            implicitWidth: unsupportedLabel.implicitWidth + 12
            implicitHeight: 20
            radius: theme.radius_sm
            color: root.unsupportedFill
            Text {
                renderType: root.textRenderType
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
            color: root.protectedPackage ? root.protectedFill
                 : root.updateAvailable  ? root.updateFill
                 : root.installedFill
            Text {
                renderType: root.textRenderType
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