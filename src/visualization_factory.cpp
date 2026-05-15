#include "visualization_factory.h"
#include "visualizer.h"

#ifdef HAVE_PROJECTM
#include "projectm_visualizer.h"
#endif

#include <iostream>
#include <algorithm>
#include <filesystem>

namespace fs = std::filesystem;

std::unique_ptr<VisualizationEngine> VisualizationFactory::createEngine(EngineType type) {
    if (type == EngineType::AUTO) {
        // Prefer projectM if available, fallback to libvisual
#ifdef HAVE_PROJECTM
        if (isProjectMAvailable()) {
            std::cout << "Auto-selecting projectM visualization engine" << std::endl;
            type = EngineType::PROJECTM;
        } else {
            std::cout << "ProjectM not available, using libvisual" << std::endl;
            type = EngineType::LIBVISUAL;
        }
#else
        std::cout << "ProjectM support not compiled, using libvisual" << std::endl;
        type = EngineType::LIBVISUAL;
#endif
    }

    switch (type) {
        case EngineType::LIBVISUAL:
            std::cout << "Creating libvisual visualization engine" << std::endl;
            return std::make_unique<Visualizer>();

#ifdef HAVE_PROJECTM
        case EngineType::PROJECTM:
            if (!isProjectMAvailable()) {
                std::cerr << "ProjectM requested but not available, falling back to libvisual" << std::endl;
                return std::make_unique<Visualizer>();
            }
            std::cout << "Creating projectM visualization engine" << std::endl;
            return std::make_unique<ProjectMVisualizer>();
#endif

        default:
            std::cerr << "Unknown engine type, using libvisual" << std::endl;
            return std::make_unique<Visualizer>();
    }
}

bool VisualizationFactory::isProjectMAvailable() {
#ifdef HAVE_PROJECTM
    // Check if projectM preset directory exists
    std::string presetDir = "/usr/share/projectM/presets";
    try {
        if (fs::exists(presetDir) && fs::is_directory(presetDir)) {
            // Check if there are any .milk files
            for (const auto& entry : fs::recursive_directory_iterator(presetDir)) {
                if (entry.is_regular_file()) {
                    std::string ext = entry.path().extension().string();
                    if (ext == ".milk" || ext == ".prjm") {
                        return true;
                    }
                }
            }
        }
    } catch (const std::exception& e) {
        std::cerr << "Error checking projectM availability: " << e.what() << std::endl;
    }
    return false;
#else
    return false;
#endif
}

std::vector<std::string> VisualizationFactory::getAvailableEngines() {
    std::vector<std::string> engines;
    engines.push_back("auto");
    engines.push_back("libvisual");

#ifdef HAVE_PROJECTM
    if (isProjectMAvailable()) {
        engines.push_back("projectm");
    }
#endif

    return engines;
}

VisualizationFactory::EngineType VisualizationFactory::stringToEngineType(const std::string& name) {
    std::string lowerName = name;
    std::transform(lowerName.begin(), lowerName.end(), lowerName.begin(), ::tolower);

    if (lowerName == "auto") {
        return EngineType::AUTO;
    } else if (lowerName == "libvisual") {
        return EngineType::LIBVISUAL;
    } else if (lowerName == "projectm") {
        return EngineType::PROJECTM;
    } else {
        return EngineType::AUTO;
    }
}

std::string VisualizationFactory::engineTypeToString(EngineType type) {
    switch (type) {
        case EngineType::AUTO:
            return "auto";
        case EngineType::LIBVISUAL:
            return "libvisual";
        case EngineType::PROJECTM:
            return "projectm";
        default:
            return "auto";
    }
}
