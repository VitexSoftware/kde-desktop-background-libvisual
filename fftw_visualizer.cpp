#include <fftw3.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <pulse/simple.h>
#include <pulse/error.h>
#include <iostream>
#include <vector>
#include <thread>
#include <atomic>
#include <chrono>
#include <cmath>
#include <algorithm>

class FFTWVisualizer {
private:
    Display* m_display;
    Window m_window;
    GC m_gc;
    XImage* m_image;
    int m_width, m_height;
    int m_screen;
    unsigned char* m_imageData;
    
    // Audio processing
    pa_simple* m_pulseAudio;
    std::thread m_audioThread;
    std::atomic<bool> m_running;
    
    // FFTW data
    std::vector<double> m_audioBuffer;
    std::vector<double> m_fftInput;
    fftw_complex* m_fftOutput;
    fftw_plan m_fftPlan;
    std::vector<double> m_spectrum;
    std::vector<double> m_smoothSpectrum;
    
    static constexpr int AUDIO_BUFFER_SIZE = 1024;
    static constexpr int FFT_SIZE = 512;
    static constexpr int SPECTRUM_BARS = 128;

public:
    FFTWVisualizer() : m_display(nullptr), m_window(0), m_gc(nullptr), 
                       m_image(nullptr), m_pulseAudio(nullptr), m_running(false),
                       m_imageData(nullptr), m_fftOutput(nullptr) {
        m_audioBuffer.resize(AUDIO_BUFFER_SIZE);
        m_fftInput.resize(FFT_SIZE);
        m_fftOutput = (fftw_complex*)fftw_malloc(sizeof(fftw_complex) * FFT_SIZE);
        m_spectrum.resize(SPECTRUM_BARS, 0.0);
        m_smoothSpectrum.resize(SPECTRUM_BARS, 0.0);
        
        // Create FFTW plan
        m_fftPlan = fftw_plan_dft_r2c_1d(FFT_SIZE, m_fftInput.data(), m_fftOutput, FFTW_ESTIMATE);
    }
    
    ~FFTWVisualizer() {
        cleanup();
        if (m_fftPlan) {
            fftw_destroy_plan(m_fftPlan);
        }
        if (m_fftOutput) {
            fftw_free(m_fftOutput);
        }
        fftw_cleanup();
    }
    
    bool initialize() {
        // Initialize X11
        m_display = XOpenDisplay(nullptr);
        if (!m_display) {
            std::cerr << "Failed to open X11 display" << std::endl;
            return false;
        }
        
        m_screen = DefaultScreen(m_display);
        m_width = DisplayWidth(m_display, m_screen);
        m_height = DisplayHeight(m_display, m_screen);
        
        std::cout << "Screen dimensions: " << m_width << "x" << m_height << std::endl;
        
        // Create fullscreen window
        m_window = XCreateSimpleWindow(m_display, RootWindow(m_display, m_screen),
                                      0, 0, m_width, m_height, 0,
                                      BlackPixel(m_display, m_screen),
                                      BlackPixel(m_display, m_screen));
        
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
        int depth = DefaultDepth(m_display, m_screen);
        m_imageData = new unsigned char[m_width * m_height * 4];
        m_image = XCreateImage(m_display, DefaultVisual(m_display, m_screen),
                              depth, ZPixmap, 0, (char*)m_imageData,
                              m_width, m_height, 32, 0);
        
        // Initialize PulseAudio
        pa_sample_spec ss;
        ss.format = PA_SAMPLE_S16LE;
        ss.channels = 2;
        ss.rate = 44100;
        
        pa_buffer_attr attr;
        attr.maxlength = AUDIO_BUFFER_SIZE * sizeof(int16_t) * 2 * 4;
        attr.fragsize = AUDIO_BUFFER_SIZE * sizeof(int16_t) * 2;
        attr.tlength = (uint32_t) -1;
        attr.prebuf = (uint32_t) -1;
        attr.minreq = (uint32_t) -1;
        
        int error;
        m_pulseAudio = pa_simple_new(nullptr, "FFTW Visualizer", PA_STREAM_RECORD,
                                    nullptr, "Visualization", &ss, nullptr, &attr, &error);
        
        if (!m_pulseAudio) {
            std::cerr << "Failed to create PulseAudio connection: " << pa_strerror(error) << std::endl;
            return false;
        }
        
        std::cout << "FFTW Visualizer initialized successfully!" << std::endl;
        return true;
    }
    
