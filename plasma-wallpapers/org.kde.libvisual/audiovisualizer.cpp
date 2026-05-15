/*
 * SPDX-FileCopyrightText: 2025 VitexSoftware <vitex@vitexsoftware.cz>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include "audiovisualizer.h"
#include <QDebug>
#include <QMutexLocker>
#include <cmath>
#include <algorithm>
#include <pulse/error.h>

// ---------------------------------------------------------------------------
// Construction / destruction
// ---------------------------------------------------------------------------

AudioVisualizer::AudioVisualizer(QObject *parent)
    : QObject(parent)
{
    qDebug() << "AudioVisualizer: Initializing (async pa_stream backend)";

    m_spectrum.reserve(SPECTRUM_SIZE);
    m_waveform.reserve(BUFFER_SIZE);
    for (int i = 0; i < SPECTRUM_SIZE; ++i) m_spectrum.append(0.0);
    for (int i = 0; i < BUFFER_SIZE;   ++i) m_waveform.append(0.0);

    initFFTW();
    connectPulse();
}

AudioVisualizer::~AudioVisualizer()
{
    disconnectPulse();
    cleanupFFTW();
}

// ---------------------------------------------------------------------------
// Property getters — mutex-protected; called from Qt main thread by QML
// ---------------------------------------------------------------------------

qreal AudioVisualizer::decibels() const
{
    QMutexLocker lk(&m_mutex);
    return m_decibels;
}

qreal AudioVisualizer::level() const
{
    QMutexLocker lk(&m_mutex);
    return m_level;
}

QVariantList AudioVisualizer::spectrum() const
{
    QMutexLocker lk(&m_mutex);
    return m_spectrum;
}

QVariantList AudioVisualizer::waveform() const
{
    QMutexLocker lk(&m_mutex);
    return m_waveform;
}

// ---------------------------------------------------------------------------
// Control — Qt main thread
// ---------------------------------------------------------------------------

void AudioVisualizer::setRunning(bool running)
{
    if (m_running == running) return;
    running ? start() : stop();
}

void AudioVisualizer::start()
{
    if (m_running) return;
    if (!m_mainloop || !m_stream) {
        qWarning() << "AudioVisualizer: start() called before PA stream is ready";
        return;
    }
    pa_threaded_mainloop_lock(m_mainloop);
    pa_stream_cork(m_stream, 0, nullptr, nullptr);  // uncork = resume capture
    pa_threaded_mainloop_unlock(m_mainloop);
    m_running = true;
    emit runningChanged();
    qDebug() << "AudioVisualizer: Capture started";
}

void AudioVisualizer::stop()
{
    if (!m_running) return;
    if (m_mainloop && m_stream) {
        pa_threaded_mainloop_lock(m_mainloop);
        pa_stream_cork(m_stream, 1, nullptr, nullptr);  // cork = pause capture
        pa_threaded_mainloop_unlock(m_mainloop);
    }
    m_running = false;
    emit runningChanged();

    {
        QMutexLocker lk(&m_mutex);
        m_decibels = -60.0;
        m_level    = 0.0;
        m_spectrum.fill(0.0);
        m_waveform.fill(0.0);
    }
    emit decibelsChanged();
    emit levelChanged();
    emit spectrumChanged();
    emit waveformChanged();
    qDebug() << "AudioVisualizer: Capture stopped";
}

void AudioVisualizer::setAudioSource(const QString &source)
{
    if (m_audioSource == source) return;
    qDebug() << "AudioVisualizer: Switching source to" << source;

    const bool wasRunning = m_running;
    if (wasRunning) stop();

    m_audioSource = source;
    emit audioSourceChanged();

    if (m_mainloop && m_context) {
        pa_threaded_mainloop_lock(m_mainloop);
        if (m_stream) {
            pa_stream_disconnect(m_stream);
            pa_stream_unref(m_stream);
            m_stream = nullptr;
        }
        if (pa_context_get_state(m_context) == PA_CONTEXT_READY)
            connectStream();
        pa_threaded_mainloop_unlock(m_mainloop);
    }

    if (wasRunning) start();
}

void AudioVisualizer::setSensitivity(qreal sensitivity)
{
    if (qFuzzyCompare(m_sensitivity, sensitivity)) return;
    m_sensitivity = qBound(0.1, sensitivity, 10.0);
    emit sensitivityChanged();
}

QStringList AudioVisualizer::getAudioSources()
{
    return {QStringLiteral("default")};
}

// ---------------------------------------------------------------------------
// Device enumeration — native libpulse, no pactl subprocess
// Filters out monitor sources using PA_SOURCE_MONITOR flag.
// ---------------------------------------------------------------------------

namespace {

struct PAEnumCtx {
    pa_mainloop  *ml;
    QVariantList  sources;
};

static void enumSourceInfoCb(pa_context *, const pa_source_info *info, int eol, void *ud)
{
    auto *ctx = static_cast<PAEnumCtx *>(ud);
    if (eol > 0) {
        pa_mainloop_quit(ctx->ml, 0);
        return;
    }
    // monitor_of_sink != PA_INVALID_INDEX identifies loopback monitor sources
    if (!info || info->monitor_of_sink != PA_INVALID_INDEX)
        return;

    QVariantMap entry;
    entry[QStringLiteral("name")]        = QString::fromUtf8(info->name);
    entry[QStringLiteral("description")] = info->description
        ? QString::fromUtf8(info->description)
        : entry[QStringLiteral("name")].toString();
    ctx->sources << entry;
}

static void enumContextStateCb(pa_context *ctx, void *ud)
{
    auto *state = static_cast<PAEnumCtx *>(ud);
    switch (pa_context_get_state(ctx)) {
    case PA_CONTEXT_READY:
        pa_context_get_source_info_list(ctx, enumSourceInfoCb, ud);
        break;
    case PA_CONTEXT_FAILED:
    case PA_CONTEXT_TERMINATED:
        pa_mainloop_quit(state->ml, 1);
        break;
    default:
        break;
    }
}

} // namespace

QVariantList AudioVisualizer::getInputSources()
{
    QVariantList result;
    QVariantMap defaultEntry;
    defaultEntry[QStringLiteral("name")]        = QStringLiteral("default");
    defaultEntry[QStringLiteral("description")] = tr("Default Input Device");
    result << defaultEntry;

    pa_mainloop *ml = pa_mainloop_new();
    if (!ml) return result;

    PAEnumCtx state;
    state.ml = ml;

    pa_context *ctx = pa_context_new(pa_mainloop_get_api(ml), "AudioVisualizerEnum");
    if (!ctx) {
        pa_mainloop_free(ml);
        return result;
    }

    pa_context_set_state_callback(ctx, enumContextStateCb, &state);
    if (pa_context_connect(ctx, nullptr, PA_CONTEXT_NOFLAGS, nullptr) < 0) {
        pa_context_unref(ctx);
        pa_mainloop_free(ml);
        return result;
    }

    int retval = 0;
    pa_mainloop_run(ml, &retval);

    pa_context_disconnect(ctx);
    pa_context_unref(ctx);
    pa_mainloop_free(ml);

    for (const auto &e : std::as_const(state.sources))
        result << e;
    return result;
}

// ---------------------------------------------------------------------------
// PulseAudio async setup — threaded mainloop + pa_context + pa_stream
// ---------------------------------------------------------------------------

void AudioVisualizer::connectPulse()
{
    m_mainloop = pa_threaded_mainloop_new();
    if (!m_mainloop) {
        qWarning() << "AudioVisualizer: Failed to create PA threaded mainloop";
        return;
    }

    m_context = pa_context_new(pa_threaded_mainloop_get_api(m_mainloop), "AudioVisualizer");
    if (!m_context) {
        qWarning() << "AudioVisualizer: Failed to create PA context";
        pa_threaded_mainloop_free(m_mainloop);
        m_mainloop = nullptr;
        return;
    }

    pa_context_set_state_callback(m_context, contextStateCb, this);
    pa_threaded_mainloop_start(m_mainloop);

    pa_threaded_mainloop_lock(m_mainloop);
    pa_context_connect(m_context, nullptr, PA_CONTEXT_NOFLAGS, nullptr);
    pa_threaded_mainloop_unlock(m_mainloop);
}

void AudioVisualizer::disconnectPulse()
{
    if (!m_mainloop) return;

    pa_threaded_mainloop_lock(m_mainloop);
    if (m_stream) {
        pa_stream_set_read_callback(m_stream, nullptr, nullptr);
        pa_stream_set_state_callback(m_stream, nullptr, nullptr);
        pa_stream_disconnect(m_stream);
        pa_stream_unref(m_stream);
        m_stream = nullptr;
    }
    if (m_context) {
        pa_context_set_state_callback(m_context, nullptr, nullptr);
        pa_context_disconnect(m_context);
    }
    pa_threaded_mainloop_unlock(m_mainloop);

    pa_threaded_mainloop_stop(m_mainloop);

    if (m_context) {
        pa_context_unref(m_context);
        m_context = nullptr;
    }
    pa_threaded_mainloop_free(m_mainloop);
    m_mainloop = nullptr;
}

void AudioVisualizer::connectStream()
{
    // Called with mainloop lock held; m_context state must be PA_CONTEXT_READY.
    pa_sample_spec spec;
    spec.format   = PA_SAMPLE_S16LE;
    spec.channels = 1;
    spec.rate     = static_cast<uint32_t>(SAMPLE_RATE);

    m_stream = pa_stream_new(m_context, "Audio Visualization", &spec, nullptr);
    if (!m_stream) {
        qWarning() << "AudioVisualizer: Failed to create PA stream";
        return;
    }

    pa_stream_set_state_callback(m_stream, streamStateCb, this);
    pa_stream_set_read_callback(m_stream, streamReadCb, this);

    // Request fragments of exactly BUFFER_SIZE samples so FFT is always fed
    // a consistent block.  PA_STREAM_START_CORKED lets start()/stop() control
    // capture without reconnecting the stream.
    pa_buffer_attr attr{};
    attr.maxlength = static_cast<uint32_t>(-1);
    attr.fragsize  = sizeof(int16_t) * BUFFER_SIZE;

    const QByteArray srcBytes = m_audioSource.toUtf8();
    const char *src = (m_audioSource == QLatin1String("default")) ? nullptr : srcBytes.constData();

    const auto flags = static_cast<pa_stream_flags_t>(
        PA_STREAM_ADJUST_LATENCY | PA_STREAM_START_CORKED);

    if (pa_stream_connect_record(m_stream, src, &attr, flags) < 0) {
        qWarning() << "AudioVisualizer: connect_record failed:"
                   << pa_strerror(pa_context_errno(m_context));
        pa_stream_unref(m_stream);
        m_stream = nullptr;
    }
}

// ---------------------------------------------------------------------------
// PA callbacks — run on the PA mainloop thread
// ---------------------------------------------------------------------------

void AudioVisualizer::contextStateCb(pa_context *ctx, void *ud)
{
    auto *av = static_cast<AudioVisualizer *>(ud);
    switch (pa_context_get_state(ctx)) {
    case PA_CONTEXT_READY:
        qDebug() << "AudioVisualizer: PA context ready";
        av->connectStream();
        av->m_deviceCount = 1;
        QMetaObject::invokeMethod(av, [av] { emit av->deviceCountChanged(); },
                                  Qt::QueuedConnection);
        break;
    case PA_CONTEXT_FAILED:
    case PA_CONTEXT_TERMINATED:
        qWarning() << "AudioVisualizer: PA context failed/terminated";
        break;
    default:
        break;
    }
}

void AudioVisualizer::streamStateCb(pa_stream *s, void *ud)
{
    auto *av = static_cast<AudioVisualizer *>(ud);
    switch (pa_stream_get_state(s)) {
    case PA_STREAM_READY:
        qDebug() << "AudioVisualizer: PA stream ready, auto-starting capture";
        pa_stream_cork(s, 0, nullptr, nullptr);  // uncork: begin recording
        av->m_running = true;
        QMetaObject::invokeMethod(av, [av] { emit av->runningChanged(); },
                                  Qt::QueuedConnection);
        break;
    case PA_STREAM_FAILED:
        qWarning() << "AudioVisualizer: PA stream failed —"
                   << pa_strerror(pa_context_errno(av->m_context));
        av->m_running = false;
        QMetaObject::invokeMethod(av, [av] { emit av->runningChanged(); },
                                  Qt::QueuedConnection);
        break;
    default:
        break;
    }
}

void AudioVisualizer::streamReadCb(pa_stream *s, size_t /*nbytes*/, void *ud)
{
    auto *av = static_cast<AudioVisualizer *>(ud);

    const void *data;
    size_t length;
    if (pa_stream_peek(s, &data, &length) < 0) return;

    if (!data) {
        // Hole in the stream — consume and ignore
        if (length > 0) pa_stream_drop(s);
        return;
    }

    const int nSamples = std::min(static_cast<int>(length / sizeof(int16_t)), BUFFER_SIZE);
    const auto *samples = static_cast<const int16_t *>(data);
    const qreal sens = av->m_sensitivity;

    // Normalize to [-1.0, 1.0] into the FFTW input buffer
    for (int i = 0; i < nSamples; ++i)
        av->m_fftIn[i] = samples[i] / 32768.0;
    for (int i = nSamples; i < BUFFER_SIZE; ++i)
        av->m_fftIn[i] = 0.0;

    pa_stream_drop(s);

    // --- Decibels / level ---
    double rms = 0.0;
    for (int i = 0; i < nSamples; ++i)
        rms += av->m_fftIn[i] * av->m_fftIn[i];
    rms = std::sqrt(rms / nSamples);
    const qreal db  = rms > 0.0
        ? qBound(-60.0, 20.0 * std::log10(rms * sens), 0.0)
        : -60.0;
    const qreal lvl = qBound(0.0, (db + 60.0) / 60.0, 1.0);

    // --- FFT spectrum ---
    fftw_execute(av->m_fftPlan);
    const int specBins = std::min(SPECTRUM_SIZE, BUFFER_SIZE / 2);
    QVariantList spec(SPECTRUM_SIZE, QVariant(0.0));
    for (int i = 0; i < specBins; ++i) {
        const double re  = av->m_fftOut[i][0];
        const double im  = av->m_fftOut[i][1];
        double mag = std::sqrt(re * re + im * im) / BUFFER_SIZE;
        mag *= sens;
        mag  = std::log10(mag + 1e-10) * 20.0;
        spec[i] = qMax(0.0, (mag + 100.0) / 100.0);
    }

    // --- Waveform ---
    QVariantList wave(BUFFER_SIZE, QVariant(0.0));
    for (int i = 0; i < nSamples; ++i)
        wave[i] = av->m_fftIn[i] * sens;

    // Publish results — brief lock, then post signal to Qt thread
    {
        QMutexLocker lk(&av->m_mutex);
        av->m_decibels = db;
        av->m_level    = lvl;
        av->m_spectrum = std::move(spec);
        av->m_waveform = std::move(wave);
    }

    QMetaObject::invokeMethod(av, &AudioVisualizer::onAudioProcessed, Qt::QueuedConnection);
}

