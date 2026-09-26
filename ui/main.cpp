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

    // Catppuccin Mocha dark theme — full design token set.
    // Worker overrides these on startup with values from
    // ~/.local/state/omarchy/current/theme/colors.toml if present.
    QVariantMap defaultTheme = {
        // Surfaces
        {"background", "#1e1e2e"},
        {"surface", "#232336"},
        {"surface_elevated", "#2a2a40"},
        {"surface_strong", "#313145"},
        {"overlay", "#11111b"},
        {"divider", "#3a3a52"},

        // Foregrounds
        {"foreground", "#cdd6f4"},
        {"foreground_muted", "#a6adc8"},
        {"foreground_dim", "#7f849c"},
        {"foreground_subtle", "#585b70"},

        // Accents
        {"accent", "#89b4fa"},
        {"accent_hover", "#b4cdff"},
        {"success", "#a6e3a1"},
        {"warning", "#f9e2af"},
        {"danger", "#f38ba8"},
        {"info", "#94e2d5"},

        // Source colours
        {"source_repo", "#89b4fa"},
        {"source_aur", "#cba6f7"},
        {"source_cachyos", "#94e2d5"},

        // Spacing (px)
        {"space_xs", 4},
        {"space_sm", 8},
        {"space_md", 12},
        {"space_lg", 16},
        {"space_xl", 24},
        {"space_xxl", 32},

        // Radius (px)
        {"radius_sm", 4},
        {"radius_md", 6},
        {"radius_lg", 8},
        {"radius_xl", 12},

        // Typography
        {"font_family", "Inter, Cantarell, sans-serif"},
        {"caption_size", 11},
        {"small_size", 12},
        {"body_size", 13},
        {"subhead_size", 14},
        {"headline_size", 16},
        {"title_size", 20},

        // Font weight values (CSS-compatible 1-1000)
        {"weight_normal", 400},
        {"weight_medium", 500},
        {"weight_bold",   700},

        // Component sizes (px)
        {"titlebar_height", 56},
        {"tabbar_height",   40},
        {"row_height_sm",   32},
        {"row_height_md",   40},
        {"row_height_lg",   48},
        {"input_height",    36},
        {"button_height",   32},
        {"chip_height",     24},
        {"badge_height",    20},
    };
    engine.rootContext()->setContextProperty("theme", defaultTheme);

    // qt_add_resources keeps the source directory in the resource path.
    const QUrl url(mainQmlUrl());
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreated,
        &app, [&url, &bridge, &engine, &app, defaultTheme](QObject* obj, const QUrl&) {
            if (obj) {
                // Let main.qml know the window for dragging
                QQmlContext* ctx = engine.rootContext();
                ctx->setContextProperty("mainWindow", obj);
                // When worker returns the theme, refresh the QML context
                QObject::connect(bridge, &Bridge::themeChanged, &app, [&engine, bridge, defaultTheme]() {
                    QVariantMap colors = bridge->theme();
                    QVariantMap merged = defaultTheme;
                    merged["background"] = colors.value("background", defaultTheme.value("background"));
                    merged["foreground"] = colors.value("bright_foreground", defaultTheme.value("foreground"));
                    merged["foreground_muted"] = colors.value("dark_foreground", defaultTheme.value("foreground_muted"));
                    merged["foreground_dim"] = colors.value("dark_foreground", defaultTheme.value("foreground_dim"));
                    merged["divider"] = colors.value("muted", defaultTheme.value("divider"));
                    merged["accent"] = colors.value("accent", defaultTheme.value("accent"));
                    merged["accent_hover"] = colors.value("light_foreground", defaultTheme.value("accent_hover"));
                    merged["success"] = colors.value("green", defaultTheme.value("success"));
                    merged["warning"] = colors.value("yellow", defaultTheme.value("warning"));
                    merged["danger"] = colors.value("red", defaultTheme.value("danger"));
                    merged["info"] = colors.value("cyan", defaultTheme.value("info"));
                    merged["source_repo"] = colors.value("blue", defaultTheme.value("source_repo"));
                    merged["source_aur"] = colors.value("magenta", defaultTheme.value("source_aur"));
                    merged["source_cachyos"] = colors.value("cyan", defaultTheme.value("source_cachyos"));
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
