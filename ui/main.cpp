#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include <QtQuickControls2>
#include <QSurfaceFormat>

#include "bridge.h"

int main(int argc, char* argv[]) {
    QGuiApplication::setApplicationName("Omarchy Software");
    QGuiApplication::setApplicationVersion("0.1.0");

    QSurfaceFormat fmt;
    fmt.setAlphaBufferSize(8);
    QSurfaceFormat::setDefaultFormat(fmt);

    // Wayland/OpenGL for Hyprland
    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGLRhi);

    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    engine.addImportPath(":/qtquickcontrols2.conf");

    Bridge* bridge = new Bridge(&app);
    engine.rootContext()->setContextProperty("bridge", bridge);
    engine.rootContext()->setContextProperty("mainWindow", nullptr); // set from QML

    const QUrl url(QStringLiteral("qrc:/Main.qml"));
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreated,
        &app, [&url, &bridge, &engine](QObject* obj, const QUrl&) {
            if (obj) {
                // Let main.qml know the window for dragging
                QQmlContext* ctx = engine.rootContext();
                ctx->setContextProperty("mainWindow", obj);
                // Load theme from the worker
                bridge->requestTheme();
            }
        },
        Qt::QueuedConnection);

    engine.load(url);
    if (engine.rootObjects().isEmpty()) return 1;

    return QGuiApplication::exec();
}
