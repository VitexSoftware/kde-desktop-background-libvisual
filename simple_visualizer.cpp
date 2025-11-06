#include <libvisual/libvisual.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <pulse/simple.h>
#include <pulse/error.h>
#include <iostream>
#include <vector>
#include <thread>
#include <chrono>
#include <atomic>
#include <cstring>

class SimpleVisualizerApp {
private:
    Display* m_display;
    Window m_window;
    GC m_gc;
    XImage* m_image;
    int m_width, m_height;
    
    VisVideo* m_video;
    VisAudio* m_audio;
    VisActor* m_actor;
    VisAudioSamplePool* m_samplePool;
    
    pa_simple* m_pulseAudio;
    std::thread m_audioThread;
    std::atomic<bool> m_running;
    
    unsigned char* m_imageData;

public:
    SimpleVisualizerApp() : m_display(nullptr), m_window(0), m_gc(nullptr), 
                           m_image(nullptr), m_video(nullptr), m_audio(nullptr), 
                           m_actor(nullptr), m_samplePool(nullptr), m_pulseAudio(nullptr), 
                           m_running(false), m_imageData(nullptr) {
    }

    ~SimpleVisualizerApp() {
        cleanup();
    }

    bool initialize(int argc, char* argv[]) {
        // Initialize X11
        m_display = XOpenDisplay(nullptr);
        if (!m_display) {
            std::cerr << "Failed to open X11 display" << std::endl;
            return false;
        }

        int screen = DefaultScreen(m_display);
        m_width = DisplayWidth(m_display, screen);
        m_height = DisplayHeight(m_display, screen);

        // Create fullscreen window
        m_window = XCreateSimpleWindow(m_display, RootWindow(m_display, screen),
                                      0, 0, m_width, m_height, 0,
                                      BlackPixel(m_display, screen),
                                      BlackPixel(m_display, screen));

        // Set window properties for desktop background
        XSetWindowAttributes attrs;
        attrs.override_redirect = True;
        XChangeWindowAttributes(m_display, m_window, CWOverrideRedirect, &attrs);

        // Set as desktop background
        Atom atom = XInternAtom(m_display, "_NET_WM_WINDOW_TYPE", False);
        Atom value = XInternAtom(m_display, "_NET_WM_WINDOW_TYPE_DESKTOP", False);
        XChangeProperty(m_display, m_window, atom, XA_ATOM, 32,
                       PropModeReplace, (unsigned char*)&value, 1);

        XMapWindow(m_display, m_window);
        XLowerWindow(m_display, m_window);

        m_gc = XCreateGC(m_display, m_window, 0, nullptr);

        // Create image
        int depth = DefaultDepth(m_display, screen);
        m_imageData = new unsigned char[m_width * m_height * 4];
        m_image = XCreateImage(m_display, DefaultVisual(m_display, screen),
                              depth, ZPixmap, 0, (char*)m_imageData,
                              m_width, m_height, 32, 0);

        // Initialize libvisual
        if (visual_init(&argc, &argv) != VISUAL_OK) {
            std::cerr << "Failed to initialize libvisual" << std::endl;
            return false;
        }

        m_video = visual_video_new();
        visual_video_set_dimension(m_video, m_width, m_height);
        visual_video_set_depth(m_video, VISUAL_VIDEO_DEPTH_24BIT);
        visual_video_allocate_buffer(m_video);

        m_audio = visual_audio_new();

        // Get the built-in samplepool from audio object
        m_samplePool = m_audio->samplepool;

        // Load a visualization plugin
        m_actor = visual_actor_new("gforce");
        if (!m_actor) {
            // Try alternative plugins
            const char* plugins[] = {"infinite", "jakdaw", "lv_scope", nullptr};
            for (int i = 0; plugins[i] && !m_actor; ++i) {
                m_actor = visual_actor_new(plugins[i]);
            }
        }

        if (!m_actor) {
            std::cerr << "Failed to load any visualization plugin" << std::endl;
            return false;
        }

        visual_actor_realize(m_actor);
        visual_actor_set_video(m_actor, m_video);

        // Initialize PulseAudio
        pa_sample_spec ss;
        ss.format = PA_SAMPLE_S16LE;
        ss.channels = 2;
        ss.rate = 44100;

        pa_buffer_attr attr;
        attr.maxlength = 1024 * sizeof(int16_t) * 2 * 4;
        attr.fragsize = 1024 * sizeof(int16_t) * 2;
        attr.tlength = (uint32_t) -1;
        attr.prebuf = (uint32_t) -1;
        attr.minreq = (uint32_t) -1;

        int error;
        m_pulseAudio = pa_simple_new(nullptr, "Simple Visualizer", PA_STREAM_RECORD,
                                    nullptr, "Visualization", &ss, nullptr, &attr, &error);

        if (!m_pulseAudio) {
            std::cerr << "Failed to create PulseAudio connection: " << pa_strerror(error) << std::endl;
            return false;
        }

        return true;
    }

