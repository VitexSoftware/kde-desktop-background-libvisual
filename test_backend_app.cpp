#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDebug>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // Add our QML import paths
    qputenv("QML2_IMPORT_PATH", "/home/vitex/.local/lib/qt6/qml:/home/vitex/.local/lib/x86_64-linux-gnu/qml");

    QQmlApplicationEngine engine;
    
    // Load our test QML
    engine.load(QUrl::fromLocalFile("/home/vitex/Projects/VitexSoftware/kde-desktop-background-libvisual/test_backend.qml"));

    if (engine.rootObjects().isEmpty()) {
        qDebug() << "Failed to load QML";
        return -1;
    }

    qDebug() << "QML loaded successfully";
    return app.exec();
}