#include "bridge.h"
#include <QAbstractItemModel>
#include <QClipboard>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QScopeGuard>
#include <QStandardPaths>
#include <QUuid>

Bridge::Bridge(QObject* parent)
    : QObject(parent)
    , m_settings(
          QSettings::IniFormat, QSettings::UserScope,
          "omarchy-software", "preferences")
    , m_clock()
{
    // Locate the Rust worker. Try adjacent to the GUI binary (development),
    // then the system install path.
    QString adjacent =
        QCoreApplication::applicationDirPath() + "/omarchy-software-core";
    QString installed =
        QDir(QCoreApplication::applicationDirPath())
            .absoluteFilePath(
                "../lib/omarchy-software/omarchy-software-core");
    m_worker.setProgram(QFileInfo::exists(adjacent) ? adjacent : installed);
    m_worker.setProcessChannelMode(QProcess::SeparateChannels);
    m_worker.start();

    // Worker writes JSON responses on stdout; tracing logs on stderr.
    connect(&m_worker, &QProcess::readyReadStandardOutput, this, &Bridge::receive);
    // Drain stderr so the OS pipe buffer doesn't fill and stall the worker.
    connect(&m_worker, &QProcess::readyReadStandardError, this, [this]() {
        m_worker.readAllStandardError();
    });
    connect(&m_worker, &QProcess::finished, this, [this](int code, QProcess::ExitStatus) {
        if (code != 0) {
            message("Worker exited with code " + QString::number(code));
        }
    });

    // Heartbeat / polling timer
    m_timer.setInterval(1000);
    connect(&m_timer, &QTimer::timeout, this, &Bridge::rebuild);
    m_timer.start();

    m_timeout.setSingleShot(true);
}

Bridge::~Bridge() {
    m_timer.stop();
    m_timeout.stop();

    if (m_worker.state() == QProcess::Starting) {
        m_worker.waitForStarted(1000);
    }
    if (m_worker.state() == QProcess::Running) {
        send(QVariantMap{{"op", "quit"}});
        if (m_worker.waitForFinished(1000)) return;

        m_worker.terminate();
        if (m_worker.waitForFinished(500)) return;

        m_worker.kill();
        m_worker.waitForFinished(1000);
    }
}

void Bridge::receive() {
    QByteArray data = m_worker.readAllStandardOutput();
    if (data.isEmpty()) return;

    m_buffer.append(data);
    while (true) {
        int pos = m_buffer.indexOf('\n');
        if (pos < 0) break;
        QByteArray line = m_buffer.left(pos);
        m_buffer = m_buffer.mid(pos + 1);
        if (line.isEmpty()) continue;

        QJsonParseError err;
        QJsonDocument doc = QJsonDocument::fromJson(line, &err);
        if (err.error != QJsonParseError::NoError) {
            qWarning() << "JSON parse error:" << err.errorString() << "in:" << line;
            continue;
        }
        handleResponse(doc.toVariant().toMap());
    }
}

void Bridge::handleResponse(const QVariantMap& resp) {
    QString kind = resp.value("kind").toString();

    if (kind == "theme") {
        applyTheme(resp.value("colors").toMap());
        emit themeChanged();
        return;
    }

    if (kind == "search_results") {
        m_busy = false;
        emit busyChanged();
        auto results = resp.value("results").toList();
        QVariantList rows;
        for (const auto& r : results) {
            auto m = r.toMap();
            // Human-readable size
            m["size_human"] = formatSize(m.value("size").toLongLong());
            rows.append(m);
        }
        m_rows.replace(rows);
        m_status = QString::number(results.size()) + " packages found";
        emit statusChanged();
        return;
    }

    if (kind == "installed") {
        m_busy = false;
        emit busyChanged();
        auto pkgs = resp.value("packages").toList();
        QVariantList rows;
        for (const auto& p : pkgs) {
            auto m = p.toMap();
            m["size_human"] = formatSize(m.value("size").toLongLong());
            rows.append(m);
        }
        m_rows.replace(rows);
        m_status = QString::number(pkgs.size()) + " installed";
        emit statusChanged();
        return;
    }

    if (kind == "updates") {
        auto repos = resp.value("repos").toList();
        auto aur = resp.value("aur").toList();
        int total = resp.value("total").toInt();
        emit updatesAvailable(total);
        m_status = QString::number(total) + " updates available";
        emit statusChanged();
        return;
    }

    if (kind == "preview") {
        m_busy = false;
        emit busyChanged();
        emit previewReady(resp.value("preview").toMap());
        return;
    }

    if (kind == "commit_result") {
        m_busy = false;
        emit busyChanged();
        emit operationFinished(resp.value("output").toString());
        // Refresh
        if (m_page == "installed") {
            loadInstalled();
        } else if (m_page == "updates") {
            checkUpdates();
        }
        return;
    }

    if (kind == "cache_cleaned") {
        emit operationFinished(
            "Freed " + formatSize(resp.value("freed_bytes").toLongLong()) +
            " (" + QString::number(resp.value("freed_units").toInt()) + " files)");
        return;
    }

    if (kind == "error") {
        m_busy = false;
        emit busyChanged();
        emit error(resp.value("message").toString());
        return;
    }

    if (kind == "action") {
        auto results = resp.value("results").toList();
        for (const auto& r : results) {
            auto m = r.toMap();
            if (m.value("ok").toBool()) {
                // no-op, already handled in specific cases above
            } else {
                emit error(m.value("message").toString());
            }
        }
    }
}

