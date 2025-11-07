#include "audiovisualizerbackend.h"
#include <QDebug>
#include <QThread>
#include <QCoreApplication>
#include <QQmlEngine>
#include <QtMath>
#include <cmath>
#include <algorithm>

// AudioProcessor Implementation
AudioProcessor::AudioProcessor(QObject* parent)
    : QObject(parent)
    , m_pulseAudio(nullptr)
    , m_processTimer(new QTimer(this))
    , m_fftOutput(nullptr)
{
    m_fftInput.resize(FFT_SIZE);
    m_spectrum.resize(SPECTRUM_BARS, 0.0);
    m_smoothSpectrum.resize(SPECTRUM_BARS, 0.0);
    
    // Allocate FFTW arrays
    m_fftOutput = (fftw_complex*)fftw_malloc(sizeof(fftw_complex) * (FFT_SIZE / 2 + 1));
    m_fftPlan = fftw_plan_dft_r2c_1d(FFT_SIZE, m_fftInput.data(), m_fftOutput, FFTW_ESTIMATE);
    
    connect(m_processTimer, &QTimer::timeout, this, &AudioProcessor::processAudio);
    m_processTimer->setInterval(20); // 50 FPS processing
}

AudioProcessor::~AudioProcessor() {
    stop();
    if (m_fftPlan) {
        fftw_destroy_plan(m_fftPlan);
    }
    if (m_fftOutput) {
        fftw_free(m_fftOutput);
    }
    fftw_cleanup();
}

bool AudioProcessor::initialize() {
    // Initialize PulseAudio
    pa_sample_spec ss;
    ss.format = PA_SAMPLE_S16LE;
    ss.channels = 2;
    ss.rate = 44100;
    
    pa_buffer_attr attr;
    attr.maxlength = AUDIO_BUFFER_SIZE * sizeof(int16_t) * 2 * 4;
    attr.fragsize = AUDIO_BUFFER_SIZE * sizeof(int16_t) * 2;
    attr.tlength = (uint32_t) -1;
    attr.prebuf = (uint32_t) -1;
    attr.minreq = (uint32_t) -1;
    
    int error;
    m_pulseAudio = pa_simple_new(nullptr, "Plasma Audio Visualizer", PA_STREAM_RECORD,
                                nullptr, "Wallpaper Visualization", &ss, nullptr, &attr, &error);
    
    if (!m_pulseAudio) {
        qWarning() << "Failed to create PulseAudio connection:" << pa_strerror(error);
        return false;
    }
    
    qDebug() << "Audio processor initialized successfully";
    return true;
}

void AudioProcessor::start() {
    if (m_pulseAudio && !m_processTimer->isActive()) {
        m_processTimer->start();
        qDebug() << "Audio processing started";
    }
}

void AudioProcessor::stop() {
    if (m_processTimer->isActive()) {
        m_processTimer->stop();
    }
    
    if (m_pulseAudio) {
        pa_simple_free(m_pulseAudio);
        m_pulseAudio = nullptr;
    }
    qDebug() << "Audio processing stopped";
}

void AudioProcessor::processAudio() {
    if (!m_pulseAudio) return;
    
    std::vector<int16_t> buffer(AUDIO_BUFFER_SIZE);
    
    int error;
    if (pa_simple_read(m_pulseAudio, buffer.data(), 
                      buffer.size() * sizeof(int16_t), &error) < 0) {
        qWarning() << "Failed to read audio:" << pa_strerror(error);
        return;
    }
    
    QMutexLocker locker(&m_dataMutex);
    
    // Convert to double and prepare for FFT (use only left channel)
    for (int i = 0; i < FFT_SIZE && i * 2 < buffer.size(); ++i) {
        m_fftInput[i] = static_cast<double>(buffer[i * 2]) / 32768.0;
    }
    
    // Perform FFT
    fftw_execute(m_fftPlan);
    
    // Calculate spectrum magnitudes
    for (int i = 0; i < SPECTRUM_BARS; ++i) {
        int fftIndex = i * (FFT_SIZE / 2) / SPECTRUM_BARS;
        if (fftIndex < FFT_SIZE / 2) {
            double real = m_fftOutput[fftIndex][0];
            double imag = m_fftOutput[fftIndex][1];
            double magnitude = sqrt(real * real + imag * imag);
            
            // Apply logarithmic scaling
            magnitude = log10(1.0 + magnitude * 9.0);
            
            // Smooth the spectrum
            m_smoothSpectrum[i] = 0.7 * m_smoothSpectrum[i] + 0.3 * magnitude;
        }
    }
    
    // Convert to QVariantList for QML
    QVariantList spectrumList;
    for (double value : m_smoothSpectrum) {
        spectrumList.append(QVariant(value));
    }
    
    emit spectrumDataReady(spectrumList);
}