    void run() {
        m_running = true;
        
        // Start audio thread
        m_audioThread = std::thread(&SimpleVisualizerApp::audioLoop, this);

        // Main render loop
        XEvent event;
        std::vector<int16_t> audioBuffer(1024);
        
        while (m_running) {
            // Check for X11 events
            while (XPending(m_display)) {
                XNextEvent(m_display, &event);
                if (event.type == KeyPress) {
                    m_running = false;
                    break;
                }
            }

            // Render visualization
            if (visual_actor_run(m_actor, m_audio) == VISUAL_OK) {
                unsigned char* videoData = static_cast<unsigned char*>(visual_video_get_pixels(m_video));
                
                // Convert RGB to BGRA and copy to image data
                for (int y = 0; y < m_height; ++y) {
                    for (int x = 0; x < m_width; ++x) {
                        int srcIndex = (y * m_width + x) * 3;
                        int dstIndex = (y * m_width + x) * 4;
                        
                        m_imageData[dstIndex + 0] = videoData[srcIndex + 2]; // B
                        m_imageData[dstIndex + 1] = videoData[srcIndex + 1]; // G
                        m_imageData[dstIndex + 2] = videoData[srcIndex + 0]; // R
                        m_imageData[dstIndex + 3] = 255;                     // A
                    }
                }

                XPutImage(m_display, m_window, m_gc, m_image, 0, 0, 0, 0, m_width, m_height);
                XFlush(m_display);
            }

            std::this_thread::sleep_for(std::chrono::milliseconds(16)); // ~60 FPS
        }

        // Wait for audio thread to finish
        if (m_audioThread.joinable()) {
            m_audioThread.join();
        }
    }

private:
    void audioLoop() {
        std::vector<int16_t> buffer(1024);
        
        while (m_running) {
            int error;
            if (pa_simple_read(m_pulseAudio, buffer.data(), 
                              buffer.size() * sizeof(int16_t), &error) < 0) {
                std::cerr << "Failed to read audio: " << pa_strerror(error) << std::endl;
                break;
            }

            // Feed audio to libvisual
            VisBuffer* visBuffer = visual_buffer_new_with_buffer(
                buffer.data(), buffer.size() * sizeof(int16_t), nullptr);
            
            visual_audio_samplepool_input(m_samplePool, visBuffer, VISUAL_AUDIO_SAMPLE_RATE_44100,
                                         VISUAL_AUDIO_SAMPLE_FORMAT_S16, 
                                         VISUAL_AUDIO_SAMPLE_CHANNEL_STEREO);
            
            visual_object_unref(VISUAL_OBJECT(visBuffer));
        }
    }

    void cleanup() {
        m_running = false;

        if (m_audioThread.joinable()) {
            m_audioThread.join();
        }

        if (m_pulseAudio) {
            pa_simple_free(m_pulseAudio);
        }

        if (m_actor) {
            visual_object_unref(VISUAL_OBJECT(m_actor));
        }

        if (m_audio) {
            visual_object_unref(VISUAL_OBJECT(m_audio));
        }

        if (m_video) {
            visual_object_unref(VISUAL_OBJECT(m_video));
        }

        visual_quit();

        if (m_image) {
            m_image->data = nullptr;
            XDestroyImage(m_image);
        }

        if (m_imageData) {
            delete[] m_imageData;
        }

        if (m_gc) {
            XFreeGC(m_display, m_gc);
        }

        if (m_window) {
            XDestroyWindow(m_display, m_window);
        }

        if (m_display) {
            XCloseDisplay(m_display);
        }
    }
};

int main(int argc, char* argv[]) {
    std::cout << "Simple LibVisual Desktop Background Visualizer" << std::endl;
    std::cout << "Press any key to exit..." << std::endl;

    SimpleVisualizerApp app;
    
    if (!app.initialize(argc, argv)) {
        std::cerr << "Failed to initialize application" << std::endl;
        return 1;
    }

    app.run();
    return 0;
}