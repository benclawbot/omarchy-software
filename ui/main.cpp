#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSurfaceFormat>

#include "bridge.h"
#include "qmlresources.h"

int main(int argc, char* argv[]) {
    QGuiApplication::setApplicationName("Omarchy Software");
    QGuiApplication::setApplicationVersion("0.1.0");

    QSurfaceFormat fmt;
    fmt.setAlphaBufferSize(8);
    QSurfaceFormat::setDefaultFormat(fmt);

    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    engine.addImportPath(":/qtquickcontrols2.conf");

    Bridge* bridge = new Bridge(&app);
    engine.rootContext()->setContextProperty("bridge", bridge);
    engine.rootContext()->setContextProperty("mainWindow", nullptr); // set from QML

    // Catppuccin Mocha dark defaults — replaced by worker theme when ready
    QVariantMap defaultTheme = {
        {"mode", "dark"},
        {"background", "#1e1e2e"},
        {"dark_background", "#171723"},
        {"darker_background", "#0f0f17"},
        {"lighter_background", "#353543"},
        {"foreground", "#cdd6f4"},
        {"dark_foreground", "#9aa1b7"},
        {"light_foreground", "#d5dcf6"},
        {"bright_foreground", "#dae0f7"},
        {"accent", "#89b4fa"},
        {"selection", "#353543"},
        {"muted", "#45475a"},
        {"source_repo", "#89b4fa"},
        {"source_aur", "#cba6f7"},
        {"source_cachyos", "#94e2d5"},
        {"green", "#a6e3a1"},
        {"yellow", "#f9e2af"},
        {"orange", "#f59cb5"},
        {"red", "#f38ba8"},
        {"cyan", "#94e2d5"},
        {"blue", "#89b4fa"},
        {"magenta", "#cba6f7"},
        {"brown", "#935e6d"},
        {"install", "#a6e3a1"},
        {"update", "#89b4fa"},
        {"remove", "#f38ba8"},
        {"warning", "#f59cb5"},
        {"glass", "rgba(30,30,46,0.82)"},
        {"glass_border", "rgba(137,180,250,0.15)"},
        {"radius", 12},
        {"fontFamily", "monospace"},
        {"fontSize", 13},
    };
    engine.rootContext()->setContextProperty("theme", defaultTheme);

    // qt_add_resources keeps the source directory in the resource path.
    const QUrl url(mainQmlUrl());
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreated,
        &app, [&url, &bridge, &engine, &app](QObject* obj, const QUrl&) {
            if (obj) {
                // Let main.qml know the window for dragging
                QQmlContext* ctx = engine.rootContext();
                ctx->setContextProperty("mainWindow", obj);
                // When worker returns the theme, refresh the QML context
                QObject::connect(bridge, &Bridge::themeChanged, &app, [&engine, bridge]() {
                    QVariantMap colors = bridge->theme();
                    QVariantMap merged = colors;
                    merged["background"] = colors.value("background", "#1e1e2e");
                    merged["foreground"] = colors.value("foreground", "#cdd6f4");
                    engine.rootContext()->setContextProperty("theme", merged);
                });
                // Load theme from the worker
                bridge->requestTheme();
            }
        },
        Qt::QueuedConnection);

    engine.load(url);
    if (engine.rootObjects().isEmpty()) return 1;

    return QGuiApplication::exec();
}
