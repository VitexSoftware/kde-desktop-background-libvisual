/*
 * SPDX-FileCopyrightText: 2025 VitexSoftware <vitex@vitexsoftware.cz>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#pragma once

#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqml.h>
#include <pulse/simple.h>
#include <fftw3.h>
#include <atomic>

/**
 * Unified audio visualizer backend for both wallpaper and config dialog
 * Provides real-time audio analysis with spectrum, waveform, and level detection
 */
class AudioVisualizer : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    
    // Audio level properties (for config dialog)
    Q_PROPERTY(qreal decibels READ decibels NOTIFY decibelsChanged)
    Q_PROPERTY(qreal level READ level NOTIFY levelChanged)
    
    // Spectrum properties (for main wallpaper)  
    Q_PROPERTY(QVariantList spectrum READ spectrum NOTIFY spectrumChanged)
    Q_PROPERTY(QVariantList waveform READ waveform NOTIFY waveformChanged)
    
    // Control properties
    Q_PROPERTY(bool running READ running WRITE setRunning NOTIFY runningChanged)
    Q_PROPERTY(int deviceCount READ deviceCount NOTIFY deviceCountChanged)
    Q_PROPERTY(QString audioSource READ audioSource WRITE setAudioSource NOTIFY audioSourceChanged)
    Q_PROPERTY(qreal sensitivity READ sensitivity WRITE setSensitivity NOTIFY sensitivityChanged)

public:
    explicit AudioVisualizer(QObject *parent = nullptr);
    ~AudioVisualizer();

    // Property getters
    qreal decibels() const { return m_decibels; }
    qreal level() const { return m_level; }
    QVariantList spectrum() const { return m_spectrum; }
    QVariantList waveform() const { return m_waveform; }
    bool running() const { return m_running; }
    int deviceCount() const { return m_deviceCount; }
    QString audioSource() const { return m_audioSource; }
    qreal sensitivity() const { return m_sensitivity; }

    // Property setters
    void setRunning(bool running);
    void setAudioSource(const QString &source);
    void setSensitivity(qreal sensitivity);

    // Methods callable from QML
    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE QStringList getAudioSources();

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
    void processAudio();

private:
    void initializePulseAudio();
    void cleanupPulseAudio();
    void initializeFFTW();
    void cleanupFFTW();
    void calculateSpectrum();
    void calculateDecibels();
    
    // Audio capture
    pa_simple *m_pulseAudio;
    QTimer *m_timer;
    
    // Audio processing
    double *m_inputBuffer;
    fftw_complex *m_outputBuffer;
    fftw_plan m_plan;
    
    // State
    std::atomic<bool> m_running;
    qreal m_decibels;
    qreal m_level;
    QVariantList m_spectrum;
    QVariantList m_waveform;
    QString m_audioSource;
    qreal m_sensitivity;
    int m_deviceCount;
    
    // Configuration
    static constexpr int SAMPLE_RATE = 44100;
    static constexpr int BUFFER_SIZE = 1024;
    static constexpr int SPECTRUM_SIZE = 256;
    static constexpr int UPDATE_INTERVAL_MS = 16; // ~60 FPS
};