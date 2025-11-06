#include "visualizer.h"
#include <iostream>
#include <algorithm>

Visualizer::Visualizer() 
    : m_video(nullptr), m_audio(nullptr), m_actor(nullptr), 
      m_samplePool(nullptr), m_width(0), m_height(0), m_initialized(false) {
}

Visualizer::~Visualizer() {
    shutdown();
}

bool Visualizer::initialize(int width, int height) {
    // LibVisual should already be initialized in main
    std::cout << "Initializing visualizer with dimensions: " << width << "x" << height << std::endl;
    
    // Use fixed small size for testing
    width = 800;
    height = 600;
    
    std::cout << "Using test dimensions: " << width << "x" << height << std::endl;
    
    m_width = width;
    m_height = height;

    // Create video object
    m_video = visual_video_new();
    if (!m_video) {
        std::cerr << "Failed to create video object" << std::endl;
        return false;
    }

    // Set video properties
    visual_video_set_dimension(m_video, m_width, m_height);
    visual_video_set_depth(m_video, VISUAL_VIDEO_DEPTH_24BIT);
    
    if (visual_video_allocate_buffer(m_video) != VISUAL_OK) {
        std::cerr << "Failed to allocate video buffer" << std::endl;
        return false;
    }

    // Create audio object
    m_audio = visual_audio_new();
    if (!m_audio) {
        std::cerr << "Failed to create audio object" << std::endl;
        return false;
    }

    // Access internal sample pool from audio object
    // LibVisual VisAudio structure contains a samplepool field
    m_samplePool = m_audio->samplepool;

    m_audioBuffer.resize(1024);
    m_initialized = true;
    return true;
}

void Visualizer::shutdown() {
    if (m_actor) {
        visual_object_unref(VISUAL_OBJECT(m_actor));
        m_actor = nullptr;
    }

    if (m_audio) {
        visual_object_unref(VISUAL_OBJECT(m_audio));
        m_audio = nullptr;
    }

    if (m_video) {
        visual_object_unref(VISUAL_OBJECT(m_video));
        m_video = nullptr;
    }

    if (m_initialized) {
        visual_quit();
        m_initialized = false;
    }
}

bool Visualizer::loadPlugin(const std::string& pluginName) {
    if (!m_initialized) {
        return false;
    }

    // Unload previous plugin
    if (m_actor) {
        visual_object_unref(VISUAL_OBJECT(m_actor));
        m_actor = nullptr;
    }

    // Load new plugin
    m_actor = visual_actor_new(pluginName.c_str());
    if (!m_actor) {
        std::cerr << "Failed to load plugin: " << pluginName << std::endl;
        return false;
    }

    // Realize the plugin
    if (visual_actor_realize(m_actor) != VISUAL_OK) {
        std::cerr << "Failed to realize plugin: " << pluginName << std::endl;
        visual_object_unref(VISUAL_OBJECT(m_actor));
        m_actor = nullptr;
        return false;
    }

    // Connect video
    if (visual_actor_set_video(m_actor, m_video) != VISUAL_OK) {
        std::cerr << "Failed to set video for plugin: " << pluginName << std::endl;
        visual_object_unref(VISUAL_OBJECT(m_actor));
        m_actor = nullptr;
        return false;
    }

    std::cout << "Successfully loaded plugin: " << pluginName << std::endl;
    return true;
}

std::vector<std::string> Visualizer::getAvailablePlugins() {
    std::vector<std::string> plugins;
    
    if (!m_initialized) {
        return plugins;
    }

    VisList* list = visual_actor_get_list();
    if (!list) {
        return plugins;
    }

    // Iterate through list using visual_list_next
    VisListEntry* entry = nullptr;
    while (void* data = visual_list_next(list, &entry)) {
        VisPluginRef* ref = static_cast<VisPluginRef*>(data);
        if (ref && ref->info) {
            plugins.push_back(ref->info->plugname);
        }
    }

    return plugins;
}

bool Visualizer::processAudio(const float* audioData, size_t samples) {
    if (!m_initialized || !m_audio || !audioData) {
        return false;
    }

    // Convert float audio to int16
    size_t samplesToProcess = std::min(samples, m_audioBuffer.size());
    for (size_t i = 0; i < samplesToProcess; ++i) {
        m_audioBuffer[i] = static_cast<int16_t>(audioData[i] * 32767.0f);
    }

    // Feed audio data to libvisual
    VisBuffer* buffer = visual_buffer_new_with_buffer(
        m_audioBuffer.data(), 
        samplesToProcess * sizeof(int16_t), 
        nullptr
    );

    if (!buffer) {
        return false;
    }

    visual_audio_samplepool_input(m_samplePool, buffer, VISUAL_AUDIO_SAMPLE_RATE_44100,
                                 VISUAL_AUDIO_SAMPLE_FORMAT_S16, 
                                 VISUAL_AUDIO_SAMPLE_CHANNEL_STEREO);

    visual_object_unref(VISUAL_OBJECT(buffer));
    return true;
}

bool Visualizer::render() {
    if (!m_initialized || !m_actor || !m_video) {
        return false;
    }

    // Run the visualization
    if (visual_actor_run(m_actor, m_audio) != VISUAL_OK) {
        return false;
    }

    return true;
}

unsigned char* Visualizer::getVideoData() {
    if (!m_video) {
        return nullptr;
    }

    return static_cast<unsigned char*>(visual_video_get_pixels(m_video));
}