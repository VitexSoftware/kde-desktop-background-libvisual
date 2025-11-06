#ifndef AUDIO_INPUT_H
#define AUDIO_INPUT_H

#include <pulse/simple.h>
#include <pulse/error.h>
#include <thread>
#include <atomic>
#include <vector>
#include <functional>
#include <string>

class AudioInput {
public:
    AudioInput();
    ~AudioInput();

    bool initialize(const std::string& device = std::string("default"));
    void start();
    void stop();
    bool isRunning() const;

    // Set callback for audio data
    void setAudioCallback(std::function<void(const float*, size_t)> callback);

    // Get available audio devices
    std::vector<std::string> getAvailableDevices();

private:
    void audioThread();
    void convertToFloat(const int16_t* input, float* output, size_t samples);

    pa_simple* m_pulseAudio;
    std::thread m_audioThread;
    std::atomic<bool> m_running;
    std::atomic<bool> m_shouldStop;
    
    std::function<void(const float*, size_t)> m_audioCallback;
    
    static const size_t BUFFER_SIZE = 1024;
    static const int SAMPLE_RATE = 44100;
    static const int CHANNELS = 2;
};

#endif // AUDIO_INPUT_H