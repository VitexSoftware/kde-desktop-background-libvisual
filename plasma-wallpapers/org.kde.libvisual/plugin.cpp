/*
 * SPDX-FileCopyrightText: 2025 VitexSoftware <vitex@vitexsoftware.cz>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include "plugin.h"
#include "backend.h"

#include <KPluginFactory>
#include <QDebug>
#include <cmath>
#include <pulse/simple.h>
#include <pulse/error.h>
#include <fftw3.h>
#include <cstring>
#include <QQmlEngine>
#include <QtQml/qqml.h>
#include <QQmlExtensionPlugin>

namespace {
    static pa_sample_spec makeSpec() {
        pa_sample_spec ss; ss.format = PA_SAMPLE_FLOAT32LE; ss.rate = 48000; ss.channels = 1; return ss; }
}

LibVisualWallpaper::LibVisualWallpaper(QObject *parent) : QObject(parent) {
    qDebug() << "LibVisualWallpaper loaded";
    connect(&m_pollTimer, &QTimer::timeout, this, &LibVisualWallpaper::audioPollTick);
    m_pollTimer.setInterval(100); // 10 Hz updates sufficient for UI

    // Prepare FFT buffers
    m_fftBuffer.resize(m_fftSize);
    m_window.resize(m_fftSize);
    m_fftInput.resize(m_fftSize);
    m_fftOutputReal.resize(m_fftSize);
    m_fftOutputImag.resize(m_fftSize);
    m_magnitude.resize(m_fftSize/2);
    for (size_t i=0;i<m_fftSize;i++) {
        m_window[i] = 0.5 * (1.0 - std::cos(2.0*M_PI * double(i)/(m_fftSize-1))); // Hann
    }
    m_fftPlan = fftw_plan_dft_r2c_1d(int(m_fftSize), m_fftInput.data(), reinterpret_cast<fftw_complex*>(m_fftOutputReal.data()), FFTW_MEASURE);

    startAudioLevel();
}

void LibVisualWallpaper::startAudioLevel() {
    if (m_running.load()) return;
    int error = 0;
    pa_sample_spec ss = makeSpec();
    // Use default source monitor (may need explicit selection later)
    m_pa = pa_simple_new(nullptr, "LibVisualWallpaper", PA_STREAM_RECORD, nullptr, "level", &ss, nullptr, nullptr, &error);
    if (!m_pa) {
        qWarning() << "PulseAudio init failed" << error;
        return;
    }
    m_running.store(true);
    m_pollTimer.start();
    emit audioActiveChanged();
}

void LibVisualWallpaper::stopAudioLevel() {
    if (!m_running.load()) return;
    m_pollTimer.stop();
    if (m_pa) { pa_simple_free(m_pa); m_pa = nullptr; }
    m_running.store(false);
    emit audioActiveChanged();
}

QVariantList LibVisualWallpaper::spectrumVariant() const {
    QVariantList list; list.reserve(int(m_magnitude.size()));
    for (float v : m_magnitude) list.push_back(v);
    return list;
}

void LibVisualWallpaper::audioPollTick() {
    if (!m_pa) return;
    float buffer[1024];
    int error = 0;
    size_t bytes = sizeof(buffer);
    if (pa_simple_read(m_pa, buffer, bytes, &error) < 0) {
        qWarning() << "pa_simple_read failed" << error;
        stopAudioLevel();
        return;
    }
    // Compute RMS -> dBFS
    double sum = 0.0;
    int samples = int(bytes / sizeof(float));
    for (int i = 0; i < samples; ++i) {
        double v = buffer[i];
        sum += v * v;
    }
    double rms = samples ? std::sqrt(sum / samples) : 0.0;
    double db = (rms > 1e-9) ? 20.0 * std::log10(rms) : -90.0;
    if (qFabs(db - m_decibels) > 0.25) { // reduce UI churn
        m_decibels = db;
        emit decibelsChanged();
    }

    // Accumulate for FFT
    size_t toCopy = std::min<size_t>(samples, m_fftSize - m_fftFill);
    std::memcpy(m_fftBuffer.data() + m_fftFill, buffer, toCopy * sizeof(float));
    m_fftFill += toCopy;
    if (m_fftFill == m_fftSize) {
        computeSpectrum(m_fftBuffer.data(), int(m_fftSize));
        m_fftFill = 0; // simple reset (could implement overlap for smoother animation)
    }
}

void LibVisualWallpaper::computeSpectrum(const float *samples, int count) {
    if (count != int(m_fftSize) || !m_fftPlan) return;
    for (int i=0;i<count;i++) {
        m_fftInput[i] = double(samples[i]) * m_window[i];
    }
    fftw_execute(m_fftPlan);
    // fftw_plan_dft_r2c stores output in first (N/2+1) complex values; we used reinterpret to real array; adjust access
    auto *complexOut = reinterpret_cast<fftw_complex*>(m_fftOutputReal.data());
    int bins = int(m_magnitude.size());
    for (int k=0;k<bins;k++) {
        double re = complexOut[k][0];
        double im = complexOut[k][1];
        double mag = std::sqrt(re*re + im*im);
        // Log scale compression
        double db = (mag > 1e-9) ? 20.0*std::log10(mag) : -120.0;
        // Normalize to 0..1 (assuming -90dB floor, 0dB peak)
        double norm = (db + 90.0)/90.0; if (norm < 0) norm = 0; if (norm > 1) norm = 1;
        m_magnitude[k] = float(norm);
    }
    emit spectrumChanged();
}

// Plugin class for wallpaper registration
class LibVisualWallpaperPackage : public QObject {
    Q_OBJECT
public:
    LibVisualWallpaperPackage(QObject *parent = nullptr) : QObject(parent) {
        qDebug() << "LibVisual wallpaper package loaded";
        // Register QML types here
        qmlRegisterType<LibVisualWallpaper>("LibVisualBackend", 1, 0, "LibVisualWallpaper");
        qmlRegisterType<LibVisualBackend>("LibVisualBackend", 1, 0, "LibVisualBackend"); 
        qDebug() << "LibVisual QML types registered";
    }
};

// Use dedicated plugin JSON (separate from package metadata.json) for reliable embedding
K_PLUGIN_CLASS_WITH_JSON(LibVisualWallpaperPackage, "plasma_wallpaper_org.kde.libvisual.json")

#include "plugin.moc"