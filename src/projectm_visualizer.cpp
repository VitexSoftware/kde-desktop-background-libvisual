#include "projectm_visualizer.h"
#include <libprojectM/projectM.hpp>
#include <iostream>
#include <filesystem>
#include <algorithm>
#include <GL/gl.h>

namespace fs = std::filesystem;

ProjectMVisualizer::ProjectMVisualizer()
    : m_projectM(nullptr), m_width(0), m_height(0), m_initialized(false),
      m_directGL(false), m_glDisplay(nullptr), m_glWindow(0), m_glContext(nullptr) {
}

ProjectMVisualizer::~ProjectMVisualizer() {
    shutdown();
}

bool ProjectMVisualizer::setGLContext(void* display, unsigned long window, void* glxContext) {
    m_glDisplay = static_cast<Display*>(display);
    m_glWindow  = static_cast<Window>(window);
    m_glContext  = static_cast<GLXContext>(glxContext);
    m_directGL   = true;
    std::cout << "ProjectM: direct GL rendering enabled (no CPU readback)" << std::endl;
    return true;
}

bool ProjectMVisualizer::initialize(int width, int height) {
    std::cout << "Initializing projectM visualizer: " << width << "x" << height << std::endl;

    m_width  = width;
    m_height = height;

    // Allocate CPU readback buffer only for the non-direct-GL fallback path
    if (!m_directGL) {
        m_frameBuffer.resize(m_width * m_height * 3);
    }

    // If using a shared GLX context, make it current before projectM init so
    // projectM creates its FBOs inside our window's context.
    if (m_directGL) {
        glXMakeCurrent(m_glDisplay, m_glWindow, m_glContext);
    }

    try {
        std::vector<std::string> configPaths = {
            "./projectM.conf",
            "/etc/projectM.conf",
            std::string(getenv("HOME") ? getenv("HOME") : "") + "/.projectM/config.inp"
        };

        std::string configFile;
        for (const auto& path : configPaths) {
            if (fs::exists(path)) {
                configFile = path;
                std::cout << "Using projectM config: " << configFile << std::endl;
                break;
            }
        }

        if (!configFile.empty()) {
            m_projectM = new projectM(configFile, projectM::FLAG_NONE);
        } else {
            projectM::Settings settings;
            settings.windowWidth          = m_width;
            settings.windowHeight         = m_height;
            settings.meshX                = 32;
            settings.meshY                = 24;
            settings.fps                  = 60;
            settings.textureSize          = 512;
            settings.smoothPresetDuration = 5;
            settings.presetDuration       = 30;
            settings.beatSensitivity      = 1.0f;
            settings.aspectCorrection     = true;
            settings.easterEgg            = 0.0f;
            settings.shuffleEnabled       = true;
            settings.hardcutEnabled       = false;
            settings.hardcutDuration      = 60;
            settings.hardcutSensitivity   = 1.0f;
            settings.softCutRatingsEnabled = false;
            settings.presetURL            = std::string("/usr/share/projectM/presets");
            settings.titleFontURL         = std::string();
            settings.menuFontURL          = std::string();
            settings.datadir              = std::string();

            m_projectM = new projectM(settings, projectM::FLAG_NONE);
        }

        if (!m_projectM) {
            std::cerr << "Failed to create projectM instance" << std::endl;
            return false;
        }

        scanPresets();
        if (m_presetPaths.empty()) {
            std::cerr << "No projectM presets found" << std::endl;
            return false;
        }

        if (!loadPresetByIndex(0)) {
            std::cerr << "Failed to load initial preset" << std::endl;
            return false;
        }

        m_initialized = true;
        std::cout << "ProjectM initialized with " << m_presetPaths.size()
                  << " presets (" << (m_directGL ? "direct GL" : "CPU readback") << " mode)"
                  << std::endl;
        return true;

    } catch (const std::exception& e) {
        std::cerr << "Exception during projectM init: " << e.what() << std::endl;
        return false;
    }
}

void ProjectMVisualizer::shutdown() {
    if (m_projectM) {
        delete m_projectM;
        m_projectM = nullptr;
    }
    m_presetPaths.clear();
    m_presetNames.clear();
    m_frameBuffer.clear();
    m_audioBuffer.clear();
    m_initialized = false;
}

void ProjectMVisualizer::scanPresets() {
    m_presetPaths.clear();
    m_presetNames.clear();

    std::string presetDir = "/usr/share/projectM/presets";
    try {
        for (const auto& entry : fs::recursive_directory_iterator(presetDir)) {
            if (!entry.is_regular_file()) continue;
            std::string ext = entry.path().extension().string();
            if (ext == ".milk" || ext == ".prjm") {
                m_presetPaths.push_back(entry.path().string());
                m_presetNames.push_back(entry.path().stem().string());
            }
        }
        std::cout << "Found " << m_presetPaths.size() << " projectM presets" << std::endl;
    } catch (const std::exception& e) {
        std::cerr << "Error scanning presets: " << e.what() << std::endl;
    }
}

bool ProjectMVisualizer::loadPlugin(const std::string& presetName) {
    if (!m_initialized || !m_projectM) return false;

    auto it = std::find(m_presetNames.begin(), m_presetNames.end(), presetName);
    if (it != m_presetNames.end()) {
        return loadPresetByIndex(std::distance(m_presetNames.begin(), it));
    }
    std::cerr << "Preset not found: " << presetName << std::endl;
    return false;
}

bool ProjectMVisualizer::loadPresetByIndex(unsigned int index) {
    if (index >= m_presetPaths.size() || !m_projectM) return false;
    try {
        m_projectM->selectPreset(index);
        std::cout << "Loaded preset: " << m_presetNames[index] << std::endl;
        return true;
    } catch (const std::exception& e) {
        std::cerr << "Failed to load preset: " << e.what() << std::endl;
        return false;
    }
}

std::vector<std::string> ProjectMVisualizer::getAvailablePlugins() {
    return m_presetNames;
}

bool ProjectMVisualizer::processAudio(const float* audioData, size_t samples) {
    if (!m_initialized || !m_projectM || !audioData) return false;
    try {
        m_projectM->pcm()->addPCMfloat(const_cast<float*>(audioData), samples);
        return true;
    } catch (const std::exception& e) {
        std::cerr << "Error processing audio: " << e.what() << std::endl;
        return false;
    }
}

bool ProjectMVisualizer::render() {
    if (!m_initialized || !m_projectM) return false;

    try {
        if (m_directGL) {
            // Ensure our shared context is current before rendering
            glXMakeCurrent(m_glDisplay, m_glWindow, m_glContext);
        }

        m_projectM->renderFrame();

        if (!m_directGL) {
            // CPU readback fallback — used only when no GLX context was provided
            glReadPixels(0, 0, m_width, m_height, GL_RGB, GL_UNSIGNED_BYTE,
                         m_frameBuffer.data());
        }
        // In direct GL mode the frame is already in the window's back-buffer;
        // the render loop calls swapBuffers() on DesktopRenderer.
        return true;
    } catch (const std::exception& e) {
        std::cerr << "Error rendering frame: " << e.what() << std::endl;
        return false;
    }
}

unsigned char* ProjectMVisualizer::getVideoData() {
    if (m_directGL || !m_initialized || m_frameBuffer.empty()) return nullptr;
    return m_frameBuffer.data();
}