void Bridge::applyTheme(const QVariantMap& colors) {
    m_theme = colors;
    // Also expose individual colours via QSettings for QML to read directly
    for (auto it = colors.constBegin(); it != colors.constEnd(); ++it) {
        m_settings.setValue("theme/" + it.key(), it.value().toString());
    }
}

bool Bridge::send(const QVariantMap& req) {
    if (m_worker.state() != QProcess::Running) return false;
    QJsonDocument doc(QJsonObject::fromVariantMap(req));
    m_worker.write(doc.toJson(QJsonDocument::Compact));
    m_worker.write("\n");
    return true;
}

void Bridge::rebuild() {
    if (m_busy || !m_visible) return;
    // No automatic rebuild in browse mode — only on explicit action
}

void Bridge::message(const QString& text) {
    m_status = text;
    emit statusChanged();
}

void Bridge::finish() {
    m_busy = false;
    emit busyChanged();
}

void Bridge::handleTimeout() {
    // Worker didn't respond within the timeout window.
    m_busy = false;
    emit busyChanged();
    emit error("Worker timeout — no response from omarchy-software-core");
}

// ── QML invokables ─────────────────────────────────────────────────────────

void Bridge::setPage(const QString& page) {
    m_page = page;
    emit preferencesChanged();
}

void Bridge::search(const QString& query, const QString& source) {
    if (query.isEmpty()) { m_rows.replace({}); return; }
    m_busy = true; emit busyChanged();
    m_status = "Searching…"; emit statusChanged();
    send(QVariantMap{{"op", "search"}, {"query", query}, {"source", source}});
}

void Bridge::loadInstalled(const QString& filter, const QString& sort, bool reverse) {
    m_busy = true; emit busyChanged();
    m_status = "Loading…"; emit statusChanged();
    send(QVariantMap{{"op", "installed"}, {"filter", filter}, {"sort", sort}, {"reverse", reverse}});
}

void Bridge::sortInstalled(const QString& sort) {
    loadInstalled(m_settings.value("installed_filter", "all").toString(), sort, false);
}

void Bridge::checkUpdates() {
    m_busy = true; emit busyChanged();
    m_status = "Checking for updates…"; emit statusChanged();
    send(QVariantMap{{"op", "updates"}});
}

void Bridge::refresh() {
    m_busy = true; emit busyChanged();
    m_status = "Refreshing databases…"; emit statusChanged();
    send(QVariantMap{{"op", "refresh"}});
}

void Bridge::queueInstall(const QVariantList& packages, const QVariantList& sources) {
    m_pendingQueue = packages;
    m_pendingSources = sources;
    m_pendingAction = "install";
    previewInstall(packages, sources);
}

void Bridge::queueRemove(const QVariantList& packages) {
    m_pendingQueue = packages;
    m_pendingAction = "remove";
    previewRemove(packages);
}

void Bridge::previewInstall(const QVariantList& packages, const QVariantList& sources) {
    m_busy = true; emit busyChanged();
    send(QVariantMap{
        {"op", "preview_install"},
        {"packages", packages},
        {"sources", sources}
    });
}

void Bridge::previewRemove(const QVariantList& packages) {
    m_busy = true; emit busyChanged();
    send(QVariantMap{{"op", "preview_remove"}, {"packages", packages}});
}

void Bridge::commit(const QVariantMap& preview) {
    m_busy = true; emit busyChanged();
    m_status = "Applying changes…"; emit statusChanged();
    send(QVariantMap{{"op", "commit"}, {"preview", preview}});
}

void Bridge::cancel() {
    send(QVariantMap{{"op", "cancel"}});
    m_busy = false;
    emit busyChanged();
    m_status = "Cancelled";
    emit statusChanged();
}

void Bridge::cancelPreview() {
    send(QVariantMap{{"op", "cancel_preview"}});
}

void Bridge::cleanCache(const QString& mode) {
    m_busy = true; emit busyChanged();
    send(QVariantMap{{"op", "cache_clean"}, {"mode", mode}});
}

void Bridge::floatPanel(int width, int height) {
    // Communicate with Hyprland to float and centre the panel
    // Uses the same hyprland protocol as the task manager
    QProcess::execute("hyprctl", {"keyword", "submap", "move"});
    Q_UNUSED(width); Q_UNUSED(height);
}

void Bridge::active(bool visible) {
    m_visible = visible;
    if (!visible) {
        // Stop polling while hidden
        m_timer.stop();
    } else {
        m_timer.start();
    }
}

QString Bridge::formatSize(double bytes) const {
    const char* units[] = {"B", "KiB", "MiB", "GiB"};
    int i = 0;
    double v = bytes;
    while (v >= 1024.0 && i < 3) { v /= 1024.0; ++i; }
    return QString::number(v, 'f', 1) + " " + units[i];
}

void Bridge::copyToClipboard(const QString& text) const {
    QGuiApplication::clipboard()->setText(text);
}
