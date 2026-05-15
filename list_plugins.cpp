#include <libvisual/libvisual.h>
#include <iostream>
#include <iomanip>

int main(int argc, char* argv[]) {
    // Initialize libvisual
    if (visual_init(&argc, &argv) != VISUAL_OK) {
        std::cerr << "Failed to initialize libvisual" << std::endl;
        return 1;
    }

    std::cout << "=== Available LibVisual Plugins ===" << std::endl;
    std::cout << std::endl;

    // Get list of actor plugins
    VisList* list = visual_actor_get_list();
    if (!list) {
        std::cerr << "Failed to get plugin list" << std::endl;
        visual_quit();
        return 1;
    }

    int pluginCount = 0;
    VisListEntry* entry = nullptr;
    
    while (void* data = visual_list_next(list, &entry)) {
        VisPluginRef* ref = static_cast<VisPluginRef*>(data);
        if (ref && ref->info && ref->info->plugname) {
            pluginCount++;
            std::cout << ref->info->plugname << "\n";
        }
    }

    std::cout << "Total plugins found: " << pluginCount << std::endl;

    // Cleanup
    visual_quit();
    
    return 0;
}
