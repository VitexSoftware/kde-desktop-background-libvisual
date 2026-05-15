#include "desktop_renderer.h"
#include <iostream>
#include <cstring>
#include <cstdlib>

DesktopRenderer::DesktopRenderer()
    : m_display(nullptr), m_rootWindow(0), m_backgroundWindow(0),
      m_gc(nullptr), m_image(nullptr), m_visualInfo(nullptr),
      m_screenWidth(0), m_screenHeight(0), m_screen(0),
      m_imageData(nullptr), m_initialized(false),
      m_glContext(nullptr), m_texture(0), m_glInitialized(false) {
}

DesktopRenderer::~DesktopRenderer() {
    shutdown();
}

bool DesktopRenderer::initialize() {
    m_display = XOpenDisplay(nullptr);
    if (!m_display) {
        std::cerr << "Failed to open X11 display" << std::endl;
        return false;
    }

    m_screen = DefaultScreen(m_display);
    m_rootWindow = RootWindow(m_display, m_screen);
    m_screenWidth = DisplayWidth(m_display, m_screen);
    m_screenHeight = DisplayHeight(m_display, m_screen);

    if (!createBackgroundWindow()) {
        return false;
    }

    // Try to initialize OpenGL — fall back to software path if unavailable
    if (!initializeGL()) {
        std::cerr << "GLX unavailable, falling back to software rendering" << std::endl;

        m_gc = XCreateGC(m_display, m_backgroundWindow, 0, nullptr);
        if (!m_gc) {
            std::cerr << "Failed to create graphics context" << std::endl;
            return false;
        }

        int depth = DefaultDepth(m_display, m_screen);
        m_imageData = new unsigned char[m_screenWidth * m_screenHeight * 4];
        m_image = XCreateImage(m_display, DefaultVisual(m_display, m_screen),
                               depth, ZPixmap, 0, (char*)m_imageData,
                               m_screenWidth, m_screenHeight, 32, 0);
        if (!m_image) {
            std::cerr << "Failed to create XImage" << std::endl;
            return false;
        }
    }

    m_initialized = true;
    return true;
}

bool DesktopRenderer::createBackgroundWindow() {
    // Prefer a GLX-capable visual; fall back to the default visual if GLX is absent
    int glAttribs[] = { GLX_RGBA, GLX_DEPTH_SIZE, 24, GLX_DOUBLEBUFFER, 0 }; // 0 == X11 None
    m_visualInfo = glXChooseVisual(m_display, m_screen, glAttribs);

    Visual* visual = m_visualInfo ? m_visualInfo->visual : DefaultVisual(m_display, m_screen);
    int depth       = m_visualInfo ? m_visualInfo->depth : DefaultDepth(m_display, m_screen);

    Colormap cmap = XCreateColormap(m_display, m_rootWindow, visual, AllocNone);

    XSetWindowAttributes attrs{};
    attrs.colormap       = cmap;
    attrs.border_pixel   = 0;
    attrs.override_redirect = True;
    attrs.background_pixel  = BlackPixel(m_display, m_screen);

    unsigned long mask = CWColormap | CWBorderPixel | CWOverrideRedirect | CWBackPixel;

    m_backgroundWindow = XCreateWindow(
        m_display, m_rootWindow,
        0, 0, m_screenWidth, m_screenHeight, 0,
        depth, InputOutput, visual, mask, &attrs);

    XFreeColormap(m_display, cmap);

    if (!m_backgroundWindow) {
        std::cerr << "Failed to create background window" << std::endl;
        return false;
    }

    Atom atomType  = XInternAtom(m_display, "_NET_WM_WINDOW_TYPE", False);
    Atom typeDesk  = XInternAtom(m_display, "_NET_WM_WINDOW_TYPE_DESKTOP", False);
    XChangeProperty(m_display, m_backgroundWindow, atomType, XA_ATOM, 32,
                    PropModeReplace, (unsigned char*)&typeDesk, 1);

    Atom atomState = XInternAtom(m_display, "_NET_WM_STATE", False);
    Atom stateBelow = XInternAtom(m_display, "_NET_WM_STATE_BELOW", False);
    XChangeProperty(m_display, m_backgroundWindow, atomState, XA_ATOM, 32,
                    PropModeReplace, (unsigned char*)&stateBelow, 1);

    XMapWindow(m_display, m_backgroundWindow);
    XLowerWindow(m_display, m_backgroundWindow);
    return true;
}

