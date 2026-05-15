/*
 * SPDX-FileCopyrightText: 2025 VitexSoftware <vitex@vitexsoftware.cz>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#pragma once

#include <QMutex>
#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QtQml/qqml.h>
#include <fftw3.h>
#include <pulse/pulseaudio.h>

/**
 * Async PulseAudio/PipeWire audio capture backend for the LibVisual wallpaper.
 *
 * Uses pa_threaded_mainloop + pa_stream for callback-driven capture (no
 * blocking QTimer), and pa_context_get_source_info_list() for in-process
 * device enumeration (no pactl subprocess).  Data written by the PA callback
 * thread is protected by m_mutex and published to QML via QueuedConnection.
 */
class AudioVisualizer : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(qreal        decibels    READ decibels    NOTIFY decibelsChanged)
    Q_PROPERTY(qreal        level       READ level       NOTIFY levelChanged)
    Q_PROPERTY(QVariantList spectrum    READ spectrum    NOTIFY spectrumChanged)
    Q_PROPERTY(QVariantList waveform    READ waveform    NOTIFY waveformChanged)
    Q_PROPERTY(bool         running     READ running     WRITE setRunning   NOTIFY runningChanged)
    Q_PROPERTY(int          deviceCount READ deviceCount NOTIFY deviceCountChanged)
    Q_PROPERTY(QString      audioSource READ audioSource WRITE setAudioSource NOTIFY audioSourceChanged)
    Q_PROPERTY(qreal        sensitivity READ sensitivity WRITE setSensitivity NOTIFY sensitivityChanged)

public:
    explicit AudioVisualizer(QObject *parent = nullptr);
    ~AudioVisualizer() override;

    qreal        decibels()    const;
    qreal        level()       const;
    QVariantList spectrum()    const;
    QVariantList waveform()    const;
    bool         running()     const { return m_running; }
    int          deviceCount() const { return m_deviceCount; }
    QString      audioSource() const { return m_audioSource; }
    qreal        sensitivity() const { return m_sensitivity; }

    void setRunning(bool running);
    void setAudioSource(const QString &source);
    void setSensitivity(qreal sensitivity);

    Q_INVOKABLE void         start();
    Q_INVOKABLE void         stop();
    Q_INVOKABLE QStringList  getAudioSources();
    Q_INVOKABLE QVariantList getInputSources();

signals:
    void decibelsChanged();
    void levelChanged();
    void spectrumChanged();
    void waveformChanged();
    void runningChanged();
    void deviceCountChanged();
    void audioSourceChanged();
    void sensitivityChanged();

private slots:
    // Emits all data signals; invoked on the Qt main thread via QueuedConnection
    // from the PA callback thread after each audio frame is processed.
    void onAudioProcessed();

private:
    // --- PulseAudio threaded mainloop ---
    pa_threaded_mainloop *m_mainloop = nullptr;
    pa_context           *m_context  = nullptr;
    pa_stream            *m_stream   = nullptr;

    void connectPulse();
    void disconnectPulse();
    void connectStream();  // call with mainloop lock held; context must be READY

    static void contextStateCb(pa_context *ctx, void *ud);
    static void streamStateCb(pa_stream *s, void *ud);
    static void streamReadCb(pa_stream *s, size_t nbytes, void *ud);

    // --- FFTW (accessed only from the PA callback thread) ---
    double       *m_fftIn  = nullptr;
    fftw_complex *m_fftOut = nullptr;
    fftw_plan     m_fftPlan = nullptr;

    void initFFTW();
    void cleanupFFTW();

    // --- Shared audio results (mutex-protected) ---
    mutable QMutex m_mutex;
    qreal          m_decibels = -60.0;
    qreal          m_level    = 0.0;
    QVariantList   m_spectrum;
    QVariantList   m_waveform;

    // --- Control state (Qt main thread) ---
    bool    m_running     = false;
    QString m_audioSource = QStringLiteral("default");
    qreal   m_sensitivity = 1.0;
    int     m_deviceCount = 0;

    static constexpr int SAMPLE_RATE   = 44100;
    static constexpr int BUFFER_SIZE   = 1024;
    static constexpr int SPECTRUM_SIZE = 256;
};
