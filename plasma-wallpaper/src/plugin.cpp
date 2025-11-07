#include <QQmlExtensionPlugin>
#include <QQmlEngine>
#include <QJSEngine>
#include "audiovisualizerbackend.h"

class AudioVisualizerWallpaperPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        Q_ASSERT(uri == QLatin1String("org.kde.plasma.audiovisualizer"));
        
        qmlRegisterType<AudioVisualizerBackend>(uri, 1, 0, "AudioVisualizerBackend");
        qmlRegisterSingletonType<AudioVisualizerBackend>(uri, 1, 0, "AudioVisualizerBackend", 
            [](QQmlEngine*, QJSEngine*) -> QObject* {
                return AudioVisualizerBackend::createInstance();
            });
    }
};

#include "plugin.moc"