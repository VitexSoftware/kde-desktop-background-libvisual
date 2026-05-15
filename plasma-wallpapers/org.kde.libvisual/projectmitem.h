/*
 * SPDX-FileCopyrightText: 2026 VitexSoftware <vitex@vitexsoftware.cz>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#pragma once

#include <QDir>
#include <QMutex>
#include <QQuickFramebufferObject>
#include <QStringList>
#include <QVariantList>
#include <QtQml/qqml.h>

class ProjectMRenderer;

/**
 * QQuickFramebufferObject that wraps a projectM instance.
 *
 * Audio PCM is fed each frame from the waveform property (a QVariantList of
 * floats in [-1, 1]).  Preset selection, shuffle and duration are all
 * configurable via QML properties.  When libprojectM is not present at build
 * time (HAVE_PROJECTM not defined) the item renders a solid black frame so
 * that the QML type always exists and main.qml compiles cleanly.
 */
class ProjectMItem : public QQuickFramebufferObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList waveform       WRITE setWaveform                          NOTIFY waveformChanged)
    Q_PROPERTY(QString      presetPath     READ  presetPath  WRITE setPresetPath      NOTIFY presetPathChanged)
    Q_PROPERTY(bool         shuffleEnabled READ  shuffleEnabled WRITE setShuffleEnabled NOTIFY shuffleEnabledChanged)
    Q_PROPERTY(int          presetDuration READ  presetDuration WRITE setPresetDuration NOTIFY presetDurationChanged)
    Q_PROPERTY(int          presetIndex    READ  presetIndex  WRITE setPresetIndex    NOTIFY presetIndexChanged)
    Q_PROPERTY(QStringList  presetNames    READ  presetNames                          NOTIFY presetNamesChanged)

    friend class ProjectMRenderer;

public:
    explicit ProjectMItem(QQuickItem *parent = nullptr);

    Renderer *createRenderer() const override;

    QString     presetPath()     const { return m_presetPath; }
    bool        shuffleEnabled() const { return m_shuffleEnabled; }
    int         presetDuration() const { return m_presetDuration; }
    int         presetIndex()    const { return m_presetIndex; }
    QStringList presetNames()    const { return m_presetNames; }

    void setWaveform(const QVariantList &waveform);
    void setPresetPath(const QString &path);
    void setShuffleEnabled(bool enabled);
    void setPresetDuration(int seconds);
    void setPresetIndex(int index);

signals:
    void waveformChanged();
    void presetPathChanged();
    void shuffleEnabledChanged();
    void presetDurationChanged();
    void presetIndexChanged();
    void presetNamesChanged();

private:
    void scanPresets();

    mutable QMutex m_mutex;
    QVariantList   m_waveform;
    QString        m_presetPath     = QStringLiteral("/usr/share/projectM/presets");
    bool           m_shuffleEnabled = true;
    int            m_presetDuration = 30;
    int            m_presetIndex    = -1;
    QStringList    m_presetNames;
};
