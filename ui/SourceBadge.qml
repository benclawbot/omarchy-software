import QtQuick 2.15
import "Theme.js" as T

// SourceBadge — coloured pill showing package source.
//   source = "repo" | "aur" | "cachyos"
Rectangle {
    property string source: "repo"
    property string repo: ""

    implicitWidth: label.implicitWidth + 14
    implicitHeight: T.badge_height
    radius: T.radius_sm

    color: {
        if (source === "aur")     return Qt.rgba(0.796, 0.651, 0.969, 0.15)  // mauve @ 15%
        if (source === "cachyos") return Qt.rgba(0.580, 0.886, 0.835, 0.15)  // teal @ 15%
        return Qt.rgba(0.537, 0.706, 0.980, 0.15)                            // blue @ 15%
    }
    border.width: 1
    border.color: {
        if (source === "aur")     return T.source_aur
        if (source === "cachyos") return T.source_cachyos
        return T.source_repo
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: {
            if (source === "aur")     return "AUR"
            if (source === "cachyos") return "CachyOS"
            return repo ? repo.charAt(0).toUpperCase() + repo.slice(1, 3) : "Core"
        }
        color: {
            if (source === "aur")     return T.source_aur
            if (source === "cachyos") return T.source_cachyos
            return T.source_repo
        }
        font.family: T.font_family
        font.pixelSize: T.caption_size
        font.weight: T.weight_bold
    }
}
