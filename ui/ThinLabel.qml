import QtQuick 2.15
import QtQuick.Layouts 1.15

Text {
    property bool isHeader: false
    property int flex: 1

    color: isHeader ? theme.dark_foreground : theme.foreground
    font.family: "monospace"
    font.pixelSize: isHeader ? 11 : 12
    font.weight: isHeader ? Font.Bold : Font.Normal
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    Layout.preferredWidth: 0
    Layout.fillWidth: true
}
