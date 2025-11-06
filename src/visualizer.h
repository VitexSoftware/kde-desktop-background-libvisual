#ifndef VISUALIZER_H
#define VISUALIZER_H

#include <libvisual/libvisual.h>
#include <vector>
#include <string>
#include <memory>

class Visualizer {
public:
    Visualizer();
    ~Visualizer();

    bool initialize(int width, int height);
    void shutdown();

    bool loadPlugin(const std::string& pluginName);
    std::vector<std::string> getAvailablePlugins();

    bool processAudio(const float* audioData, size_t samples);
    bool render();

    unsigned char* getVideoData();
    int getWidth() const { return m_width; }
    int getHeight() const { return m_height; }

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