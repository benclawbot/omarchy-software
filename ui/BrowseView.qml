import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    color: "transparent"

    // Reuse the shared PackageList
    PackageList {
        id: browseList
        anchors.fill: parent
    }
}
