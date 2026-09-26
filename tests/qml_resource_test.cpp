#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlPropertyMap>
#include <QQuickWindow>
#include <QVariantMap>
#include <cstdio>

namespace {
QVariantMap testTheme() {
    QVariantMap theme;
    theme.insert(QStringLiteral("background"), QStringLiteral("#1e1e2e"));
    theme.insert(QStringLiteral("surface"), QStringLiteral("#232336"));
    theme.insert(QStringLiteral("surface_elevated"), QStringLiteral("#2a2a40"));
    theme.insert(QStringLiteral("surface_strong"), QStringLiteral("#313145"));
    theme.insert(QStringLiteral("overlay"), QStringLiteral("#11111b"));
    theme.insert(QStringLiteral("divider"), QStringLiteral("#3a3a52"));
    theme.insert(QStringLiteral("foreground"), QStringLiteral("#cdd6f4"));
    theme.insert(QStringLiteral("foreground_muted"), QStringLiteral("#a6adc8"));
    theme.insert(QStringLiteral("foreground_dim"), QStringLiteral("#7f849c"));
    theme.insert(QStringLiteral("foreground_subtle"), QStringLiteral("#585b70"));
    theme.insert(QStringLiteral("accent"), QStringLiteral("#89b4fa"));
    theme.insert(QStringLiteral("accent_hover"), QStringLiteral("#b4cdff"));
    theme.insert(QStringLiteral("success"), QStringLiteral("#a6e3a1"));
    theme.insert(QStringLiteral("warning"), QStringLiteral("#f9e2af"));
    theme.insert(QStringLiteral("danger"), QStringLiteral("#f38ba8"));
    theme.insert(QStringLiteral("info"), QStringLiteral("#94e2d5"));
    theme.insert(QStringLiteral("source_repo"), QStringLiteral("#89b4fa"));
    theme.insert(QStringLiteral("source_aur"), QStringLiteral("#cba6f7"));
    theme.insert(QStringLiteral("source_cachyos"), QStringLiteral("#94e2d5"));
    theme.insert(QStringLiteral("space_xs"), 4);
    theme.insert(QStringLiteral("space_sm"), 8);
    theme.insert(QStringLiteral("space_md"), 12);
    theme.insert(QStringLiteral("space_lg"), 16);
    theme.insert(QStringLiteral("space_xl"), 24);
    theme.insert(QStringLiteral("space_xxl"), 32);
    theme.insert(QStringLiteral("radius_sm"), 4);
    theme.insert(QStringLiteral("radius_md"), 6);
    theme.insert(QStringLiteral("radius_lg"), 8);
    theme.insert(QStringLiteral("radius_xl"), 12);
    theme.insert(QStringLiteral("font_family"), QStringLiteral("Inter, Cantarell, sans-serif"));
    theme.insert(QStringLiteral("caption_size"), 11);
    theme.insert(QStringLiteral("small_size"), 12);
    theme.insert(QStringLiteral("body_size"), 13);
    theme.insert(QStringLiteral("subhead_size"), 14);
    theme.insert(QStringLiteral("headline_size"), 16);
    theme.insert(QStringLiteral("title_size"), 20);
    theme.insert(QStringLiteral("weight_normal"), 400);
    theme.insert(QStringLiteral("weight_medium"), 500);
    theme.insert(QStringLiteral("weight_bold"), 700);
    theme.insert(QStringLiteral("titlebar_height"), 56);
    theme.insert(QStringLiteral("tabbar_height"), 40);
    theme.insert(QStringLiteral("row_height_sm"), 32);
    theme.insert(QStringLiteral("row_height_md"), 40);
    theme.insert(QStringLiteral("row_height_lg"), 48);
    theme.insert(QStringLiteral("input_height"), 36);
    theme.insert(QStringLiteral("button_height"), 32);
    theme.insert(QStringLiteral("chip_height"), 24);
    theme.insert(QStringLiteral("badge_height"), 20);
    return theme;
}
}

int main(int argc, char* argv[]) {
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), testTheme());
    auto* bridge = QQmlPropertyMap::create(&engine);
    bridge->insert(QStringLiteral("rows"), QVariantList{});
    bridge->insert(QStringLiteral("busy"), false);
    bridge->insert(QStringLiteral("status"), QStringLiteral("Ready"));
    bridge->insert(QStringLiteral("categories"), QStringList{});
    bridge->insert(QStringLiteral("repositories"), QStringList{});
    engine.rootContext()->setContextProperty(QStringLiteral("bridge"), bridge);
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
