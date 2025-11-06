#include <QApplication>
#include <QTimer>
#include <QThread>

#include "settings.h"
#include "visualizer.h"
#include "audio_input.h"
#include "desktop_renderer.h"
#include "gui.h"

#include <iostream>
#include <memory>
#include <csignal>

class VisualizationApp : public QObject {
    Q_OBJECT

public:
    VisualizationApp(QObject* parent = nullptr) : QObject(parent), m_running(false) {
        m_settings = std::make_unique<Settings>();
        m_visualizer = std::make_unique<Visualizer>();
        m_audioInput = std::make_unique<AudioInput>();
        m_renderer = std::make_unique<DesktopRenderer>();
        
        // Setup render timer
        m_renderTimer = new QTimer(this);
        connect(m_renderTimer, &QTimer::timeout, this, &VisualizationApp::renderFrame);
        
        // Setup auto-switch timer
        m_autoSwitchTimer = new QTimer(this);
        connect(m_autoSwitchTimer, &QTimer::timeout, this, &VisualizationApp::switchToNextPlugin);
    }

    ~VisualizationApp() {
        stopVisualization();
    }

    bool initialize() {
        // Get screen size
        int screenWidth, screenHeight;
        if (!m_renderer->initialize()) {
            std::cerr << "Failed to initialize desktop renderer" << std::endl;
            return false;
        }
        
        m_renderer->getScreenSize(screenWidth, screenHeight);
        m_settings->setWindowSize(screenWidth, screenHeight);

        // Initialize visualizer
        if (!m_visualizer->initialize(screenWidth, screenHeight)) {
            std::cerr << "Failed to initialize visualizer" << std::endl;
            return false;
        }

        // Get available plugins and load default
        m_availablePlugins = m_visualizer->getAvailablePlugins();
        if (m_availablePlugins.empty()) {
            std::cerr << "No visualization plugins found" << std::endl;
            return false;
        }

        // Load default plugin
        std::string defaultPlugin = m_settings->getVisualPlugin().toStdString();
        bool pluginFound = false;
        for (const auto& plugin : m_availablePlugins) {
            if (plugin == defaultPlugin) {
                pluginFound = true;
                break;
            }
        }

        if (!pluginFound && !m_availablePlugins.empty()) {
            defaultPlugin = m_availablePlugins[0];
            m_settings->setVisualPlugin(QString::fromStdString(defaultPlugin));
        }

        if (!m_visualizer->loadPlugin(defaultPlugin)) {
            std::cerr << "Failed to load visualization plugin: " << defaultPlugin << std::endl;
            return false;
        }

        m_currentPluginIndex = 0;

        // Initialize audio input
        std::string audioDevice = m_settings->getAudioDevice().toStdString();
        if (!m_audioInput->initialize(audioDevice)) {
            std::cerr << "Failed to initialize audio input" << std::endl;
            return false;
        }

        // Set audio callback
        m_audioInput->setAudioCallback([this](const float* data, size_t samples) {
            m_visualizer->processAudio(data, samples);
        });

        return true;
    }

    void createGUI() {
        m_controlPanel = std::make_unique<ControlPanel>(m_settings.get());
        
        // Update GUI with available options
        m_controlPanel->updatePluginList(m_availablePlugins);
        m_controlPanel->updateAudioDeviceList(m_audioInput->getAvailableDevices());
        
        // Connect signals
        connect(m_controlPanel.get(), &ControlPanel::startVisualization,
                this, &VisualizationApp::startVisualization);
        connect(m_controlPanel.get(), &ControlPanel::stopVisualization,
                this, &VisualizationApp::stopVisualization);
        connect(m_controlPanel.get(), &ControlPanel::visualPluginChanged,
                this, &VisualizationApp::changePlugin);
        connect(m_controlPanel.get(), &ControlPanel::audioDeviceChanged,
                this, &VisualizationApp::changeAudioDevice);
        connect(m_controlPanel.get(), &ControlPanel::autoSwitchIntervalChanged,
                this, &VisualizationApp::changeAutoSwitchInterval);
    }

public slots:
    void startVisualization() {
        if (m_running) return;

        m_audioInput->start();
        m_renderTimer->start(16); // ~60 FPS
        
        int interval = m_settings->getAutoSwitchInterval();
        if (interval > 0) {
            m_autoSwitchTimer->start(interval * 1000);
        }
        
        m_running = true;
        std::cout << "Visualization started" << std::endl;
    }

