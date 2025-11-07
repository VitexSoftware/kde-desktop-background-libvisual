/*
 * Decibel probe singleton for config dialog
 */
#pragma once
#include <QObject>
#include <QTimer>
#include <atomic>

struct pa_simple; // forward

class AudioLevelProbe : public QObject {
    Q_OBJECT
    Q_PROPERTY(double decibels READ decibels NOTIFY decibelsChanged)
public:
    explicit AudioLevelProbe(QObject *parent=nullptr);
    ~AudioLevelProbe() override;
    double decibels() const { return m_dbSmoothed; }
signals:
    void decibelsChanged();
private slots:
    void poll();
private:
    void start();
    void stop();
    pa_simple *m_pa=nullptr;
    QTimer m_timer;
    std::atomic<bool> m_running{false};
    double m_dbSmoothed=-90.0;
};

// QML plugin wrapper
#include <QQmlExtensionPlugin>
class LibVisualProbePlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlEngineExtensionInterface_iid)
public:
    void registerTypes(const char *uri) override;
};
