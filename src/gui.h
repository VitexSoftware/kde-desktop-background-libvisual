#ifndef GUI_H
#define GUI_H

#include <QWidget>
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QComboBox>
#include <QSpinBox>
#include <QPushButton>
#include <QLabel>
#include <QTimer>
#include <QSystemTrayIcon>
#include <QMenu>
#include <QAction>
#include <QApplication>

#include "settings.h"
#include "visualizer.h"
#include "audio_input.h"

class ControlPanel : public QWidget {
    Q_OBJECT

public:
    explicit ControlPanel(Settings* settings, QWidget* parent = nullptr);
    ~ControlPanel();

    void updatePluginList(const std::vector<std::string>& plugins);
    void updateAudioDeviceList(const std::vector<std::string>& devices);

signals:
    void audioDeviceChanged(const QString& device);
    void visualPluginChanged(const QString& plugin);
    void autoSwitchIntervalChanged(int seconds);
    void startVisualization();
    void stopVisualization();

private slots:
    void onAudioDeviceChanged();
    void onVisualPluginChanged();
    void onAutoSwitchChanged();
    void onStartClicked();
    void onStopClicked();
    void onTrayIconActivated(QSystemTrayIcon::ActivationReason reason);
    void showControlPanel();
    void quitApplication();

private:
    void setupUI();
    void setupTrayIcon();
    void createConnections();

    Settings* m_settings;
    
    // UI components
    QVBoxLayout* m_mainLayout;
    QComboBox* m_audioDeviceCombo;
    QComboBox* m_visualPluginCombo;
    QSpinBox* m_autoSwitchSpin;
    QPushButton* m_startButton;
    QPushButton* m_stopButton;
    
    // System tray
    QSystemTrayIcon* m_trayIcon;
    QMenu* m_trayMenu;
    QAction* m_showAction;
    QAction* m_quitAction;
    
    bool m_isRunning;
};

#endif // GUI_H