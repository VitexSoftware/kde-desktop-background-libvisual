#include "settings.h"
#include <QDir>
#include <QStandardPaths>

Settings::Settings() {
    QString configDir = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    QString configPath = configDir + "/libvisual-bg.conf";
    
    m_settings = new QSettings(configPath, QSettings::IniFormat);
    
    // Default values
    m_audioDevice = "default";
    m_visualPlugin = "gforce";
    m_autoSwitchInterval = 30;
    m_windowWidth = 1920;
    m_windowHeight = 1080;
    
    load();
}

Settings::~Settings() {
    save();
    delete m_settings;
}

QString Settings::getAudioDevice() const {
    return m_audioDevice;
}

void Settings::setAudioDevice(const QString& device) {
    m_audioDevice = device;
}

QString Settings::getVisualPlugin() const {
    return m_visualPlugin;
}

void Settings::setVisualPlugin(const QString& plugin) {
    m_visualPlugin = plugin;
}

int Settings::getAutoSwitchInterval() const {
    return m_autoSwitchInterval;
}

void Settings::setAutoSwitchInterval(int seconds) {
    m_autoSwitchInterval = seconds;
}

int Settings::getWindowWidth() const {
    return m_windowWidth;
}

int Settings::getWindowHeight() const {
    return m_windowHeight;
}

void Settings::setWindowSize(int width, int height) {
    m_windowWidth = width;
    m_windowHeight = height;
}

void Settings::save() {
    m_settings->setValue("audio/device", m_audioDevice);
    m_settings->setValue("visual/plugin", m_visualPlugin);
    m_settings->setValue("visual/auto_switch_interval", m_autoSwitchInterval);
    m_settings->setValue("window/width", m_windowWidth);
    m_settings->setValue("window/height", m_windowHeight);
    m_settings->sync();
}

void Settings::load() {
    m_audioDevice = m_settings->value("audio/device", m_audioDevice).toString();
    m_visualPlugin = m_settings->value("visual/plugin", m_visualPlugin).toString();
    m_autoSwitchInterval = m_settings->value("visual/auto_switch_interval", m_autoSwitchInterval).toInt();
    m_windowWidth = m_settings->value("window/width", m_windowWidth).toInt();
    m_windowHeight = m_settings->value("window/height", m_windowHeight).toInt();
}