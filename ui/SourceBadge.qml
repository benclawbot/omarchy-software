import QtQuick 2.15

// SourceBadge — coloured pill showing package source.
//   source = "repo" | "aur" | "cachyos"
Rectangle {
    property string source: "repo"
    property string repo: ""

    readonly property bool cachyRepo: source === "cachyos" || repo.toLowerCase().startsWith("cachyos")

    implicitWidth: label.implicitWidth + 14
    implicitHeight: theme.badge_height
    radius: theme.radius_sm

    color: {
        if (source === "aur")     return Qt.rgba(0.796, 0.651, 0.969, 0.15)  // mauve @ 15%
        if (cachyRepo) return Qt.rgba(0.580, 0.886, 0.835, 0.15)  // teal @ 15%
        return Qt.rgba(0.537, 0.706, 0.980, 0.15)                            // blue @ 15%
    }
    border.width: 1
    border.color: {
        if (source === "aur")     return theme.source_aur
        if (cachyRepo) return theme.source_cachyos
        return theme.source_repo
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: {
            if (source === "aur")     return "AUR"
            if (cachyRepo) return "CachyOS"
            return repo ? repo.charAt(0).toUpperCase() + repo.slice(1) : "Repo"
        }
        color: {
            if (source === "aur")     return theme.source_aur
            if (cachyRepo) return theme.source_cachyos
            return theme.source_repo
        }
        font.family: theme.font_family
        font.pixelSize: theme.caption_size
        font.weight: theme.weight_bold
    }
}
