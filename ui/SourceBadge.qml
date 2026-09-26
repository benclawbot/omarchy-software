import QtQuick 2.15

Rectangle {
    property string source: "repo"
    property string repo: ""

    radius: 4
    height: 18
    width: label.width + 10

    color: {
        if (source === "aur")    return "#3d2e52" // dark magenta bg
        if (source === "cachyos") return "#1e3a36" // dark cyan bg
        return "#1e2d4a"                     // dark blue bg
    }

    border.width: 1
    border.color: {
        if (source === "aur")    return "#cba6f7"
        if (source === "cachyos") return "#94e2d5"
        return "#89b4fa"
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: {
            if (source === "aur")    return "AUR"
            if (source === "cachyos") return "CachyOS"
            return repo ? repo.charAt(0).toUpperCase() + repo.slice(1, 3) : "Core"
        }
        color: {
            if (source === "aur")    return "#cba6f7"
            if (source === "cachyos") return "#94e2d5"
            return "#89b4fa"
        }
        font.family: "monospace"; font.pixelSize: 10; font.weight: Font.Bold
    }
}
