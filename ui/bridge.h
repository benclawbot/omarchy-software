#pragma once
#include <QAbstractListModel>
#include <QElapsedTimer>
#include <QObject>
#include <QProcess>
#include <QSettings>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

class Rows : public QAbstractListModel {
    Q_OBJECT
public:
    explicit Rows(QObject* parent = nullptr) : QAbstractListModel(parent) {}
    int rowCount(const QModelIndex& p = {}) const override {
        return p.isValid() ? 0 : rows.size();
    }
    QVariant data(const QModelIndex& i, int role) const override {
        return i.isValid() && i.row() < rows.size() && role == Qt::UserRole + 1
                   ? rows[i.row()]
                   : QVariant();
    }
    QHash<int, QByteArray> roleNames() const override {
        return {{Qt::UserRole + 1, "entry"}};
    }
    Q_INVOKABLE void replace(const QVariantList& next) {
        beginResetModel();
        rows = next;
        endResetModel();
    }
    QVariantList rows;
};

class Bridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(Rows* rows READ rows CONSTANT)
    Q_PROPERTY(QString page READ page WRITE setPage NOTIFY preferencesChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QVariantMap theme READ theme NOTIFY themeChanged)
    Q_PROPERTY(QVariantList selected READ selected NOTIFY selectionChanged)

public:
    explicit Bridge(QObject* parent = nullptr);
    ~Bridge() override;

    Rows* rows() { return &m_rows; }
    QString page() const { return m_page; }
    QString status() const { return m_status; }
    bool busy() const { return m_busy; }
    QVariantMap theme() const { return m_theme; }
    QVariantList selected() const { return m_selected; }

    void setPage(const QString& page);

    Q_INVOKABLE void search(const QString& query, const QString& source = "all");
    Q_INVOKABLE void loadInstalled(const QString& filter = "all", const QString& sort = "name", bool reverse = false);
    Q_INVOKABLE void sortInstalled(const QString& sort);
    Q_INVOKABLE void checkUpdates();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void queueInstall(const QVariantList& packages, const QVariantList& sources);
    Q_INVOKABLE void queueRemove(const QVariantList& packages);
    Q_INVOKABLE void previewInstall(const QVariantList& packages, const QVariantList& sources);
    Q_INVOKABLE void previewRemove(const QVariantList& packages);
    Q_INVOKABLE void commit(const QVariantMap& preview);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void cancelPreview();
    Q_INVOKABLE void cleanCache(const QString& mode);
    Q_INVOKABLE void floatPanel(int width, int height);
    Q_INVOKABLE void active(bool visible);

    // Helpers exposed to QML
    Q_INVOKABLE QString formatSize(double bytes) const;
    Q_INVOKABLE void copyToClipboard(const QString& text) const;

signals:
    void themeChanged();
    void statusChanged();
    void busyChanged();
    void selectionChanged();
    void previewReady(const QVariantMap& preview);
    void operationFinished(const QString& message);
    void error(const QString& message);
    void updatesAvailable(int count);

private slots:
    void receive();
    void handleTimeout();

private:
    void rebuild();
    bool send(const QVariantMap& req);
    void message(const QString& text);
    void finish();
    void handleResponse(const QVariantMap& resp);
    void applyTheme(const QVariantMap& colors);

    Rows m_rows;
    QProcess m_worker;
    QTimer m_timer, m_timeout;
    QSettings m_settings;
    QByteArray m_buffer;
    QVariantMap m_snapshot;
    QVariantMap m_theme;
    QVariantList m_selected;
    QVariantList m_pendingQueue;
    QVariantList m_pendingSources;
    QString m_pendingAction;
    QElapsedTimer m_clock;
    QString m_page = "browse";
    QString m_status = "Ready";
    bool m_busy = false;
    bool m_visible = true;
};
