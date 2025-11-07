#ifndef AUDIOVISUALIZERBACKEND_H
#define AUDIOVISUALIZERBACKEND_H

#include <QObject>
#include <QThread>
#include <QTimer>
#include <QStringList>
#include <QVariantList>
#include <QMutex>
#include <QQmlEngine>
#include <fftw3.h>
#include <pulse/simple.h>
#include <pulse/error.h>
#include <vector>
#include <atomic>

class AudioProcessor : public QObject {
    Q_OBJECT

public:
    explicit AudioProcessor(QObject* parent = nullptr);
    ~AudioProcessor();

    bool initialize();
    void start();
    void stop();

signals:
    void spectrumDataReady(const QVariantList& spectrum);

private slots:
    void processAudio();

private:
    pa_simple* m_pulseAudio;
    QTimer* m_processTimer;
    std::vector<double> m_fftInput;
    fftw_complex* m_fftOutput;
    fftw_plan m_fftPlan;
    std::vector<double> m_spectrum;
    std::vector<double> m_smoothSpectrum;
    QMutex m_dataMutex;
    
    static constexpr int FFT_SIZE = 512;
    static constexpr int SPECTRUM_BARS = 128;
    static constexpr int AUDIO_BUFFER_SIZE = 1024;
};

class AudioVisualizerBackend : public QObject {
    Q_OBJECT

public:
    explicit AudioVisualizerBackend(QObject* parent = nullptr);
    ~AudioVisualizerBackend();

    Q_INVOKABLE void startVisualization();
    Q_INVOKABLE void stopVisualization();
    Q_INVOKABLE QStringList getAudioDevices();
    Q_INVOKABLE void testMode();
    Q_INVOKABLE bool hasNewData();
    Q_INVOKABLE static AudioVisualizerBackend* createInstance();

signals:
    void spectrumUpdated(const QVariantList& spectrum);

private slots:
    void onSpectrumDataReady(const QVariantList& spectrum);

private:
    AudioProcessor* m_processor;
    QThread* m_audioThread;
    QTimer* m_testTimer;
    bool m_isTestMode;
    std::atomic<bool> m_hasNewData;
    
    void setupTestMode();
};

class AudioVisualizerPlugin : public QObject {
    Q_OBJECT

public:
    AudioVisualizerPlugin(QObject* parent = nullptr);
    ~AudioVisualizerPlugin();

    void registerTypes();
};

#endif // AUDIOVISUALIZERBACKEND_H