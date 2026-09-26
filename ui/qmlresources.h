#pragma once

#include <QString>

inline const QString& mainQmlUrl() {
    static const QString url = QStringLiteral("qrc:/ui/Main.qml");
    return url;
}
