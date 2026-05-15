#ifndef VISUALIZATION_FACTORY_H
#define VISUALIZATION_FACTORY_H

#include "visualization_engine.h"
#include <memory>
#include <string>
#include <vector>

/**
 * Factory for creating visualization engine instances.
 * Supports libvisual and projectM engines with runtime detection.
 */
class VisualizationFactory {
public:
    enum class EngineType {
        AUTO,        // Automatically select best available
        LIBVISUAL,   // Force libvisual
        PROJECTM     // Force projectM
    };

    /**
     * Create a visualization engine instance.
     * @param type Engine type to create (AUTO, LIBVISUAL, or PROJECTM)
     * @return Unique pointer to visualization engine, or nullptr on failure
     */
    static std::unique_ptr<VisualizationEngine> createEngine(EngineType type = EngineType::AUTO);

    /**
     * Check if projectM is available on the system.
     * @return true if projectM can be used, false otherwise
     */
    static bool isProjectMAvailable();

    /**
     * Get list of available engine types.
     * @return Vector of engine type names
     */
    static std::vector<std::string> getAvailableEngines();

    /**
     * Convert string to engine type.
     * @param name Engine name ("auto", "libvisual", or "projectm")
     * @return Engine type enum value
     */
    static EngineType stringToEngineType(const std::string& name);

    /**
     * Convert engine type to string.
     * @param type Engine type enum value
     * @return Engine name string
     */
    static std::string engineTypeToString(EngineType type);
};

#endif // VISUALIZATION_FACTORY_H
