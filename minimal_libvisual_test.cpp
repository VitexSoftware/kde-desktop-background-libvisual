#include <libvisual/libvisual.h>
#include <iostream>

int main(int argc, char* argv[]) {
    std::cout << "Testing libvisual initialization..." << std::endl;
    
    // Test basic initialization
    int result = visual_init(&argc, &argv);
    if (result != VISUAL_OK) {
        std::cerr << "visual_init failed with code: " << result << std::endl;
        return 1;
    }
    
    std::cout << "LibVisual initialized successfully!" << std::endl;
    
    // Test basic objects creation
    VisVideo* video = visual_video_new();
    if (!video) {
        std::cerr << "Failed to create video object" << std::endl;
        visual_quit();
        return 1;
    }
    
    std::cout << "Video object created successfully!" << std::endl;
    
    // Cleanup
    visual_object_unref(VISUAL_OBJECT(video));
    visual_quit();
    
    std::cout << "Test completed successfully!" << std::endl;
    return 0;
}