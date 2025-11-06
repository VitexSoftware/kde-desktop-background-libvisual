#ifndef SETTINGS_H
#define SETTINGS_H

#include <QString>
#include <QSettings>

class Settings {
public:
    Settings();
    ~Settings();

    // Audio settings
    QString getAudioDevice() const;
    void setAudioDevice(const QString& device);

    // Visual settings
    QString getVisualPlugin() const;
    void setVisualPlugin(const QString& plugin);

    int getAutoSwitchInterval() const;
    void setAutoSwitchInterval(int seconds);

    // Window settings
    int getWindowWidth() const;
    int getWindowHeight() const;
    void setWindowSize(int width, int height);

    // Save/Load
    void save();
    void load();

private:
    QSettings* m_settings;
    QString m_audioDevice;
    QString m_visualPlugin;
    int m_autoSwitchInterval;
    int m_windowWidth;
    int m_windowHeight;
};

#endif // SETTINGS_H