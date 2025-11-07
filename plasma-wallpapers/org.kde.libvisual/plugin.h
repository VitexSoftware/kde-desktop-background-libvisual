/*
 * SPDX-FileCopyrightText: 2025 VitexSoftware <vitex@vitexsoftware.cz>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#ifndef LIBVISUALIZATIONWALLPAPER_H
#define LIBVISUALIZATIONWALLPAPER_H

#include <QObject>
#include <QColor>
#include <QTimer>
#include <atomic>
#include <vector>
#include <QVariant>
#include <QtQml/qqml.h>

// Forward declare fftw_plan to avoid including fftw3 header in MOC translation units
extern "C" { typedef struct fftw_plan_s *fftw_plan; }

// Forward declare PulseAudio simple API types (to avoid heavy includes here)
struct pa_simple;


// Plasma 6 no longer ships a public C++ Wallpaper base class; we keep a QObject plugin
// for future libvisual integration (exposed to QML later). If Plasma::Wallpaper becomes
// available again, this class can be adapted to inherit it.
class LibVisualWallpaper : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(double decibels READ decibels NOTIFY decibelsChanged)
    Q_PROPERTY(QVariantList spectrum READ spectrumVariant NOTIFY spectrumChanged)
    Q_PROPERTY(int fftSize READ fftSize CONSTANT)
    Q_PROPERTY(bool audioActive READ audioActive NOTIFY audioActiveChanged)
public:
    explicit LibVisualWallpaper(QObject *parent = nullptr);
    ~LibVisualWallpaper() override = default;

    double decibels() const { return m_decibels; }
    QVariantList spectrumVariant() const;
    int fftSize() const { return static_cast<int>(m_fftSize); }
    bool audioActive() const { return m_running.load(); }

public slots:
    void startAudioLevel();
    void stopAudioLevel();

signals:
    void decibelsChanged();
    void spectrumChanged();
    void audioActiveChanged();

private:
    void audioPollTick();
    void computeSpectrum(const float *samples, int count);
    pa_simple *m_pa = nullptr;
    QTimer m_pollTimer;
    double m_decibels = -90.0; // silence default
    std::atomic<bool> m_running{false};

    // FFT related
    size_t m_fftSize = 2048;
    std::vector<float> m_fftBuffer;  // ring accumulation
    size_t m_fftFill = 0;
    std::vector<double> m_window;    // Hann window
    std::vector<double> m_fftInput;  // double for FFTW
    std::vector<double> m_fftOutputReal;
    std::vector<double> m_fftOutputImag;
    std::vector<float>  m_magnitude; // compressed mags
    fftw_plan m_fftPlan = nullptr;

    // Future: expose properties to QML (e.g. audio levels)
signals:
    void frameReady();
};

#endif // LIBVISUALIZATIONWALLPAPER_H