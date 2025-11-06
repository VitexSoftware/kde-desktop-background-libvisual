#include <libvisual/libvisual.h>
#include <iostream>

int main(int argc, char* argv[]) {
    std::cout << "Testing libvisual with different approaches..." << std::endl;
    
    // Test 1: Initialize without video allocation
    if (visual_init(&argc, &argv) != VISUAL_OK) {
        std::cerr << "visual_init failed" << std::endl;
        return 1;
    }
    
    std::cout << "LibVisual initialized successfully!" << std::endl;
    
    // Test 2: Try creating actor without video first
    VisActor* actor = visual_actor_new("gforce");
    if (!actor) {
        std::cout << "Gforce plugin not available, trying others..." << std::endl;
        const char* plugins[] = {"infinite", "jakdaw", "lv_scope", "madspin", nullptr};
        for (int i = 0; plugins[i] && !actor; ++i) {
            std::cout << "Trying plugin: " << plugins[i] << std::endl;
            actor = visual_actor_new(plugins[i]);
        }
    }
    
    if (!actor) {
        std::cerr << "No visualization plugins available" << std::endl;
        visual_quit();
        return 1;
    }
    
    std::cout << "Actor created successfully!" << std::endl;
    
    // Test 3: Try very small video buffer
    VisVideo* video = visual_video_new();
    if (!video) {
        std::cerr << "Failed to create video object" << std::endl;
        visual_object_unref(VISUAL_OBJECT(actor));
        visual_quit();
        return 1;
    }
    
    // Start with tiny dimensions
    visual_video_set_dimension(video, 64, 48);
    visual_video_set_depth(video, VISUAL_VIDEO_DEPTH_8BIT);
    
    std::cout << "Attempting small buffer allocation (64x48, 8-bit)..." << std::endl;
    
    if (visual_video_allocate_buffer(video) != VISUAL_OK) {
        std::cerr << "Even small buffer allocation failed" << std::endl;
        
        // Try without allocating buffer at all
        std::cout << "Trying to work without buffer allocation..." << std::endl;
        
        // Create our own buffer
        int bufferSize = 64 * 48 * 1; // 8-bit = 1 byte per pixel
        unsigned char* buffer = new unsigned char[bufferSize];
        visual_video_set_buffer(video, buffer);
        
        std::cout << "Custom buffer set successfully!" << std::endl;
        
        // Test actor connection
        if (visual_actor_realize(actor) == VISUAL_OK &&
            visual_actor_set_video(actor, video) == VISUAL_OK) {
            std::cout << "Actor setup completed successfully!" << std::endl;
        } else {
            std::cerr << "Actor setup failed" << std::endl;
        }
        
        delete[] buffer;
    } else {
        std::cout << "Buffer allocated successfully!" << std::endl;
    }
    
    // Cleanup
    visual_object_unref(VISUAL_OBJECT(video));
    visual_object_unref(VISUAL_OBJECT(actor));
    visual_quit();
    
    std::cout << "Test completed!" << std::endl;
    return 0;
}