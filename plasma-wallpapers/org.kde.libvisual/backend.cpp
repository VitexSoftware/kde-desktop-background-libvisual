/*
 * SPDX-FileCopyrightText: 2025 VitexSoftware <vitex@vitexsoftware.cz>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include "backend.h"
#include <QDebug>
#include <cmath>
#include <cstring>
#include <pulse/error.h>
#include <QtQml/qqml.h>

LibVisualBackend::LibVisualBackend(QObject *parent)
    : QObject(parent)
    , m_audioTimer(new QTimer(this))
    , m_decibels(-60.0)
    , m_audioActive(false)
    , m_pulseCapture(nullptr)
    , m_fftInput(nullptr)
    , m_fftOutput(nullptr)
{
    // Initialize spectrum with zeros
    for (int i = 0; i < m_fftSize / 2; i++) {
        m_spectrum.append(0.0);
    }

    // Initialize FFT
    m_fftInput = reinterpret_cast<fftw_complex*>(fftw_malloc(sizeof(fftw_complex) * m_fftSize));
    m_fftOutput = reinterpret_cast<fftw_complex*>(fftw_malloc(sizeof(fftw_complex) * m_fftSize));
    m_fftPlan = fftw_plan_dft_1d(m_fftSize, m_fftInput, m_fftOutput, FFTW_FORWARD, FFTW_ESTIMATE);

    // Hann window
    for (int i = 0; i < m_fftSize; i++) {
        m_window[i] = 0.5f * (1.0f - std::cos(2.0f * M_PI * i / (m_fftSize - 1)));
    }

    connect(m_audioTimer, &QTimer::timeout, this, &LibVisualBackend::audioPollTick);
    
    // Auto-start audio capture
    startAudioLevel();
}

LibVisualBackend::~LibVisualBackend()
{
    if (m_pulseCapture) {
        pa_simple_free(m_pulseCapture);
    }
    if (m_fftInput) fftw_free(m_fftInput);
    if (m_fftOutput) fftw_free(m_fftOutput);
    fftw_destroy_plan(m_fftPlan);
}

void LibVisualBackend::startAudioLevel()
{
    if (m_pulseCapture) {
        return; // Already running
    }

    pa_sample_spec ss;
    ss.format = PA_SAMPLE_FLOAT32LE;
    ss.channels = 1;
    ss.rate = 44100;

    pa_buffer_attr attr;
    attr.maxlength = (uint32_t) -1;
    attr.tlength = pa_usec_to_bytes(50 * 1000, &ss); // 50ms latency (PA_USEC_PER_MSEC = 1000)
    attr.prebuf = (uint32_t) -1;
    attr.minreq = (uint32_t) -1;
    attr.fragsize = pa_usec_to_bytes(50 * 1000, &ss);

    int error;
    m_pulseCapture = pa_simple_new(nullptr, "libvisual-wallpaper", PA_STREAM_RECORD,
                                   nullptr, "wallpaper capture", &ss, nullptr, &attr, &error);
    
    if (!m_pulseCapture) {
        qWarning() << "PulseAudio capture failed:" << pa_strerror(error);
        m_audioActive = false;
        emit audioActiveChanged();
        return;
    }

    m_audioActive = true;
    emit audioActiveChanged();
    
    // Start polling timer (30 FPS for smooth animation)
    m_audioTimer->start(33);
}

void LibVisualBackend::audioPollTick()
{
    if (!m_pulseCapture) return;

    int error;
    const int samples = m_fftSize;
    
    if (pa_simple_read(m_pulseCapture, m_audioBuffer, samples * sizeof(float), &error) < 0) {
        qWarning() << "PulseAudio read failed:" << pa_strerror(error);
        return;
    }

    // Calculate RMS for decibel level
    float rms = 0.0f;
    for (int i = 0; i < samples; i++) {
        rms += m_audioBuffer[i] * m_audioBuffer[i];
    }
    rms = std::sqrt(rms / samples);
    
    m_decibels = rms > 0 ? 20.0f * std::log10(rms) : -60.0f;
    emit decibelsChanged();

    // Compute spectrum
    computeSpectrum();
}

void LibVisualBackend::computeSpectrum()
{
    // Apply window and copy to FFT input
    for (int i = 0; i < m_fftSize; i++) {
        m_fftInput[i][0] = m_audioBuffer[i] * m_window[i]; // Real part
        m_fftInput[i][1] = 0.0; // Imaginary part
    }
    
    // Execute FFT
    fftw_execute(m_fftPlan);
    
    // Calculate magnitudes for positive frequencies only
    const int numBins = m_fftSize / 2;
    for (int i = 0; i < numBins; i++) {
        float real = m_fftOutput[i][0];
        float imag = m_fftOutput[i][1];
        float magnitude = std::sqrt(real * real + imag * imag);
        
        // Normalize and convert to 0-1 range (adjust scale as needed)
        magnitude = std::min(1.0f, magnitude / (m_fftSize / 4));
        
        m_spectrum[i] = magnitude;
    }
    
    emit spectrumChanged();
}

#include "backend.moc"