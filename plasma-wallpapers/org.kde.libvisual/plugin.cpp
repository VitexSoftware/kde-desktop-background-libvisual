/*
 * SPDX-FileCopyrightText: 2025 VitexSoftware <vitex@vitexsoftware.cz>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include "plugin.h"
#include <KPluginFactory>
#include <QDebug>

// The wallpaper is implemented entirely in QML (main.qml / config.qml).
// AudioVisualizer is registered as a QML element by qt_add_qml_module.
// This plugin class is only required to satisfy KPluginFactory.
class LibVisualWallpaperPackage : public QObject {
    Q_OBJECT
public:
    explicit LibVisualWallpaperPackage(QObject *parent = nullptr) : QObject(parent) {
        qDebug() << "LibVisual wallpaper package loaded";
    }
};

K_PLUGIN_CLASS_WITH_JSON(LibVisualWallpaperPackage, "plasma_wallpaper_org.kde.libvisual.json")

#include "plugin.moc"
