#ifndef VISUALIZATION_ENGINE_H
#define VISUALIZATION_ENGINE_H

#include <vector>
#include <string>

/**
 * Abstract interface for visualization engines.
 * Supports both libvisual and projectM implementations.
 */
class VisualizationEngine {
public:
    virtual ~VisualizationEngine() = default;

    /**
     * Initialize the visualization engine with given dimensions.
     * @param width Video width in pixels
     * @param height Video height in pixels
     * @return true on success, false on failure
     */
    virtual bool initialize(int width, int height) = 0;

    /**
     * Shutdown and cleanup the visualization engine.
     */
    virtual void shutdown() = 0;

    /**
     * Load a specific visualization plugin/preset.
     * @param name Plugin or preset name
     * @return true on success, false on failure
     */
    virtual bool loadPlugin(const std::string& name) = 0;

    /**
     * Get list of available plugins/presets.
     * @return Vector of plugin/preset names
     */
    virtual std::vector<std::string> getAvailablePlugins() = 0;

    /**
     * Process audio data for visualization.
     * @param audioData PCM audio data as float array
     * @param samples Number of samples
     * @return true on success, false on failure
     */
    virtual bool processAudio(const float* audioData, size_t samples) = 0;

    /**
     * Render one frame of visualization.
     * @return true on success, false on failure
     */
    virtual bool render() = 0;

    /**
     * Get pointer to rendered video frame data.
     * @return Pointer to RGB/RGBA pixel data
     */
    virtual unsigned char* getVideoData() = 0;

    /**
     * Get current video width.
     * @return Width in pixels
     */
    virtual int getWidth() const = 0;

    /**
     * Get current video height.
     * @return Height in pixels
     */
    virtual int getHeight() const = 0;

    /**
     * Get the engine type name.
     * @return Engine name (e.g., "libvisual" or "projectM")
     */
    virtual std::string getEngineName() const = 0;

    /**
     * Returns true if this engine renders directly into an active OpenGL context
     * rather than producing a CPU pixel buffer.  When true, the caller must call
     * swapBuffers() on the renderer instead of renderFrame(pixel_data).
     */
    virtual bool usesDirectGL() const { return false; }

    /**
     * Provide an existing GLX context so the engine can render directly into
     * the desktop window without a GPU→CPU readback.  Returns true on success.
     * Only implemented by GPU-based engines (e.g. projectM).
     */
    virtual bool setGLContext(void* /*display*/, unsigned long /*window*/,
                              void* /*glxContext*/) { return false; }
};

#endif // VISUALIZATION_ENGINE_H
