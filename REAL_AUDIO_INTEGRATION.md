# Audio Backend — Implementation Notes

Technical reference for the `AudioVisualizer` C++ backend. See the [README](README.md) for user-facing documentation.

## Architecture

The backend is a single `AudioVisualizer : QObject` class registered as a `QML_ELEMENT`. It owns:

- a `pa_threaded_mainloop` (runs on its own OS thread)
- a `pa_context` connected to the PulseAudio/PipeWire socket
- a `pa_stream` that delivers audio frames via callback

No QTimer is involved. Audio arrives at `streamReadCb()` on the PA thread as soon as PulseAudio/PipeWire has a full fragment ready.

## Thread model

```
Qt main thread                  PA mainloop thread
──────────────────              ──────────────────────────────────
QML property reads              contextStateCb()
  └─ QMutexLocker lk(m_mutex)     └─ connectStream()
  └─ return m_spectrum / …       streamStateCb()
                                   └─ pa_stream_cork(s, 0, …)  ← uncork
AudioVisualizer::start()        streamReadCb()
  └─ mainloop_lock()              └─ pa_stream_peek()
  └─ pa_stream_cork(0)            └─ normalize, RMS, FFT
  └─ mainloop_unlock()            └─ QMutexLocker lk(m_mutex)
                                  └─ m_spectrum = std::move(spec)
AudioVisualizer::stop()         └─ mainloop_unlock()
  └─ pa_stream_cork(1)          └─ invokeMethod(onAudioProcessed,
                                               QueuedConnection)
onAudioProcessed()              ← posted back to Qt main thread
  └─ emit spectrumChanged()
  └─ emit levelChanged()
  └─ emit decibelsChanged()
  └─ emit waveformChanged()
```

Key rule: emit signals only from the Qt main thread. The PA callback uses `QMetaObject::invokeMethod(..., Qt::QueuedConnection)` to post `onAudioProcessed()` to the main thread after writing shared data under the mutex.

## PipeWire compatibility

The code uses only the stable `libpulse` C API (`<pulse/pulseaudio.h>`). PipeWire ships a `pipewire-pulse` service that implements the full PulseAudio protocol on the same Unix socket. As far as `libpulse` is concerned there is no difference — the same `pa_context_connect()` / `pa_stream_connect_record()` calls work on both daemons.

Device enumeration (`getInputSources()`) uses `pa_context_get_source_info_list()` directly rather than spawning a `pactl` subprocess. Monitor sources (loopback captures of sinks) are excluded by checking:

```cpp
if (info->monitor_of_sink != PA_INVALID_INDEX)
    return;  // skip monitor
```

This field is available in all supported versions of libpulse and works identically under PipeWire.

## Audio parameters

| Constant | Value | Notes |
|---|---|---|
| `SAMPLE_RATE` | 44100 Hz | set in `pa_sample_spec` |
| `BUFFER_SIZE` | 1024 samples | fragment size = `sizeof(int16_t) * 1024` |
| `SPECTRUM_SIZE` | 256 bins | FFT output truncated to first 256 of 512 bins |

The fragment size keeps latency around 23 ms at 44100 Hz. `PA_STREAM_ADJUST_LATENCY` lets PulseAudio/PipeWire round to the nearest hardware period without us having to negotiate it explicitly.

## Stream lifecycle

```
connectPulse()
  pa_threaded_mainloop_new()
  pa_context_new()
  pa_context_set_state_callback(contextStateCb)
  pa_threaded_mainloop_start()         ← PA thread starts here
  pa_context_connect()

contextStateCb / PA_CONTEXT_READY
  connectStream()                      ← called with mainloop lock held
    pa_stream_new(spec: S16LE 44100 1ch)
    pa_stream_set_read_callback(streamReadCb)
    pa_stream_connect_record(PA_STREAM_START_CORKED | PA_STREAM_ADJUST_LATENCY)

streamStateCb / PA_STREAM_READY
  pa_stream_cork(s, 0, …)             ← uncork: capture begins automatically
  m_running = true

streamReadCb (every ~23 ms)
  pa_stream_peek() → process → pa_stream_drop()

stop()
  pa_stream_cork(s, 1, …)             ← cork: capture pauses, stream stays connected

disconnectPulse()
  pa_stream_disconnect() + pa_stream_unref()
  pa_context_disconnect()
  pa_threaded_mainloop_stop()
  pa_context_unref()
  pa_threaded_mainloop_free()
```

## DSP pipeline (per frame, PA thread)

1. Normalize `int16_t` samples to `[-1.0, 1.0]` into `m_fftIn[BUFFER_SIZE]`
2. Compute RMS → `dB = 20 * log10(rms * sensitivity)`, clamped to `[-60, 0]`
3. `fftw_execute(m_fftPlan)` — real-to-complex r2c on `BUFFER_SIZE` samples
4. For each bin `i` in `[0, SPECTRUM_SIZE)`: `mag = sqrt(re²+im²) / BUFFER_SIZE * sens`; convert to `[0,1]` via `(20*log10(mag+1e-10) + 100) / 100`
5. Lock `m_mutex` → move `spec` and `wave` into member fields → unlock
6. `QMetaObject::invokeMethod(this, &AudioVisualizer::onAudioProcessed, Qt::QueuedConnection)`

## Build dependencies

| Library | pkg-config name | Purpose |
|---|---|---|
| libpulse | `libpulse` | PulseAudio/PipeWire async API |
| libfftw3 | `fftw3` | Real-to-complex FFT |
| Qt6 Qml | (cmake target) | QML element registration |

`libpulse-simple` is not required (the former `pa_simple_read` blocking API was removed in v1.1.6).

## Diagnostics

```bash
# Check that the backend symbols are present in the installed library
bash test_qml_module.sh

# Full system check including PipeWire sources
./diagnostics.sh --quick

# Trace PA connection events (run before starting Plasma)
PULSE_LOG=4 plasmashell 2>&1 | grep AudioVisualizer
```