// AudioVisualizerBackend Implementation
AudioVisualizerBackend::AudioVisualizerBackend(QObject* parent)
    : QObject(parent)
    , m_processor(nullptr)
    , m_audioThread(new QThread(this))
    , m_testTimer(new QTimer(this))
    , m_isTestMode(false)
    , m_hasNewData(false)
{
    m_processor = new AudioProcessor();
    m_processor->moveToThread(m_audioThread);
    
    connect(m_audioThread, &QThread::started, m_processor, &AudioProcessor::initialize);
    connect(m_processor, &AudioProcessor::spectrumDataReady, 
            this, &AudioVisualizerBackend::onSpectrumDataReady);
    
    connect(m_testTimer, &QTimer::timeout, [this]() {
        setupTestMode();
    });
    
    qDebug() << "AudioVisualizerBackend created";
}

AudioVisualizerBackend::~AudioVisualizerBackend() {
    stopVisualization();
    if (m_audioThread->isRunning()) {
        m_audioThread->quit();
        m_audioThread->wait(3000);
    }
    delete m_processor;
}

void AudioVisualizerBackend::startVisualization() {
    qDebug() << "Starting visualization...";
    
    if (!m_audioThread->isRunning()) {
        m_audioThread->start();
    }
    
    // Give thread time to start
    QTimer::singleShot(500, [this]() {
        QMetaObject::invokeMethod(m_processor, "start", Qt::QueuedConnection);
    });
}

void AudioVisualizerBackend::stopVisualization() {
    qDebug() << "Stopping visualization...";
    
    if (m_testTimer->isActive()) {
        m_testTimer->stop();
        m_isTestMode = false;
    }
    
    QMetaObject::invokeMethod(m_processor, "stop", Qt::QueuedConnection);
}

QStringList AudioVisualizerBackend::getAudioDevices() {
    // TODO: Query actual PulseAudio devices
    return QStringList() << "Default" << "Built-in Audio" << "USB Audio";
}

void AudioVisualizerBackend::testMode() {
    qDebug() << "Activating test mode";
    m_isTestMode = true;
    m_testTimer->start(50); // 20 FPS for test
}

bool AudioVisualizerBackend::hasNewData() {
    bool hasNew = m_hasNewData.load();
    m_hasNewData.store(false);
    return hasNew;
}

AudioVisualizerBackend* AudioVisualizerBackend::createInstance() {
    return new AudioVisualizerBackend();
}

void AudioVisualizerBackend::onSpectrumDataReady(const QVariantList& spectrum) {
    m_hasNewData.store(true);
    emit spectrumUpdated(spectrum);
}

void AudioVisualizerBackend::setupTestMode() {
    if (!m_isTestMode) return;
    
    // Generate fake spectrum data for testing
    QVariantList fakeSpectrum;
    double time = QDateTime::currentMSecsSinceEpoch() * 0.001;
    
    for (int i = 0; i < 128; ++i) {
        double value = sin(time + i * 0.1) * 0.5 + 0.5;
        value *= (sin(time * 0.5 + i * 0.05) * 0.3 + 0.7);
        fakeSpectrum.append(QVariant(value));
    }
    
    emit spectrumUpdated(fakeSpectrum);
}

// AudioVisualizerPlugin Implementation
AudioVisualizerPlugin::AudioVisualizerPlugin(QObject* parent)
    : QObject(parent)
{
    registerTypes();
}

AudioVisualizerPlugin::~AudioVisualizerPlugin() {
    // Cleanup if needed
}

void AudioVisualizerPlugin::registerTypes() {
    qmlRegisterType<AudioVisualizerBackend>("org.kde.plasma.audiovisualizer", 1, 0, "AudioVisualizerBackend");
    qmlRegisterSingletonType<AudioVisualizerBackend>("org.kde.plasma.audiovisualizer", 1, 0, "AudioVisualizerBackend", 
        [](QQmlEngine*, QJSEngine*) -> QObject* {
            return new AudioVisualizerBackend();
        });
}