// ---------------------------------------------------------------------------
// Qt main thread — emit signals after PA callback populated shared data
// ---------------------------------------------------------------------------

void AudioVisualizer::onAudioProcessed()
{
    emit decibelsChanged();
    emit levelChanged();
    emit spectrumChanged();
    emit waveformChanged();
}

// ---------------------------------------------------------------------------
// FFTW
// ---------------------------------------------------------------------------

void AudioVisualizer::initFFTW()
{
    m_fftIn  = fftw_alloc_real(BUFFER_SIZE);
    m_fftOut = fftw_alloc_complex(BUFFER_SIZE / 2 + 1);
    if (!m_fftIn || !m_fftOut) {
        qCritical() << "AudioVisualizer: Failed to allocate FFTW buffers";
        return;
    }
    m_fftPlan = fftw_plan_dft_r2c_1d(BUFFER_SIZE, m_fftIn, m_fftOut, FFTW_ESTIMATE);
    if (!m_fftPlan)
        qCritical() << "AudioVisualizer: Failed to create FFTW plan";
}

void AudioVisualizer::cleanupFFTW()
{
    if (m_fftPlan) { fftw_destroy_plan(m_fftPlan); m_fftPlan = nullptr; }
    if (m_fftIn)   { fftw_free(m_fftIn);            m_fftIn   = nullptr; }
    if (m_fftOut)  { fftw_free(m_fftOut);           m_fftOut  = nullptr; }
}

#include "audiovisualizer.moc"
