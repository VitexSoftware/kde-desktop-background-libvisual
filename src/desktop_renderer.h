#ifndef DESKTOP_RENDERER_H
#define DESKTOP_RENDERER_H

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <GL/glx.h>
#include <GL/gl.h>

// Undefine X11 macros that conflict with Qt
#ifdef None
#undef None
#endif
#ifdef Status
#undef Status
#endif
#ifdef Bool
#undef Bool
#endif

#include <memory>

class DesktopRenderer {
public:
    DesktopRenderer();
    ~DesktopRenderer();

    bool initialize();
    void shutdown();

    bool renderFrame(const unsigned char* data, int width, int height);
    void swapBuffers();
    void getScreenSize(int& width, int& height);

    // GL context accessors for engines that render directly to OpenGL
    Display* getDisplay() const { return m_display; }
    Window getWindow() const { return m_backgroundWindow; }
    GLXContext getGLContext() const { return m_glContext; }
    bool hasGLContext() const { return m_glInitialized; }

private:
    bool createBackgroundWindow();
    bool initializeGL();
    bool renderFrameGL(const unsigned char* data, int width, int height);
    bool renderFrameSW(const unsigned char* data, int width, int height);
    void destroyWindow();
    void shutdownGL();

    Display* m_display;
    Window m_rootWindow;
    Window m_backgroundWindow;
    GC m_gc;
    XImage* m_image;
    XVisualInfo* m_visualInfo;

    int m_screenWidth;
    int m_screenHeight;
    int m_screen;

    unsigned char* m_imageData;
    bool m_initialized;

    // OpenGL/GLX state
    GLXContext m_glContext;
    GLuint m_texture;
    bool m_glInitialized;
};

#endif // DESKTOP_RENDERER_H