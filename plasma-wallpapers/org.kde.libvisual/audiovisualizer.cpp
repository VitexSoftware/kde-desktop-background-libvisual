/*
 * SPDX-FileCopyrightText: 2025 VitexSoftware <vitex@vitexsoftware.cz>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include "audiovisualizer.h"
#include <QDebug>
#include <QThread>
#include <cmath>
#include <algorithm>
#include <pulse/error.h>

AudioVisualizer::AudioVisualizer(QObject *parent)
    : QObject(parent)
    , m_pulseAudio(nullptr)
    , m_timer(new QTimer(this))
    , m_inputBuffer(nullptr)
    , m_outputBuffer(nullptr)
    , m_plan(nullptr)
    , m_running(false)
    , m_decibels(-60.0)
    , m_level(0.0)
    , m_audioSource("default")
    , m_sensitivity(1.0)
    , m_deviceCount(0)
{
    qDebug() << "AudioVisualizer: Initializing unified audio backend";
    
    // Initialize spectrum and waveform arrays
    m_spectrum.reserve(SPECTRUM_SIZE);
    m_waveform.reserve(BUFFER_SIZE);
    
    for (int i = 0; i < SPECTRUM_SIZE; ++i) {
        m_spectrum.append(0.0);
    }
    
    for (int i = 0; i < BUFFER_SIZE; ++i) {
        m_waveform.append(0.0);
    }
    
    // Setup timer
    m_timer->setInterval(UPDATE_INTERVAL_MS);
    connect(m_timer, &QTimer::timeout, this, &AudioVisualizer::processAudio);
    
    // Initialize audio systems
    initializeFFTW();
    initializePulseAudio();
}

AudioVisualizer::~AudioVisualizer()
{
    qDebug() << "AudioVisualizer: Cleaning up";
    stop();
    cleanupPulseAudio();
    cleanupFFTW();
}

void AudioVisualizer::setRunning(bool running)
{
    if (m_running == running) return;
    
    if (running) {
        start();
    } else {
        stop();
    }
}

void AudioVisualizer::setAudioSource(const QString &source)
{
    if (m_audioSource == source) return;
    
    qDebug() << "AudioVisualizer: Setting audio source to" << source;
    m_audioSource = source;
    emit audioSourceChanged();
    
    // Restart if running to use new source
    if (m_running) {
        stop();
        start();
    }
}

void AudioVisualizer::setSensitivity(qreal sensitivity)
{
    if (qFuzzyCompare(m_sensitivity, sensitivity)) return;
    
    m_sensitivity = qMax(0.1, qMin(10.0, sensitivity));
    emit sensitivityChanged();
}

void AudioVisualizer::start()
{
    if (m_running) return;
    
    qDebug() << "AudioVisualizer: Starting audio capture";
    
    if (!m_pulseAudio) {
        qWarning() << "AudioVisualizer: PulseAudio not initialized";
        return;
    }
    
    m_running = true;
    m_timer->start();
    emit runningChanged();
    
    qDebug() << "AudioVisualizer: Audio capture started successfully";
}

void AudioVisualizer::stop()
{
    if (!m_running) return;
    
    qDebug() << "AudioVisualizer: Stopping audio capture";
    
    m_running = false;
    m_timer->stop();
    emit runningChanged();
    
    // Reset values
    m_decibels = -60.0;
    m_level = 0.0;
    
    // Clear spectrum and waveform
    for (int i = 0; i < m_spectrum.size(); ++i) {
        m_spectrum[i] = 0.0;
    }
    for (int i = 0; i < m_waveform.size(); ++i) {
        m_waveform[i] = 0.0;
    }
    
    emit decibelsChanged();
    emit levelChanged();
    emit spectrumChanged();
    emit waveformChanged();
}

QStringList AudioVisualizer::getAudioSources()
{
    // For now return basic sources, can be extended to enumerate actual PulseAudio sources
    return {"default", "monitor", "microphone"};
}

void AudioVisualizer::processAudio()
{
    if (!m_running || !m_pulseAudio) return;
    
    // Read audio data from PulseAudio
    int16_t audioData[BUFFER_SIZE];
    int error;
    
    if (pa_simple_read(m_pulseAudio, audioData, sizeof(audioData), &error) < 0) {
        qWarning() << "AudioVisualizer: Failed to read audio data:" << pa_strerror(error);
        return;
    }
    
    // Convert to double and normalize
    for (int i = 0; i < BUFFER_SIZE; ++i) {
        m_inputBuffer[i] = static_cast<double>(audioData[i]) / 32768.0;
        
        // Update waveform data
        if (i < m_waveform.size()) {
            m_waveform[i] = m_inputBuffer[i] * m_sensitivity;
        }
    }
    
    // Calculate audio level and decibels
    calculateDecibels();
    
    // Calculate spectrum using FFT
    calculateSpectrum();
    
    // Emit signals for property updates
    emit decibelsChanged();
    emit levelChanged();
    emit spectrumChanged();
    emit waveformChanged();
}

void AudioVisualizer::initializePulseAudio()
{
    qDebug() << "AudioVisualizer: Initializing PulseAudio";
    
    pa_sample_spec spec;
    spec.format = PA_SAMPLE_S16LE;
    spec.channels = 1;
    spec.rate = SAMPLE_RATE;
    
    int error;
    m_pulseAudio = pa_simple_new(
        nullptr,                    // Server
        "AudioVisualizer",          // Application name
        PA_STREAM_RECORD,          // Direction
        m_audioSource.toUtf8().constData(), // Source device
        "Audio Visualization",      // Stream description
        &spec,                     // Sample spec
        nullptr,                   // Channel map
        nullptr,                   // Buffer attributes
        &error
    );
    
    if (!m_pulseAudio) {
        qWarning() << "AudioVisualizer: Failed to initialize PulseAudio:" << pa_strerror(error);
        return;
    }
    
    qDebug() << "AudioVisualizer: PulseAudio initialized successfully";
    m_deviceCount = 1; // Simplified for now
    emit deviceCountChanged();
}

void AudioVisualizer::cleanupPulseAudio()
{
    if (m_pulseAudio) {
        pa_simple_free(m_pulseAudio);
        m_pulseAudio = nullptr;
    }
}

void AudioVisualizer::initializeFFTW()
{
    qDebug() << "AudioVisualizer: Initializing FFTW";
    
    m_inputBuffer = fftw_alloc_real(BUFFER_SIZE);
    m_outputBuffer = fftw_alloc_complex(BUFFER_SIZE / 2 + 1);
    
    if (!m_inputBuffer || !m_outputBuffer) {
        qCritical() << "AudioVisualizer: Failed to allocate FFTW buffers";
        return;
    }
    
    m_plan = fftw_plan_dft_r2c_1d(BUFFER_SIZE, m_inputBuffer, m_outputBuffer, FFTW_ESTIMATE);
    
    if (!m_plan) {
        qCritical() << "AudioVisualizer: Failed to create FFTW plan";
        return;
    }
    
    qDebug() << "AudioVisualizer: FFTW initialized successfully";
}

void AudioVisualizer::cleanupFFTW()
{
    if (m_plan) {
        fftw_destroy_plan(m_plan);
        m_plan = nullptr;
    }
    
    if (m_inputBuffer) {
        fftw_free(m_inputBuffer);
        m_inputBuffer = nullptr;
    }
    
    if (m_outputBuffer) {
        fftw_free(m_outputBuffer);
        m_outputBuffer = nullptr;
    }
}

void AudioVisualizer::calculateSpectrum()
{
    if (!m_plan) return;
    
    // Execute FFT
    fftw_execute(m_plan);
    
    // Calculate magnitude spectrum
    for (int i = 0; i < SPECTRUM_SIZE && i < (BUFFER_SIZE / 2); ++i) {
        double real = m_outputBuffer[i][0];
        double imag = m_outputBuffer[i][1];
        double magnitude = std::sqrt(real * real + imag * imag) / BUFFER_SIZE;
        
        // Apply sensitivity and logarithmic scaling
        magnitude *= m_sensitivity;
        magnitude = std::log10(magnitude + 1e-10) * 20.0; // Convert to dB-like scale
        magnitude = std::max(0.0, (magnitude + 100.0) / 100.0); // Normalize to 0-1
        
        m_spectrum[i] = magnitude;
    }
}

void AudioVisualizer::calculateDecibels()
{
    if (!m_inputBuffer) return;
    
    // Calculate RMS (Root Mean Square)
    double rms = 0.0;
    for (int i = 0; i < BUFFER_SIZE; ++i) {
        rms += m_inputBuffer[i] * m_inputBuffer[i];
    }
    rms = std::sqrt(rms / BUFFER_SIZE);
    
    // Convert to decibels
    if (rms > 0.0) {
        m_decibels = 20.0 * std::log10(rms * m_sensitivity);
        m_decibels = std::max(-60.0, std::min(0.0, m_decibels)); // Clamp to reasonable range
    } else {
        m_decibels = -60.0;
    }
    
    // Calculate simple level (0-1)
    m_level = (m_decibels + 60.0) / 60.0; // Convert -60dB to 0dB range to 0-1
    m_level = std::max(0.0, std::min(1.0, m_level));
}

#include "audiovisualizer.moc"