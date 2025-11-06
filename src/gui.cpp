#include "gui.h"
#include <QApplication>
#include <QGridLayout>
#include <QGroupBox>
#include <QMessageBox>

ControlPanel::ControlPanel(Settings* settings, QWidget* parent)
    : QWidget(parent), m_settings(settings), m_isRunning(false) {
    
    setWindowTitle("LibVisual Background Control");
    setFixedSize(400, 300);
    
    setupUI();
    setupTrayIcon();
    createConnections();
    
    // Hide to system tray by default
    hide();
}

ControlPanel::~ControlPanel() {
}

void ControlPanel::setupUI() {
    m_mainLayout = new QVBoxLayout(this);
    
    // Audio device selection
    QGroupBox* audioGroup = new QGroupBox("Audio Input", this);
    QVBoxLayout* audioLayout = new QVBoxLayout(audioGroup);
    
    QLabel* audioLabel = new QLabel("Audio Device:", audioGroup);
    m_audioDeviceCombo = new QComboBox(audioGroup);
    
    audioLayout->addWidget(audioLabel);
    audioLayout->addWidget(m_audioDeviceCombo);
    
    // Visual plugin selection
    QGroupBox* visualGroup = new QGroupBox("Visualization", this);
    QVBoxLayout* visualLayout = new QVBoxLayout(visualGroup);
    
    QLabel* pluginLabel = new QLabel("Visual Plugin:", visualGroup);
    m_visualPluginCombo = new QComboBox(visualGroup);
    
    QLabel* autoSwitchLabel = new QLabel("Auto Switch Interval (seconds):", visualGroup);
    m_autoSwitchSpin = new QSpinBox(visualGroup);
    m_autoSwitchSpin->setRange(5, 300);
    m_autoSwitchSpin->setValue(m_settings->getAutoSwitchInterval());
    
    visualLayout->addWidget(pluginLabel);
    visualLayout->addWidget(m_visualPluginCombo);
    visualLayout->addWidget(autoSwitchLabel);
    visualLayout->addWidget(m_autoSwitchSpin);
    
    // Control buttons
    QGroupBox* controlGroup = new QGroupBox("Control", this);
    QHBoxLayout* controlLayout = new QHBoxLayout(controlGroup);
    
    m_startButton = new QPushButton("Start Visualization", controlGroup);
    m_stopButton = new QPushButton("Stop Visualization", controlGroup);
    m_stopButton->setEnabled(false);
    
    controlLayout->addWidget(m_startButton);
    controlLayout->addWidget(m_stopButton);
    
    // Add all groups to main layout
    m_mainLayout->addWidget(audioGroup);
    m_mainLayout->addWidget(visualGroup);
    m_mainLayout->addWidget(controlGroup);
    m_mainLayout->addStretch();
}

void ControlPanel::setupTrayIcon() {
    m_trayIcon = new QSystemTrayIcon(this);
    m_trayIcon->setIcon(QIcon(":/icons/libvisual.png")); // You'll need to add an icon
    
    m_trayMenu = new QMenu(this);
    m_showAction = new QAction("Show Control Panel", this);
    m_quitAction = new QAction("Quit", this);
    
    m_trayMenu->addAction(m_showAction);
    m_trayMenu->addSeparator();
    m_trayMenu->addAction(m_quitAction);
    
    m_trayIcon->setContextMenu(m_trayMenu);
    
    if (QSystemTrayIcon::isSystemTrayAvailable()) {
        m_trayIcon->show();
    }
}

void ControlPanel::createConnections() {
    connect(m_audioDeviceCombo, QOverload<int>::of(&QComboBox::currentIndexChanged),
            this, &ControlPanel::onAudioDeviceChanged);
    
    connect(m_visualPluginCombo, QOverload<int>::of(&QComboBox::currentIndexChanged),
            this, &ControlPanel::onVisualPluginChanged);
    
    connect(m_autoSwitchSpin, QOverload<int>::of(&QSpinBox::valueChanged),
            this, &ControlPanel::onAutoSwitchChanged);
    
    connect(m_startButton, &QPushButton::clicked, this, &ControlPanel::onStartClicked);
    connect(m_stopButton, &QPushButton::clicked, this, &ControlPanel::onStopClicked);
    
    connect(m_trayIcon, &QSystemTrayIcon::activated, 
            this, &ControlPanel::onTrayIconActivated);
    
    connect(m_showAction, &QAction::triggered, this, &ControlPanel::showControlPanel);
    connect(m_quitAction, &QAction::triggered, this, &ControlPanel::quitApplication);
}

void ControlPanel::updatePluginList(const std::vector<std::string>& plugins) {
    m_visualPluginCombo->clear();
    
    QString currentPlugin = m_settings->getVisualPlugin();
    int currentIndex = 0;
    
    for (size_t i = 0; i < plugins.size(); ++i) {
        QString pluginName = QString::fromStdString(plugins[i]);
        m_visualPluginCombo->addItem(pluginName);
        
        if (pluginName == currentPlugin) {
            currentIndex = static_cast<int>(i);
        }
    }
    
    m_visualPluginCombo->setCurrentIndex(currentIndex);
}

void ControlPanel::updateAudioDeviceList(const std::vector<std::string>& devices) {
    m_audioDeviceCombo->clear();
    
    QString currentDevice = m_settings->getAudioDevice();
    int currentIndex = 0;
    
    for (size_t i = 0; i < devices.size(); ++i) {
        QString deviceName = QString::fromStdString(devices[i]);
        m_audioDeviceCombo->addItem(deviceName);
        
        if (deviceName == currentDevice) {
            currentIndex = static_cast<int>(i);
        }
    }
    
    m_audioDeviceCombo->setCurrentIndex(currentIndex);
}

void ControlPanel::onAudioDeviceChanged() {
    QString device = m_audioDeviceCombo->currentText();
    m_settings->setAudioDevice(device);
    emit audioDeviceChanged(device);
}

void ControlPanel::onVisualPluginChanged() {
    QString plugin = m_visualPluginCombo->currentText();
    m_settings->setVisualPlugin(plugin);
    emit visualPluginChanged(plugin);
}

void ControlPanel::onAutoSwitchChanged() {
    int interval = m_autoSwitchSpin->value();
    m_settings->setAutoSwitchInterval(interval);
    emit autoSwitchIntervalChanged(interval);
}

void ControlPanel::onStartClicked() {
    m_startButton->setEnabled(false);
    m_stopButton->setEnabled(true);
    m_isRunning = true;
    emit startVisualization();
}

void ControlPanel::onStopClicked() {
    m_startButton->setEnabled(true);
    m_stopButton->setEnabled(false);
    m_isRunning = false;
    emit stopVisualization();
}

void ControlPanel::onTrayIconActivated(QSystemTrayIcon::ActivationReason reason) {
    if (reason == QSystemTrayIcon::DoubleClick) {
        showControlPanel();
    }
}

void ControlPanel::showControlPanel() {
    show();
    raise();
    activateWindow();
}

void ControlPanel::quitApplication() {
    QApplication::quit();
}

// MOC include removed - using automoc