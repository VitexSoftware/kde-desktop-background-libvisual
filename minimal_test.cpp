#include <iostream>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <unistd.h>
#include <cstdlib>
#include <cmath>

class MinimalVisualizerApp {
private:
    Display* m_display;
    Window m_window;
    GC m_gc;
    int m_width, m_height;
    bool m_running;
    unsigned char* m_frameBuffer;

public:
    MinimalVisualizerApp() : m_display(nullptr), m_window(0), m_gc(nullptr), 
                            m_running(false), m_frameBuffer(nullptr) {
    }

    ~MinimalVisualizerApp() {
        cleanup();
    }

    bool initialize() {
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

        // Allocate frame buffer
        m_frameBuffer = new unsigned char[m_width * m_height * 3];

        return true;
    }

    void run() {
        m_running = true;
        
        std::cout << "Minimal visualizer running. Press Ctrl+C to exit..." << std::endl;
        
        XEvent event;
        int frame = 0;
        
        while (m_running) {
            // Check for X11 events
            while (XPending(m_display)) {
                XNextEvent(m_display, &event);
                if (event.type == KeyPress) {
                    m_running = false;
                    break;
                }
            }

            // Generate simple animated pattern
            generatePattern(frame);

            // Create and display image
            XImage* image = XCreateImage(m_display, DefaultVisual(m_display, DefaultScreen(m_display)),
                                       DefaultDepth(m_display, DefaultScreen(m_display)), 
                                       ZPixmap, 0, (char*)m_frameBuffer,
                                       m_width, m_height, 8, 0);

            XPutImage(m_display, m_window, m_gc, image, 0, 0, 0, 0, m_width, m_height);
            image->data = nullptr; // Prevent XDestroyImage from freeing our buffer
            XDestroyImage(image);
            XFlush(m_display);

            frame++;
            usleep(50000); // ~20 FPS
        }
    }

private:
    void generatePattern(int frame) {
        for (int y = 0; y < m_height; ++y) {
            for (int x = 0; x < m_width; ++x) {
                int index = (y * m_width + x) * 3;
                
                // Simple animated sine wave pattern
                double dx = (x - m_width/2.0) / (m_width/4.0);
                double dy = (y - m_height/2.0) / (m_height/4.0);
                double dist = sqrt(dx*dx + dy*dy);
                double wave = sin(dist * 2 - frame * 0.1) * 0.5 + 0.5;
                
                // Color based on wave
                m_frameBuffer[index + 0] = (unsigned char)(wave * 255); // R
                m_frameBuffer[index + 1] = (unsigned char)(wave * 128); // G  
                m_frameBuffer[index + 2] = (unsigned char)(wave * 64);  // B
            }
        }
    }

    void cleanup() {
        m_running = false;

        if (m_frameBuffer) {
            delete[] m_frameBuffer;
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
    std::cout << "Minimal Desktop Background Visualizer" << std::endl;
    std::cout << "This demonstrates basic X11 desktop rendering..." << std::endl;

    MinimalVisualizerApp app;
    
    if (!app.initialize()) {
        std::cerr << "Failed to initialize application" << std::endl;
        return 1;
    }

    app.run();
    return 0;
}