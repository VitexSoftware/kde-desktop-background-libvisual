#include <libvisual/libvisual.h>
#include <iostream>

int main(int argc, char* argv[]) {
    std::cout << "Testing libvisual video initialization..." << std::endl;
    
    // Test basic initialization
    int result = visual_init(&argc, &argv);
    if (result != VISUAL_OK) {
        std::cerr << "visual_init failed with code: " << result << std::endl;
        return 1;
    }
    
    std::cout << "LibVisual initialized successfully!" << std::endl;
    
    // Test video with exact same setup as Visualizer
    VisVideo* video = visual_video_new();
    if (!video) {
        std::cerr << "Failed to create video object" << std::endl;
        visual_quit();
        return 1;
    }
    
    std::cout << "Video object created successfully!" << std::endl;
    
    // Set same properties as in Visualizer
    int width = 800, height = 600;
    visual_video_set_dimension(video, width, height);
    visual_video_set_depth(video, VISUAL_VIDEO_DEPTH_24BIT);
    
    std::cout << "Video properties set, attempting buffer allocation..." << std::endl;
    
    // This is where it crashes
    if (visual_video_allocate_buffer(video) != VISUAL_OK) {
        std::cerr << "Failed to allocate video buffer" << std::endl;
        visual_object_unref(VISUAL_OBJECT(video));
        visual_quit();
        return 1;
    }
    
    std::cout << "Video buffer allocated successfully!" << std::endl;
    
    // Cleanup
    visual_object_unref(VISUAL_OBJECT(video));
    visual_quit();
    
    std::cout << "Test completed successfully!" << std::endl;
    return 0;
}