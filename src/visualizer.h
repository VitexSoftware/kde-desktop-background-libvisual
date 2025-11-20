#ifndef VISUALIZER_H
#define VISUALIZER_H

#include <libvisual/libvisual.h>
#include <vector>
#include <string>
#include <memory>
#include "visualization_engine.h"

class Visualizer : public VisualizationEngine {
public:
    Visualizer();
    ~Visualizer() override;

    bool initialize(int width, int height) override;
    void shutdown() override;

    bool loadPlugin(const std::string& pluginName) override;
    std::vector<std::string> getAvailablePlugins() override;

    bool processAudio(const float* audioData, size_t samples) override;
    bool render() override;

    unsigned char* getVideoData() override;
    int getWidth() const override { return m_width; }
    int getHeight() const override { return m_height; }
    std::string getEngineName() const override { return "libvisual"; }

private:
    VisVideo* m_video;
    VisAudio* m_audio;
    VisActor* m_actor;
    VisAudioSamplePool* m_samplePool;
    
    int m_width;
    int m_height;
    bool m_initialized;
    
    std::vector<int16_t> m_audioBuffer;
};

#endif // VISUALIZER_H