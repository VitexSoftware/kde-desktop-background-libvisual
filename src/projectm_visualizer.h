#ifndef PROJECTM_VISUALIZER_H
#define PROJECTM_VISUALIZER_H

#include "visualization_engine.h"
#include <GL/glx.h>
#include <X11/Xlib.h>
#include <vector>
#include <string>
#include <memory>

// Forward declare to avoid including projectM.hpp in header
class projectM;

/**
 * ProjectM-based visualization engine implementation.
 * Provides access to 4,188+ Milkdrop-compatible presets.
 *
 * When a GLX context is supplied via setGLContext() the engine renders
 * directly into the desktop window — no GPU→CPU readback via glReadPixels.
 */
class ProjectMVisualizer : public VisualizationEngine {
public:
    ProjectMVisualizer();
    ~ProjectMVisualizer() override;

    bool initialize(int width, int height) override;
    void shutdown() override;

    bool loadPlugin(const std::string& presetName) override;
    std::vector<std::string> getAvailablePlugins() override;

    bool processAudio(const float* audioData, size_t samples) override;
    bool render() override;

    unsigned char* getVideoData() override;
    int getWidth() const override { return m_width; }
    int getHeight() const override { return m_height; }
    std::string getEngineName() const override { return "projectM"; }

    // Direct GL rendering support
    bool usesDirectGL() const override { return m_directGL; }
    bool setGLContext(void* display, unsigned long window, void* glxContext) override;

private:
    void scanPresets();
    bool loadPresetByIndex(unsigned int index);

    projectM* m_projectM;
    std::vector<std::string> m_presetPaths;
    std::vector<std::string> m_presetNames;

    int m_width;
    int m_height;
    bool m_initialized;

    // CPU readback buffer (only used when directGL is false)
    std::vector<unsigned char> m_frameBuffer;
    std::vector<float> m_audioBuffer;

    // Direct GL rendering state
    bool m_directGL;
    Display* m_glDisplay;
    Window m_glWindow;
    GLXContext m_glContext;
};

#endif // PROJECTM_VISUALIZER_H
