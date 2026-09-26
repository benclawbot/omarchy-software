#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QVariantMap>
#include <cstdio>

namespace {
QVariantMap testTheme() {
    const QString color = QStringLiteral("#1e1e2e");
    QVariantMap theme;
    for (const char* key : {"background", "dark_background", "darker_background",
                            "lighter_background", "foreground", "dark_foreground",
                            "light_foreground", "bright_foreground", "accent", "selection",
                            "muted", "source_repo", "source_aur", "source_cachyos", "green",
                            "yellow", "orange", "red", "cyan", "blue", "magenta", "brown",
                            "install", "update", "remove", "warning", "glass",
                            "glass_border", "fontFamily"})
        theme.insert(QString::fromLatin1(key), color);
    theme.insert(QStringLiteral("radius"), 12);
    theme.insert(QStringLiteral("fontSize"), 13);
    theme.insert(QStringLiteral("mode"), QStringLiteral("dark"));
    return theme;
}
}

int main(int argc, char* argv[]) {
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), testTheme());
    engine.rootContext()->setContextProperty(QStringLiteral("bridge"), &engine);
    engine.rootContext()->setContextProperty(QStringLiteral("mainWindow"), nullptr);

    QStringList errors;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, &engine,
                     [&errors](const QList<QQmlError>& warnings) {
        for (const QQmlError& warning : warnings)
            errors.append(warning.toString());
    });

    engine.load(QUrl(QStringLiteral("qrc:/qml-smoke/ui/Main.qml")));
    if (engine.rootObjects().size() != 1) {
        std::fprintf(stderr, "Main.qml did not produce exactly one root object\n");
        for (const QString& error : errors)
            std::fprintf(stderr, "%s\n", qPrintable(error));
        return 1;
    }

    auto* window = qobject_cast<QQuickWindow*>(engine.rootObjects().constFirst());
    if (!window || !window->isVisible()) {
        std::fprintf(stderr, "Main.qml root is not a visible QQuickWindow\n");
        return 1;
    }
    if (!errors.isEmpty()) {
        for (const QString& error : errors)
            std::fprintf(stderr, "%s\n", qPrintable(error));
        return 1;
    }
    return 0;
}
