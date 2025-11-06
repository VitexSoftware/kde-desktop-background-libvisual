#include "audio_input.h"
#include <iostream>
#include <cstring>
#include <algorithm>

AudioInput::AudioInput() : m_pulseAudio(nullptr), m_running(false), m_shouldStop(false) {
}

AudioInput::~AudioInput() {
    stop();
    if (m_pulseAudio) {
        pa_simple_free(m_pulseAudio);
    }
}

bool AudioInput::initialize(const std::string& device) {
    pa_sample_spec ss;
    ss.format = PA_SAMPLE_S16LE;
    ss.channels = CHANNELS;
    ss.rate = SAMPLE_RATE;

    pa_buffer_attr attr;
    attr.maxlength = BUFFER_SIZE * sizeof(int16_t) * CHANNELS * 4;
    attr.tlength = (uint32_t) -1;
    attr.prebuf = (uint32_t) -1;
    attr.minreq = (uint32_t) -1;
    attr.fragsize = BUFFER_SIZE * sizeof(int16_t) * CHANNELS;

    int error;
    const char* deviceName = (device == "default") ? nullptr : device.c_str();
    
    m_pulseAudio = pa_simple_new(
        nullptr,                    // server
        "libvisual-bg",             // application name
        PA_STREAM_RECORD,           // direction
        deviceName,                 // device
        "Audio Visualization",      // stream description
        &ss,                        // sample spec
        nullptr,                    // channel map
        &attr,                      // buffer attributes
        &error                      // error code
    );

    if (!m_pulseAudio) {
        std::cerr << "Failed to create PulseAudio connection: " << pa_strerror(error) << std::endl;
        return false;
    }

    return true;
}

void AudioInput::start() {
    if (m_running || !m_pulseAudio) {
        return;
    }

    m_shouldStop = false;
    m_running = true;
    m_audioThread = std::thread(&AudioInput::audioThread, this);
}

void AudioInput::stop() {
    if (!m_running) {
        return;
    }

    m_shouldStop = true;
    if (m_audioThread.joinable()) {
        m_audioThread.join();
    }
    m_running = false;
}

bool AudioInput::isRunning() const {
    return m_running;
}

void AudioInput::setAudioCallback(std::function<void(const float*, size_t)> callback) {
    m_audioCallback = callback;
}

std::vector<std::string> AudioInput::getAvailableDevices() {
    // This is a simplified implementation
    // In a real application, you would query PulseAudio for available sources
    return {"default", "alsa_input.pci-0000_00_1f.3.analog-stereo"};
}

void AudioInput::audioThread() {
    std::vector<int16_t> buffer(BUFFER_SIZE * CHANNELS);
    std::vector<float> floatBuffer(BUFFER_SIZE * CHANNELS);

    while (!m_shouldStop) {
        int error;
        if (pa_simple_read(m_pulseAudio, buffer.data(), 
                          buffer.size() * sizeof(int16_t), &error) < 0) {
            std::cerr << "Failed to read audio data: " << pa_strerror(error) << std::endl;
            break;
        }

        // Convert to float and call callback
        convertToFloat(buffer.data(), floatBuffer.data(), buffer.size());
        
        if (m_audioCallback) {
            m_audioCallback(floatBuffer.data(), BUFFER_SIZE);
        }
    }
}

void AudioInput::convertToFloat(const int16_t* input, float* output, size_t samples) {
    for (size_t i = 0; i < samples; ++i) {
        output[i] = static_cast<float>(input[i]) / 32768.0f;
    }
}