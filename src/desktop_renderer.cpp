#include "desktop_renderer.h"
#include <iostream>
#include <cstring>
#include <cstdlib>

DesktopRenderer::DesktopRenderer() 
    : m_display(nullptr), m_rootWindow(0), m_backgroundWindow(0), 
      m_gc(nullptr), m_image(nullptr), m_imageData(nullptr), m_initialized(false) {
}

DesktopRenderer::~DesktopRenderer() {
    shutdown();
}

bool DesktopRenderer::initialize() {
    // Open X11 display
    m_display = XOpenDisplay(nullptr);
    if (!m_display) {
        std::cerr << "Failed to open X11 display" << std::endl;
        return false;
    }

    m_screen = DefaultScreen(m_display);
    m_rootWindow = RootWindow(m_display, m_screen);
    
    // Get screen dimensions
    m_screenWidth = DisplayWidth(m_display, m_screen);
    m_screenHeight = DisplayHeight(m_display, m_screen);

    // Create background window
    if (!createBackgroundWindow()) {
        return false;
    }

    // Create graphics context
    m_gc = XCreateGC(m_display, m_backgroundWindow, 0, nullptr);
    if (!m_gc) {
        std::cerr << "Failed to create graphics context" << std::endl;
        return false;
    }

    // Allocate image data
    int depth = DefaultDepth(m_display, m_screen);
    m_imageData = new unsigned char[m_screenWidth * m_screenHeight * 4];

    // Create XImage
    m_image = XCreateImage(m_display, DefaultVisual(m_display, m_screen),
                          depth, ZPixmap, 0, (char*)m_imageData,
                          m_screenWidth, m_screenHeight, 32, 0);

    if (!m_image) {
        std::cerr << "Failed to create XImage" << std::endl;
        return false;
    }

    m_initialized = true;
    return true;
}

void DesktopRenderer::shutdown() {
    if (m_image) {
        m_image->data = nullptr; // Prevent XDestroyImage from freeing our buffer
        XDestroyImage(m_image);
        m_image = nullptr;
    }

    if (m_imageData) {
        delete[] m_imageData;
        m_imageData = nullptr;
    }

    if (m_gc) {
        XFreeGC(m_display, m_gc);
        m_gc = nullptr;
    }

    destroyWindow();

    if (m_display) {
        XCloseDisplay(m_display);
        m_display = nullptr;
    }

    m_initialized = false;
}

bool DesktopRenderer::renderFrame(const unsigned char* data, int width, int height) {
    if (!m_initialized || !data) {
        return false;
    }

    // Scale/copy the visualization data to screen size
    // For simplicity, we'll just tile the visualization if it's smaller than screen
    for (int y = 0; y < m_screenHeight; ++y) {
        for (int x = 0; x < m_screenWidth; ++x) {
            int srcX = x % width;
            int srcY = y % height;
            int srcIndex = (srcY * width + srcX) * 3; // Assuming RGB data
            int dstIndex = (y * m_screenWidth + x) * 4; // RGBA

            if (srcIndex + 2 < width * height * 3) {
                m_imageData[dstIndex + 2] = data[srcIndex];     // R
                m_imageData[dstIndex + 1] = data[srcIndex + 1]; // G
                m_imageData[dstIndex + 0] = data[srcIndex + 2]; // B
                m_imageData[dstIndex + 3] = 255;                 // A
            }
        }
    }

    // Put image to window
    XPutImage(m_display, m_backgroundWindow, m_gc, m_image, 
              0, 0, 0, 0, m_screenWidth, m_screenHeight);
    
    XFlush(m_display);
    return true;
}

void DesktopRenderer::getScreenSize(int& width, int& height) {
    width = m_screenWidth;
    height = m_screenHeight;
}

bool DesktopRenderer::createBackgroundWindow() {
    XSetWindowAttributes attrs;
    attrs.override_redirect = True;
    attrs.background_pixel = BlackPixel(m_display, m_screen);
    
    unsigned long valuemask = CWOverrideRedirect | CWBackPixel;

    m_backgroundWindow = XCreateWindow(
        m_display, m_rootWindow,
        0, 0, m_screenWidth, m_screenHeight, 0,
        DefaultDepth(m_display, m_screen), InputOutput,
        DefaultVisual(m_display, m_screen),
        valuemask, &attrs
    );

    if (!m_backgroundWindow) {
        std::cerr << "Failed to create background window" << std::endl;
        return false;
    }

    // Set window to be on desktop background layer
    Atom atom = XInternAtom(m_display, "_NET_WM_WINDOW_TYPE", False);
    Atom value = XInternAtom(m_display, "_NET_WM_WINDOW_TYPE_DESKTOP", False);
    XChangeProperty(m_display, m_backgroundWindow, atom, XA_ATOM, 32,
                   PropModeReplace, (unsigned char*)&value, 1);

    // Set window below all others
    atom = XInternAtom(m_display, "_NET_WM_STATE", False);
    value = XInternAtom(m_display, "_NET_WM_STATE_BELOW", False);
    XChangeProperty(m_display, m_backgroundWindow, atom, XA_ATOM, 32,
                   PropModeReplace, (unsigned char*)&value, 1);

    XMapWindow(m_display, m_backgroundWindow);
    XLowerWindow(m_display, m_backgroundWindow);

    return true;
}

void DesktopRenderer::destroyWindow() {
    if (m_backgroundWindow && m_display) {
        XDestroyWindow(m_display, m_backgroundWindow);
        m_backgroundWindow = 0;
    }
}