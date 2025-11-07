#include "probe.h"
#include <pulse/simple.h>
#include <pulse/error.h>
#include <cmath>

static pa_sample_spec makeSpec() {
    pa_sample_spec ss; ss.format=PA_SAMPLE_FLOAT32LE; ss.rate=48000; ss.channels=1; return ss; }

AudioLevelProbe::AudioLevelProbe(QObject *parent): QObject(parent) {
    connect(&m_timer,&QTimer::timeout,this,&AudioLevelProbe::poll);
    m_timer.setInterval(100);
    start();
}
AudioLevelProbe::~AudioLevelProbe(){ stop(); }

void AudioLevelProbe::start(){
    if(m_running.load()) return;
    int error=0; pa_sample_spec ss=makeSpec();
    m_pa = pa_simple_new(nullptr,"LibVisualProbe",PA_STREAM_RECORD,nullptr,"probe",&ss,nullptr,nullptr,&error);
    if(!m_pa){ return; }
    m_running.store(true); m_timer.start();
}
void AudioLevelProbe::stop(){
    if(!m_running.load()) return;
    m_timer.stop(); if(m_pa){ pa_simple_free(m_pa); m_pa=nullptr; }
    m_running.store(false);
}

void AudioLevelProbe::poll(){
    if(!m_pa) return;
    float buf[512]; int error=0; if(pa_simple_read(m_pa,buf,sizeof(buf),&error)<0){ stop(); return; }
    int n = int(sizeof(buf)/sizeof(float)); double sum=0; for(int i=0;i<n;i++){ double v=buf[i]; sum+=v*v; }
    double rms = n? std::sqrt(sum/n):0.0; double db = (rms>1e-9)? 20.0*std::log10(rms):-90.0;
    // Smooth (EMA)
    const double alpha=0.3; m_dbSmoothed = alpha*db + (1-alpha)*m_dbSmoothed;
    emit decibelsChanged();
}

#include <qqml.h>
void LibVisualProbePlugin::registerTypes(const char *uri){
    qmlRegisterSingletonType<AudioLevelProbe>(uri,1,0,"Probe",[](QQmlEngine*,QJSEngine*)->QObject*{ return new AudioLevelProbe; });
}
