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

class LibVisualBackend : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(qreal decibels READ decibels NOTIFY decibelsChanged)
    Q_PROPERTY(QVariantList spectrum READ spectrum NOTIFY spectrumChanged)
    Q_PROPERTY(int fftSize READ fftSize CONSTANT)
    Q_PROPERTY(bool audioActive READ audioActive NOTIFY audioActiveChanged)

public:
    explicit LibVisualBackend(QObject *parent = nullptr);
    ~LibVisualBackend();

    qreal decibels() const { return m_decibels; }
    QVariantList spectrum() const { return m_spectrum; }
    int fftSize() const { return m_fftSize; }
    bool audioActive() const { return m_audioActive; }

    Q_INVOKABLE void startAudioLevel();

signals:
    void decibelsChanged();
    void spectrumChanged();
    void audioActiveChanged();

private slots:
    void audioPollTick();

private:
    void computeSpectrum();

    QTimer *m_audioTimer;
    qreal m_decibels;
    QVariantList m_spectrum;
    bool m_audioActive;

    // Audio capture
    pa_simple *m_pulseCapture;
    static const int m_fftSize = 2048;
    float m_audioBuffer[m_fftSize];
    
    // FFT processing
    fftw_complex *m_fftInput;
    fftw_complex *m_fftOutput;
    fftw_plan m_fftPlan;
    float m_window[m_fftSize];
};