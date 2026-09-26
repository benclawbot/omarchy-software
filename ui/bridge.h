#pragma once
#include <QAbstractListModel>
#include <QElapsedTimer>
#include <QObject>
#include <QProcess>
#include <QQueue>
#include <QSettings>
#include <QTimer>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

class Rows : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int length READ count NOTIFY countChanged)
public:
    explicit Rows(QObject* parent = nullptr) : QAbstractListModel(parent) {}
    int rowCount(const QModelIndex& p = {}) const override {
        return p.isValid() ? 0 : rows.size();
    }
    QVariant data(const QModelIndex& i, int role) const override {
        return i.isValid() && i.row() < rows.size()
                       && (role == Qt::UserRole + 1 || role == Qt::UserRole + 2)
                   ? rows[i.row()]
                   : QVariant();
    }
    QHash<int, QByteArray> roleNames() const override {
        return {{Qt::UserRole + 1, "entry"}, {Qt::UserRole + 2, "modelData"}};
    }
    Q_INVOKABLE void replace(const QVariantList& next) {
        beginResetModel();
        rows = next;
        endResetModel();
        emit countChanged();
    }
    QVariantList rows;
    int count() const { return rows.size(); }
signals:
    void countChanged();
};

class Bridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(Rows* rows READ rows CONSTANT)
    Q_PROPERTY(QString page READ page WRITE setPage NOTIFY preferencesChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QVariantMap theme READ theme NOTIFY themeChanged)
    Q_PROPERTY(QVariantList selected READ selected NOTIFY selectionChanged)
    Q_PROPERTY(QStringList categories READ categories NOTIFY searchOptionsChanged)
    Q_PROPERTY(QStringList repositories READ repositories NOTIFY searchOptionsChanged)

public:
    explicit Bridge(QObject* parent = nullptr);
    ~Bridge() override;

    Rows* rows() { return &m_rows; }
    QString page() const { return m_page; }
    QString status() const { return m_status; }
    bool busy() const { return m_busy; }
    QVariantMap theme() const { return m_theme; }
    QVariantList selected() const { return m_selected; }
    QStringList categories() const { return m_categories; }
    QStringList repositories() const { return m_repositories; }

    void setPage(const QString& page);

    Q_INVOKABLE void search(const QString& query, const QString& source = "all",
                            const QString& repository = "", const QString& category = "all");
    Q_INVOKABLE void loadInstalled(const QString& filter = "all", const QString& sort = "name", bool reverse = false);
    Q_INVOKABLE void sortInstalled(const QString& sort);
    Q_INVOKABLE void checkUpdates();
    Q_INVOKABLE void previewUpdates();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void queueInstall(const QVariantList& packages, const QVariantList& sources);
    Q_INVOKABLE void queueRemove(const QVariantList& packages);
    Q_INVOKABLE void previewInstall(const QVariantList& packages, const QVariantList& sources);
    Q_INVOKABLE void previewRemove(const QVariantList& packages);
    Q_INVOKABLE void commit(const QVariantMap& preview);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void cancelPreview();
    Q_INVOKABLE void floatPanel(int width, int height);
    Q_INVOKABLE void active(bool visible);
    Q_INVOKABLE void setSelected(const QVariantList& packages);
    Q_INVOKABLE void stageSelectedRemoval();

    // Public wrapper used by main.cpp to trigger initial theme load
    void requestTheme() { send(QVariantMap{{"op", "theme"}}); }

    // Helpers exposed to QML
    Q_INVOKABLE QString formatSize(double bytes) const;
    Q_INVOKABLE void copyToClipboard(const QString& text) const;

signals:
    void themeChanged();
    void statusChanged();
    void busyChanged();
    void selectionChanged();
    void searchOptionsChanged();
    void preferencesChanged();
    void previewReady(const QVariantMap& preview);
    void operationFinished(const QString& action,
                           const QStringList& packages,
                           const QString& message);
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
    QQueue<QVariantMap> m_deferredRequests;
    QStringList m_categories;
    QStringList m_repositories;
    QVariantList m_pendingQueue;
    QVariantList m_pendingSources;
    QString m_pendingAction;
    QStringList m_pendingPackages;
    QElapsedTimer m_clock;
    QString m_page = "installed";
    QString m_searchQuery;
    QString m_searchSource = "all";
    QString m_searchRepository;
    QString m_searchCategory = "all";
    QString m_status = "Ready";
    bool m_busy = false;
    bool m_visible = true;
    bool m_refreshJustCompleted = false;
};
