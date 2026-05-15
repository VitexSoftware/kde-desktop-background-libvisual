/*
 * SPDX-FileCopyrightText: 2026 VitexSoftware <vitex@vitexsoftware.cz>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include "projectmitem.h"

#include <QDebug>
#include <QDir>
#include <QMutexLocker>
#include <QOpenGLFramebufferObject>
#include <QOpenGLFramebufferObjectFormat>
#include <QSize>
#include <QVector>

#ifdef HAVE_PROJECTM
#  include <libprojectM/projectM.hpp>
#endif

// ---------------------------------------------------------------------------
// ProjectMRenderer — lives on the render thread
// ---------------------------------------------------------------------------

class ProjectMRenderer : public QQuickFramebufferObject::Renderer
{
public:
    ProjectMRenderer() = default;
    ~ProjectMRenderer() override
    {
#ifdef HAVE_PROJECTM
        delete m_pm;
#endif
    }

    // Called on the render thread; item pointer valid, but only read via mutex
    void synchronize(QQuickFramebufferObject *fbo) override
    {
        auto *item = static_cast<ProjectMItem *>(fbo);

        // Copy waveform under mutex
        {
            QMutexLocker lk(&item->m_mutex);
            m_waveform = item->m_waveform;
        }

        // Detect preset-path change → force re-init
        const QString newPath = item->m_presetPath;
        if (newPath != m_presetPath) {
            m_presetPath = newPath;
#ifdef HAVE_PROJECTM
            delete m_pm;
            m_pm = nullptr;
#endif
        }

        m_shuffleEnabled = item->m_shuffleEnabled;
        m_presetDuration = item->m_presetDuration;

        // If a specific preset was requested, apply it next render
        int requestedIndex = item->m_presetIndex;
        if (requestedIndex != m_appliedPresetIndex) {
            m_pendingPresetIndex  = requestedIndex;
            m_appliedPresetIndex  = requestedIndex;
        }
    }

    QOpenGLFramebufferObject *createFramebufferObject(const QSize &size) override
    {
        QOpenGLFramebufferObjectFormat fmt;
        fmt.setAttachment(QOpenGLFramebufferObject::CombinedDepthStencil);
        auto *fbo = new QOpenGLFramebufferObject(size, fmt);

#ifdef HAVE_PROJECTM
        if (m_pm)
            m_pm->projectM_resetGL(size.width(), size.height());
#endif
        m_size = size;
        return fbo;
    }

    void render() override
    {
#ifdef HAVE_PROJECTM
        if (!m_pm)
            initProjectM();

        if (m_pm) {
            // Apply pending explicit preset selection
            if (m_pendingPresetIndex >= 0) {
                unsigned sz = m_pm->getPlaylistSize();
                if (sz > 0) {
                    unsigned idx = static_cast<unsigned>(m_pendingPresetIndex) % sz;
                    m_pm->selectPreset(idx, true);
                }
                m_pendingPresetIndex = -1;
            }

            // Feed PCM to projectM
            if (!m_waveform.isEmpty()) {
                QVector<float> pcm;
                pcm.reserve(m_waveform.size());
                for (const QVariant &v : std::as_const(m_waveform))
                    pcm.append(static_cast<float>(v.toDouble()));
                m_pm->pcm()->addPCMfloat(pcm.constData(), pcm.size());
            }

            m_pm->renderFrame();
        }
#else
        // Stub: clear to black so the FBO is not garbage
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
#endif
        // Request continuous rendering
        update();
    }

private:
    void initProjectM()
    {
#ifdef HAVE_PROJECTM
        try {
            projectM::Settings s;
            s.windowWidth      = static_cast<unsigned>(m_size.width());
            s.windowHeight     = static_cast<unsigned>(m_size.height());
            s.fps              = 60;
            s.textureSize      = 512;
            s.meshX            = 32;
            s.meshY            = 24;
            s.presetURL        = m_presetPath.toStdString();
            s.shuffleEnabled   = m_shuffleEnabled;
            s.presetDuration   = static_cast<double>(m_presetDuration);
            s.hardcutDuration  = 3.0;
            s.beatSensitivity  = 10.0;
            s.aspectCorrection = true;

            m_pm = new projectM(s);
            qDebug() << "ProjectMRenderer: projectM initialised, presetURL ="
                     << QString::fromStdString(s.presetURL)
                     << "playlist size =" << m_pm->getPlaylistSize();
        } catch (const std::exception &ex) {
            qWarning() << "ProjectMRenderer: projectM init failed:" << ex.what();
            m_pm = nullptr;
        } catch (...) {
            qWarning() << "ProjectMRenderer: projectM init failed (unknown exception)";
            m_pm = nullptr;
        }
#endif
    }

#ifdef HAVE_PROJECTM
    projectM *m_pm = nullptr;
#endif

    QVariantList m_waveform;
    QString      m_presetPath        = QStringLiteral("/usr/share/projectM/presets");
    bool         m_shuffleEnabled    = true;
    int          m_presetDuration    = 30;
    int          m_pendingPresetIndex = -1;
    int          m_appliedPresetIndex = -1;
    QSize        m_size;
};

// ---------------------------------------------------------------------------
// ProjectMItem — QML-visible item, Qt main thread
// ---------------------------------------------------------------------------

ProjectMItem::ProjectMItem(QQuickItem *parent)
    : QQuickFramebufferObject(parent)
{
    setMirrorVertically(true);  // GL origin is bottom-left; Qt origin is top-left
    scanPresets();
}

QQuickFramebufferObject::Renderer *ProjectMItem::createRenderer() const
{
    return new ProjectMRenderer();
}

void ProjectMItem::setWaveform(const QVariantList &waveform)
{
    {
        QMutexLocker lk(&m_mutex);
        m_waveform = waveform;
    }
    emit waveformChanged();
    update();
}

void ProjectMItem::setPresetPath(const QString &path)
{
    if (m_presetPath == path)
        return;
    m_presetPath = path;
    scanPresets();
    emit presetPathChanged();
    emit presetNamesChanged();
    update();
}

void ProjectMItem::setShuffleEnabled(bool enabled)
{
    if (m_shuffleEnabled == enabled)
        return;
    m_shuffleEnabled = enabled;
    emit shuffleEnabledChanged();
}

void ProjectMItem::setPresetDuration(int seconds)
{
    if (m_presetDuration == seconds)
        return;
    m_presetDuration = seconds;
    emit presetDurationChanged();
}

void ProjectMItem::setPresetIndex(int index)
{
    if (m_presetIndex == index)
        return;
    m_presetIndex = index;
    emit presetIndexChanged();
    update();
}

void ProjectMItem::scanPresets()
{
    m_presetNames = QDir(m_presetPath)
        .entryList({QStringLiteral("*.milk"), QStringLiteral("*.prjm")},
                   QDir::Files, QDir::Name);
}

#include "projectmitem.moc"
