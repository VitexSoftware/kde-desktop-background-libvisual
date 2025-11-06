#ifndef DESKTOP_RENDERER_H
#define DESKTOP_RENDERER_H

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/extensions/Xrender.h>

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
    void getScreenSize(int& width, int& height);

private:
    bool createBackgroundWindow();
    void destroyWindow();

    Display* m_display;
    Window m_rootWindow;
    Window m_backgroundWindow;
    GC m_gc;
    XImage* m_image;
    
    int m_screenWidth;
    int m_screenHeight;
    int m_screen;
    
    unsigned char* m_imageData;
    bool m_initialized;
};

#endif // DESKTOP_RENDERER_H