bool DesktopRenderer::initializeGL() {
    if (!m_visualInfo) return false;

    m_glContext = glXCreateContext(m_display, m_visualInfo, nullptr, GL_TRUE);
    if (!m_glContext) {
        std::cerr << "Failed to create GLX context" << std::endl;
        return false;
    }

    if (!glXMakeCurrent(m_display, m_backgroundWindow, m_glContext)) {
        std::cerr << "Failed to make GLX context current" << std::endl;
        glXDestroyContext(m_display, m_glContext);
        m_glContext = nullptr;
        return false;
    }

    glEnable(GL_TEXTURE_2D);
    glGenTextures(1, &m_texture);
    glBindTexture(GL_TEXTURE_2D, m_texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glViewport(0, 0, m_screenWidth, m_screenHeight);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, 1, 0, 1, -1, 1);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    m_glInitialized = true;
    std::cout << "GLX context created — hardware-accelerated rendering enabled" << std::endl;
    return true;
}

void DesktopRenderer::shutdown() {
    shutdownGL();

    if (m_image) {
        m_image->data = nullptr;
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

    if (m_visualInfo) {
        XFree(m_visualInfo);
        m_visualInfo = nullptr;
    }
    if (m_display) {
        XCloseDisplay(m_display);
        m_display = nullptr;
    }

    m_initialized = false;
}

void DesktopRenderer::shutdownGL() {
    if (!m_glInitialized) return;

    if (m_texture) {
        glDeleteTextures(1, &m_texture);
        m_texture = 0;
    }
    if (m_glContext) {
        glXMakeCurrent(m_display, 0, nullptr); // 0 == X11 None (undefed to avoid Qt conflict)
        glXDestroyContext(m_display, m_glContext);
        m_glContext = nullptr;
    }
    m_glInitialized = false;
}

bool DesktopRenderer::renderFrame(const unsigned char* data, int width, int height) {
    if (!m_initialized || !data) return false;

    if (m_glInitialized) {
        return renderFrameGL(data, width, height);
    }
    return renderFrameSW(data, width, height);
}

// Upload a CPU pixel buffer as a texture and draw it as a fullscreen quad.
// This is faster than XPutImage because the GPU handles the blit asynchronously.
bool DesktopRenderer::renderFrameGL(const unsigned char* data, int width, int height) {
    glXMakeCurrent(m_display, m_backgroundWindow, m_glContext);

    glBindTexture(GL_TEXTURE_2D, m_texture);

    // libvisual gives us RGB; upload and let the GPU scale to screen size
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0,
                 GL_RGB, GL_UNSIGNED_BYTE, data);

    glClear(GL_COLOR_BUFFER_BIT);
    glBegin(GL_QUADS);
        glTexCoord2f(0.0f, 1.0f); glVertex2f(0.0f, 0.0f);
        glTexCoord2f(1.0f, 1.0f); glVertex2f(1.0f, 0.0f);
        glTexCoord2f(1.0f, 0.0f); glVertex2f(1.0f, 1.0f);
        glTexCoord2f(0.0f, 0.0f); glVertex2f(0.0f, 1.0f);
    glEnd();

    glXSwapBuffers(m_display, m_backgroundWindow);
    return true;
}

bool DesktopRenderer::renderFrameSW(const unsigned char* data, int width, int height) {
    for (int y = 0; y < m_screenHeight; ++y) {
        for (int x = 0; x < m_screenWidth; ++x) {
            int srcX = x % width;
            int srcY = y % height;
            int srcIndex = (srcY * width + srcX) * 3;
            int dstIndex = (y * m_screenWidth + x) * 4;

            if (srcIndex + 2 < width * height * 3) {
                m_imageData[dstIndex + 2] = data[srcIndex];
                m_imageData[dstIndex + 1] = data[srcIndex + 1];
                m_imageData[dstIndex + 0] = data[srcIndex + 2];
                m_imageData[dstIndex + 3] = 255;
            }
        }
    }

    XPutImage(m_display, m_backgroundWindow, m_gc, m_image,
              0, 0, 0, 0, m_screenWidth, m_screenHeight);
    XFlush(m_display);
    return true;
}

// Called by the render loop when an engine draws directly into the GL context
// (e.g. projectM in direct-GL mode) — just present the frame.
void DesktopRenderer::swapBuffers() {
    if (m_glInitialized) {
        glXSwapBuffers(m_display, m_backgroundWindow);
    }
}

void DesktopRenderer::getScreenSize(int& width, int& height) {
    width  = m_screenWidth;
    height = m_screenHeight;
}

void DesktopRenderer::destroyWindow() {
    if (m_backgroundWindow && m_display) {
        XDestroyWindow(m_display, m_backgroundWindow);
        m_backgroundWindow = 0;
    }
}