    void run() {
        m_running = true;
        
        // Start audio thread
        m_audioThread = std::thread(&FFTWVisualizer::audioLoop, this);
        
        // Main render loop
        XEvent event;
        
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
            renderFrame();
            
            std::this_thread::sleep_for(std::chrono::milliseconds(16)); // ~60 FPS
        }
        
        // Wait for audio thread to finish
        if (m_audioThread.joinable()) {
            m_audioThread.join();
        }
    }

private:
    void audioLoop() {
        std::vector<int16_t> buffer(AUDIO_BUFFER_SIZE);
        
        while (m_running) {
            int error;
            if (pa_simple_read(m_pulseAudio, buffer.data(), 
                              buffer.size() * sizeof(int16_t), &error) < 0) {
                std::cerr << "Failed to read audio: " << pa_strerror(error) << std::endl;
                break;
            }
            
            // Process audio data
            processAudio(buffer);
        }
    }
    
    void processAudio(const std::vector<int16_t>& audioData) {
        // Convert to double and prepare for FFT
        for (int i = 0; i < FFT_SIZE && i < audioData.size(); ++i) {
            m_fftInput[i] = static_cast<double>(audioData[i]) / 32768.0;
        }
        
        // Perform FFT
        fftw_execute(m_fftPlan);
        
        // Calculate spectrum magnitudes
        for (int i = 0; i < SPECTRUM_BARS; ++i) {
            int fftIndex = i * (FFT_SIZE / 2) / SPECTRUM_BARS;
            if (fftIndex < FFT_SIZE / 2) {
                double real = m_fftOutput[fftIndex][0];
                double imag = m_fftOutput[fftIndex][1];
                double magnitude = sqrt(real * real + imag * imag);
                
                // Smooth the spectrum
                m_smoothSpectrum[i] = 0.8 * m_smoothSpectrum[i] + 0.2 * magnitude;
            }
        }
    }
    
    void renderFrame() {
        // Clear the image
        std::fill(m_imageData, m_imageData + m_width * m_height * 4, 0);
        
        // Draw spectrum bars
        int barWidth = m_width / SPECTRUM_BARS;
        
        for (int i = 0; i < SPECTRUM_BARS; ++i) {
            double intensity = m_smoothSpectrum[i];
            
            // Logarithmic scaling
            intensity = log10(1.0 + intensity * 9.0);
            
            int barHeight = static_cast<int>(intensity * m_height * 0.8);
            barHeight = std::min(barHeight, m_height);
            
            // Color based on frequency (low = red, mid = green, high = blue)
            int red = 255 - (i * 255 / SPECTRUM_BARS);
            int green = (i < SPECTRUM_BARS / 2) ? (i * 255 * 2 / SPECTRUM_BARS) : 255 - ((i - SPECTRUM_BARS / 2) * 255 * 2 / SPECTRUM_BARS);
            int blue = (i * 255 / SPECTRUM_BARS);
            
            // Draw bar
            int x = i * barWidth;
            int y = m_height - barHeight;
            
            for (int px = x; px < x + barWidth - 1 && px < m_width; ++px) {
                for (int py = y; py < m_height && py >= 0; ++py) {
                    int pixelIndex = (py * m_width + px) * 4;
                    m_imageData[pixelIndex + 0] = blue;  // B
                    m_imageData[pixelIndex + 1] = green; // G
                    m_imageData[pixelIndex + 2] = red;   // R
                    m_imageData[pixelIndex + 3] = 255;   // A
                }
            }
        }
        
        // Update X11 display
        XPutImage(m_display, m_window, m_gc, m_image, 0, 0, 0, 0, m_width, m_height);
        XFlush(m_display);
    }
    
    void cleanup() {
        m_running = false;
        
        if (m_audioThread.joinable()) {
            m_audioThread.join();
        }
        
        if (m_pulseAudio) {
            pa_simple_free(m_pulseAudio);
        }
        
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

int main() {
    std::cout << "FFTW3 Audio Visualizer for KDE Desktop Background" << std::endl;
    std::cout << "Press any key to exit..." << std::endl;
    
    FFTWVisualizer visualizer;
    
    if (!visualizer.initialize()) {
        std::cerr << "Failed to initialize visualizer" << std::endl;
        return 1;
    }
    
    visualizer.run();
    return 0;
}