    void stopVisualization() {
        if (!m_running) return;

        m_audioInput->stop();
        m_renderTimer->stop();
        m_autoSwitchTimer->stop();
        
        m_running = false;
        std::cout << "Visualization stopped" << std::endl;
    }

    void changePlugin(const QString& pluginName) {
        m_visualizer->loadPlugin(pluginName.toStdString());
        
        // Update current plugin index
        for (size_t i = 0; i < m_availablePlugins.size(); ++i) {
            if (m_availablePlugins[i] == pluginName.toStdString()) {
                m_currentPluginIndex = i;
                break;
            }
        }
    }

    void changeAudioDevice(const QString& deviceName) {
        bool wasRunning = m_running;
        if (wasRunning) {
            stopVisualization();
        }

        m_audioInput->initialize(deviceName.toStdString());

        if (wasRunning) {
            startVisualization();
        }
    }

    void changeAutoSwitchInterval(int seconds) {
        if (m_running && seconds > 0) {
            m_autoSwitchTimer->start(seconds * 1000);
        } else {
            m_autoSwitchTimer->stop();
        }
    }

private slots:
    void renderFrame() {
        if (!m_running) return;

        if (m_visualizer->render()) {
            unsigned char* videoData = m_visualizer->getVideoData();
            if (videoData) {
                m_renderer->renderFrame(videoData, 
                                      m_visualizer->getWidth(), 
                                      m_visualizer->getHeight());
            }
        }
    }

    void switchToNextPlugin() {
        if (m_availablePlugins.empty()) return;

        m_currentPluginIndex = (m_currentPluginIndex + 1) % m_availablePlugins.size();
        QString nextPlugin = QString::fromStdString(m_availablePlugins[m_currentPluginIndex]);
        
        changePlugin(nextPlugin);
        m_settings->setVisualPlugin(nextPlugin);
        
        std::cout << "Switched to plugin: " << nextPlugin.toStdString() << std::endl;
    }

private:
    std::unique_ptr<Settings> m_settings;
    std::unique_ptr<Visualizer> m_visualizer;
    std::unique_ptr<AudioInput> m_audioInput;
    std::unique_ptr<DesktopRenderer> m_renderer;
    std::unique_ptr<ControlPanel> m_controlPanel;
    
    QTimer* m_renderTimer;
    QTimer* m_autoSwitchTimer;
    
    std::vector<std::string> m_availablePlugins;
    size_t m_currentPluginIndex;
    bool m_running;
};

// Signal handler for clean shutdown
VisualizationApp* g_app = nullptr;

void signalHandler(int signal) {
    if (g_app) {
        g_app->stopVisualization();
    }
    QApplication::quit();
}

int main(int argc, char* argv[]) {
    QApplication app(argc, argv);
    app.setApplicationName("LibVisual Background");
    app.setApplicationVersion("1.0");
    app.setQuitOnLastWindowClosed(false); // Keep running in system tray

    // Initialize libvisual first
    if (visual_init(&argc, &argv) != VISUAL_OK) {
        std::cerr << "Failed to initialize libvisual" << std::endl;
        return 1;
    }

    // Setup signal handlers
    signal(SIGINT, signalHandler);
    signal(SIGTERM, signalHandler);

    VisualizationApp vizApp;
    g_app = &vizApp;

    if (!vizApp.initialize()) {
        std::cerr << "Failed to initialize application" << std::endl;
        return 1;
    }

    vizApp.createGUI();

    // Auto-start visualization if requested
    bool autoStart = false;
    for (int i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--autostart") == 0) {
            autoStart = true;
            break;
        }
    }

    if (autoStart) {
        QTimer::singleShot(1000, &vizApp, &VisualizationApp::startVisualization);
    }

    std::cout << "LibVisual Background started. Check system tray for controls." << std::endl;
    
    int result = app.exec();
    g_app = nullptr;
    
    // Cleanup libvisual
    visual_quit();
    
    return result;
}

#include "main.moc"