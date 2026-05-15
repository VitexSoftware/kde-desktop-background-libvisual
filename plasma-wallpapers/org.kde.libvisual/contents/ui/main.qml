/*
 * SPDX-FileCopyrightText: 2025 VitexSoftware <vitex@vitexsoftware.cz>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Controls
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import AudioVisualizer 1.0

WallpaperItem {
    id: root
    
    // Configuration properties bound to main.xml
    property int visualizationType: root.configuration.visualizationType
    property real audioSensitivity: root.configuration.audioSensitivity  
    property bool showInfo: root.configuration.showInfo
    property string audioSource: root.configuration.audioSource
    property int colorScheme: root.configuration.colorScheme
    property bool showStatusIndicator: root.configuration.showStatusIndicator
    property real t: 0
    
    // Audio backend configuration
    property bool useRealAudio: true   // Enable real audio by default now that module works
    property bool debugAudio: true   // Enable debug logging temporarily
    
    // Real audio backend instance
    AudioVisualizer {
        id: audioBackend
        
        Component.onCompleted: {
            if (debugAudio) {
                console.log("AudioVisualizer - Audio backend initialized successfully!")
                console.log("AudioVisualizer - Device count:", deviceCount)
                console.log("AudioVisualizer - Initial running state:", running)
                console.log("AudioVisualizer - Unified module loaded successfully!")
            }
            // Start audio processing
            start()
        }
        
        onRunningChanged: {
            if (root.debugAudio) {
                // console.log("AudioVisualizer - Running state changed:", running)
            }
        }
        
        onDecibelsChanged: {
            // Debug output completely disabled
            // if (root.debugAudio && Math.random() < 0.01) { 
            //     // console.log("AudioVisualizer - Audio level:", decibels.toFixed(1), "dB")
            // }
        }
    }

        // Configuration change handlers
    onVisualizationTypeChanged: {
        if (root.debugAudio) {
            // console.log("Wallpaper - Visualization type changed to:", visualizationType)
        }
    }
    
    onAudioSensitivityChanged: {
        if (root.debugAudio) {
            // console.log("Wallpaper - Audio sensitivity changed to:", audioSensitivity)
        }
    }
    
    onShowInfoChanged: {
        if (root.debugAudio) {
            // console.log("Wallpaper - Show info changed to:", showInfo)
        }
    }
    
    onAudioSourceChanged: {
        if (root.debugAudio) {
            // console.log("Wallpaper - Audio source changed to:", audioSource)
        }
    }

    // Fill the available wallpaper space
    anchors.fill: parent

    // Enhanced timer with real audio integration
    Timer {
        interval: 16; running: true; repeat: true // 60fps refresh rate
        onTriggered: {
            root.t += 0.016
            updateAudioLevels()
        }
    }
    
    // Comprehensive audio processing function
    function updateAudioLevels() {
        if (root.useRealAudio && audioBackend && audioBackend.running) {
            // Use real audio data from LibVisualBackend
            updateRealAudioLevels()
        } else {
            // Fallback to simulation
            updateSimulatedAudioLevels()
        }
    }
    
    function updateRealAudioLevels() {
        // Convert decibels to linear scale (dB range typically -60 to 0)
        // Normalize to 0-1 range and apply sensitivity
        const dbNormalized = Math.max(0, (audioBackend.decibels + 60) / 60)
        
        // Add noise threshold - only show activity above meaningful levels
        const noiseThreshold = 0.15  // 15% threshold to filter out background noise
        const rawLevel = dbNormalized * root.audioSensitivity
        root.audioPeak = rawLevel > noiseThreshold ? Math.max(0, rawLevel - noiseThreshold) / (1 - noiseThreshold) : 0
        
        // Extract frequency band levels from spectrum
        if (audioBackend.spectrum && audioBackend.spectrum.length >= 64) {
            // Bass: bins 0-15 (roughly 0-1kHz)
            let bassSum = 0
            for (let i = 0; i < 16; i++) {
                bassSum += audioBackend.spectrum[i] || 0
            }
            const rawBass = (bassSum / 16) * root.audioSensitivity
            root.bassLevel = rawBass > noiseThreshold ? Math.max(0, rawBass - noiseThreshold) / (1 - noiseThreshold) : 0
            
            // Mid: bins 16-39 (roughly 1-4kHz)  
            let midSum = 0
            for (let i = 16; i < 40; i++) {
                midSum += audioBackend.spectrum[i] || 0
            }
            const rawMid = (midSum / 24) * root.audioSensitivity
            root.midLevel = rawMid > noiseThreshold ? Math.max(0, rawMid - noiseThreshold) / (1 - noiseThreshold) : 0
            
            // Treble: bins 40-63 (roughly 4-8kHz)
            let trebleSum = 0
            for (let i = 40; i < Math.min(64, audioBackend.spectrum.length); i++) {
                trebleSum += audioBackend.spectrum[i] || 0
            }
            const rawTreble = (trebleSum / 24) * root.audioSensitivity
            root.trebleLevel = rawTreble > noiseThreshold ? Math.max(0, rawTreble - noiseThreshold) / (1 - noiseThreshold) : 0
        } else {
            // Fallback if spectrum is not available
            root.bassLevel = root.audioPeak * 0.8
            root.midLevel = root.audioPeak * 0.9  
            root.trebleLevel = root.audioPeak * 0.7
        }
        
        // Debug output completely disabled 
        // if (root.debugAudio && Math.random() < 0.005) { 
        //     // console.log("Real Audio - Peak:", root.audioPeak.toFixed(2), 
        //                "Bass:", root.bassLevel.toFixed(2),
        //                "Mid:", root.midLevel.toFixed(2), 
        //                "Treble:", root.trebleLevel.toFixed(2))
        // }
    }
    
    function updateSimulatedAudioLevels() {
        // Original simulation with more dynamic variation
        root.audioPeak = Math.max(0.1, Math.abs(Math.sin(root.t * 8 + Math.sin(root.t * 3) * 2)) * root.audioSensitivity)
        root.bassLevel = Math.abs(Math.cos(root.t * 4 + Math.sin(root.t * 1.5))) * root.audioSensitivity
        root.midLevel = Math.abs(Math.sin(root.t * 6 + Math.cos(root.t * 2.3) * 1.5)) * root.audioSensitivity
        root.trebleLevel = Math.abs(Math.cos(root.t * 12 + Math.sin(root.t * 4.7))) * root.audioSensitivity
    }
    
    // Helper function to get real spectrum data for a given frequency bin
    function getRealSpectrumValue(binIndex) {
        if (!audioBackend || !audioBackend.spectrum || audioBackend.spectrum.length === 0) {
            return 0.1 // Fallback when no spectrum available
        }
        
        const spectrumLength = audioBackend.spectrum.length
        if (binIndex >= spectrumLength) {
            return 0.05 // High frequency bins default to low value
        }
        
        // Direct mapping for now - could implement logarithmic scaling later
        return Math.max(0.05, audioBackend.spectrum[binIndex] || 0.05)
    }
    
    // Audio-reactive properties
    property real audioPeak: 0.1
    property real bassLevel: 0.1
    property real midLevel: 0.1
    property real trebleLevel: 0.1
    
    // Color scheme functions
    // 0: Rainbow Spectrum, 1: Blue Gradient, 2: Fire, 3: Plasma, 4: Monochrome
    function getColorForValue(value, intensity) {
        switch(colorScheme) {
            case 0: // Rainbow Spectrum
                var hue = value * 360
                var sat = 0.8 + intensity * 0.2
                var val = 0.5 + intensity * 0.5
                return Qt.hsva(hue, sat, val, 0.9)
            case 1: // Blue Gradient
                return Qt.rgba(0.1 + intensity * 0.3, 0.3 + intensity * 0.5, 0.5 + intensity * 0.5, 0.9)
            case 2: // Fire
                return Qt.rgba(0.8 + intensity * 0.2, 0.3 * intensity, 0.1 * intensity, 0.9)
            case 3: // Plasma
                return Qt.rgba(0.5 + intensity * 0.5, 0.2 * intensity, 0.5 + intensity * 0.5, 0.9)
            case 4: // Monochrome
                var gray = 0.3 + intensity * 0.7
                return Qt.rgba(gray, gray, gray, 0.9)
            default:
                return Qt.rgba(0.5, 0.5, 0.5, 0.9)
        }
    }
    
    function getBackgroundColor(position, isTop) {
        var t = root.t * 0.2
        var base = isTop ? 0.25 : 0.05
        var mod = isTop ? Math.sin(t) : Math.cos(t)
        
        switch(colorScheme) {
            case 0: // Rainbow Spectrum
                return isTop ? Qt.rgba(0.5 + 0.25*mod, 0.25 + 0.25*mod, 0.5, 1) :
                              Qt.rgba(0.15 + 0.15*mod, 0.05, 0.15, 1)
            case 1: // Blue Gradient
                return Qt.rgba(0.0, base + 0.25*mod, 0.5 + (isTop ? 0.25*mod : 0), 1)
            case 2: // Fire
                return isTop ? Qt.rgba(0.5 + 0.25*mod, base + 0.25*mod, 0.0, 1) :
                              Qt.rgba(0.15 + 0.15*mod, 0.05, 0.0, 1)
            case 3: // Plasma
                return isTop ? Qt.rgba(0.5, 0.0, base + 0.25*mod, 1) :
                              Qt.rgba(0.15 + 0.15*mod, 0.0, 0.05, 1)
            case 4: // Monochrome
                var gray = base + 0.15*mod
                return Qt.rgba(gray, gray, gray, 1)
            default:
                return Qt.rgba(base, base, base, 1)
        }
    }

    // Background gradient shifting subtly
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { 
                position: 0.0; 
                color: getBackgroundColor(0.0, true)
            }
            GradientStop { 
                position: 1.0; 
                color: getBackgroundColor(1.0, false)
            }
        }
    }

    // Enhanced spectrum bars with real FFT data support
    Repeater {
        id: spectrumRepeater
        anchors.fill: parent
        model: visualizationType === 0 ? 64 : 0
        
        Rectangle {
            // Real-time spectrum calculation with fallback
            readonly property real realSpectrum: getRealSpectrumValue(index)
            readonly property real freqMultiplier: (index < 12) ? root.bassLevel : 
                                                  (index < 24) ? root.midLevel : 
                                                  (index < 40) ? root.trebleLevel : root.audioPeak
            readonly property real baseAmp: 0.3 + 0.7 * freqMultiplier
            readonly property real randomFactor: Math.abs(Math.sin(root.t * (4 + index * 0.15) + index * 0.8))
            readonly property real simulatedMag: Math.max(0.2, baseAmp * randomFactor * (0.7 + 0.5 * Math.sin(root.t * 6 + index * 0.3)) * root.audioSensitivity)
            
            // Use real spectrum data when available, otherwise simulate
            readonly property real mag: root.useRealAudio && audioBackend && audioBackend.running ? 
                                       Math.max(0.05, realSpectrum * root.audioSensitivity) : 
                                       simulatedMag
            
            // Fixed positioning and sizing
            width: Math.max(6, parent.width / 64 * 0.8)
            height: Math.max(30, parent.height * 0.8 * Math.min(mag, 1.0))
            anchors.bottom: parent.bottom
            x: index * (parent.width / 64)
            radius: 2
            
            // Enhanced reactive coloring with guaranteed visibility
            color: getColorForValue(index / 64.0, Math.min(mag, 1.0))
            
            // Pulse effect for high peaks
            scale: mag > 0.7 ? (1.0 + 0.2 * Math.sin(root.t * 15)) : 1.0
            
            // Always visible glow effect
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 1.5
                height: parent.height * 1.1
                radius: parent.radius
                color: "transparent"
                border.color: Qt.rgba(1, 0.8, 0.3, 0.6)
                border.width: 2
            }
        }
    }

    // Enhanced audio-reactive fractal pattern
    Item {
        anchors.centerIn: parent
        visible: visualizationType === 3
        scale: 0.3 + (root.audioPeak * 0.8) + (root.audioSensitivity * 0.4) // More dramatic scaling
        rotation: root.t * 15 * root.audioPeak // Rotate faster with audio peaks
        
        Repeater {
            model: 50
            Rectangle {
                // Audio-reactive size and pulsing
                property real audioBoost: (index < 15) ? root.bassLevel : 
                                         (index < 30) ? root.midLevel : root.trebleLevel
                property real baseSize: index * 10 + 15
                property real pulseSize: baseSize * (1.0 + audioBoost * 0.5)
                
                width: pulseSize * (1.0 + 0.3 * Math.sin(root.t * 8 + index * 0.4))
                height: width
                radius: width/2
                color: "transparent"
                
                // Enhanced reactive border with frequency-based colors
                border.color: Qt.rgba(
                    0.2 + 0.6 * audioBoost, 
                    0.4 + 0.6 * Math.sin(root.t * 3 + index * 0.3) * root.audioPeak, 
                    0.7 + 0.3 * Math.cos(root.t * 2 + index * 0.2) * audioBoost,
                    0.3 + 0.5 * root.audioPeak * (1.0 + 0.5 * Math.sin(root.t * 6))
                )
                border.width: (1 + (index % 4)) * (1.0 + audioBoost * 2)
                anchors.centerIn: parent
                
                // Multi-layered rotation responsive to different frequency ranges
                rotation: (root.t * 8 * root.audioSensitivity + index * 12 + audioBoost * 45) % 360
                
                // Pulse scaling for intense audio moments
                scale: audioBoost > 0.6 ? (1.0 + (audioBoost - 0.6) * 0.8 * Math.sin(root.t * 25)) : 1.0
                
                // Secondary glow effect for peaks
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 1.3
                    height: parent.height * 1.3
                    radius: width/2
                    color: "transparent"
                    border.color: Qt.rgba(1, 0.5, 0.8, audioBoost > 0.7 ? (audioBoost - 0.7) : 0)
                    border.width: audioBoost > 0.7 ? 2 : 0
                    visible: audioBoost > 0.5
                    rotation: -parent.rotation * 0.5 // Counter-rotate for hypnotic effect
                }
            }
        }
        
        // Central pulsing core
        Rectangle {
            anchors.centerIn: parent
            width: 20 + root.audioPeak * 60
            height: width
            radius: width/2
            color: Qt.rgba(0.9, 0.6, 0.2, 0.7 * root.audioPeak)
            border.color: Qt.rgba(1, 0.8, 0.4, root.audioPeak)
            border.width: root.audioPeak > 0.5 ? 4 : 2
            scale: 1.0 + root.bassLevel * 0.4 * Math.sin(root.t * 12)
        }
    }

    // Enhanced audio-reactive waveform visualization
    Item {
        anchors.fill: parent
        visible: visualizationType === 1
        
        // Main waveform path
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                
                var primaryColor = getColorForValue(0.5, 0.7 + 0.3 * root.audioPeak)
                ctx.strokeStyle = primaryColor
                ctx.lineWidth = 2 + root.audioPeak * 4
                ctx.beginPath()
                
                var centerY = height / 2
                var steps = 200
                for (var i = 0; i < steps; i++) {
                    var x = (i / steps) * width
                    var progress = i / steps * Math.PI * 8
                    
                    // Multi-layered waveform with audio reactivity - uses ENTIRE screen height
                    var maxAmplitude = height * 0.49   // Use 98% of screen height (49% from center each way)
                    var baseAmplitude = maxAmplitude * 0.8  // Base amplitude at 80% of max
                    var amplitude = baseAmplitude + (maxAmplitude - baseAmplitude) * root.audioSensitivity * 
                                  (0.7 + 0.3 * Math.sin(progress + root.t * 4)) *
                                  (0.8 + 0.2 * Math.sin(progress * 0.3 + root.t * 2.5)) *
                                  (0.5 + 0.5 * root.audioPeak * Math.sin(progress * 2 + root.t * 8))
                    
                    var y = centerY + amplitude * Math.sin(progress + root.t * 6)
                    
                    // Allow waveform to extend beyond screen boundaries for loud sounds
                    // No clipping - let it go off-screen when amplitude is high
                    
                    if (i === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.stroke()
                
                // Secondary harmonic wave
                var secondaryColor = getColorForValue(0.7, 0.5 + 0.3 * root.midLevel)
                ctx.strokeStyle = secondaryColor
                ctx.lineWidth = 1 + root.midLevel * 3
                ctx.beginPath()
                for (var i = 0; i < steps; i++) {
                    var x = (i / steps) * width
                    var progress = i / steps * Math.PI * 12
                    var maxAmplitude = height * 0.47   // Secondary wave uses 94% of screen height
                    var baseAmplitude = maxAmplitude * 0.6  // Base amplitude for secondary wave
                    var amplitude = baseAmplitude + (maxAmplitude - baseAmplitude) * root.audioSensitivity * root.midLevel *
                                  (0.7 + 0.3 * Math.cos(progress * 0.5 + root.t * 3))
                    var y = centerY + amplitude * Math.cos(progress + root.t * 4)
                    
                    // Allow secondary wave to reach very close to screen edges (1px margin)
                    y = Math.max(1, Math.min(height - 1, y))
                    
                    if (i === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.stroke()
            }
            
            Timer {
                interval: 16; running: parent.visible; repeat: true
                onTriggered: parent.requestPaint()
            }
        }
        
        // Waveform particles for intense moments
        Repeater {
            model: root.audioPeak > 0.6 ? 20 : 0
            Rectangle {
                width: 4 + root.audioPeak * 6
                height: width
                radius: width/2
                color: Qt.rgba(1, 0.7, 0.3, 0.8 * root.audioPeak)
                x: Math.random() * parent.width
                y: parent.height/2 + (Math.random() - 0.5) * parent.height * 0.4 * root.audioPeak
                
                PropertyAnimation on y {
                    duration: 1000 + Math.random() * 1000
                    to: parent.height/2 + (Math.random() - 0.5) * parent.height * 0.6 * root.audioPeak
                    loops: Animation.Infinite
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }

    // Enhanced oscilloscope visualization
    Item {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.8
        height: width
        visible: visualizationType === 2
        
        // Oscilloscope screen background
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.02, 0.05, 0.1, 0.8)
            border.color: Qt.rgba(0.2, 0.8, 0.4, 0.6)
            border.width: 2
            radius: 8
        }
        
        // Grid lines
        Repeater {
            model: 8
            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(0.1, 0.3, 0.2, 0.3)
                y: (index + 1) * parent.height / 9
            }
        }
        Repeater {
            model: 8
            Rectangle {
                height: parent.height
                width: 1
                color: Qt.rgba(0.1, 0.3, 0.2, 0.3)
                x: (index + 1) * parent.width / 9
            }
        }
        
        // Oscilloscope trace
        Canvas {
            anchors.fill: parent
            anchors.margins: 10
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                
                // Main XY oscilloscope pattern
                ctx.strokeStyle = Qt.rgba(0.2, 0.9, 0.3, 0.9)
                ctx.lineWidth = 2
                ctx.shadowColor = Qt.rgba(0.2, 0.9, 0.3, 0.5)
                ctx.shadowBlur = 4
                ctx.beginPath()
                
                var centerX = width / 2
                var centerY = height / 2
                var steps = 300
                for (var i = 0; i < steps; i++) {
                    var t = (i / steps) * Math.PI * 4 + root.t * 3
                    
                    // Complex Lissajous patterns responsive to audio
                    var x = centerX + (width * 0.3) * root.audioSensitivity * root.bassLevel * 
                           Math.sin(t * 2 + root.t * 2) * (0.8 + 0.2 * Math.sin(t * 0.5))
                    var y = centerY + (height * 0.3) * root.audioSensitivity * root.trebleLevel * 
                           Math.cos(t * 3 + root.t * 1.5) * (0.8 + 0.2 * Math.cos(t * 0.3))
                    
                    if (i === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.stroke()
                
                // Secondary trace for complexity
                if (root.audioPeak > 0.4) {
                    ctx.strokeStyle = Qt.rgba(0.9, 0.5, 0.2, 0.6)
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    for (var i = 0; i < steps; i++) {
                        var t = (i / steps) * Math.PI * 6 + root.t * 4
                        var x = centerX + (width * 0.2) * root.audioSensitivity * root.midLevel * 
                               Math.cos(t * 1.5 + root.t * 3)
                        var y = centerY + (height * 0.2) * root.audioSensitivity * root.audioPeak * 
                               Math.sin(t * 2.5 + root.t * 2)
                        if (i === 0) ctx.moveTo(x, y)
                        else ctx.lineTo(x, y)
                    }
                    ctx.stroke()
                }
            }
            
            Timer {
                interval: 16; running: parent.visible; repeat: true
                onTriggered: parent.requestPaint()
            }
        }
        
        // Scope intensity indicator
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 15
            width: 8
            height: parent.height * 0.3
            color: Qt.rgba(0.1, 0.2, 0.1, 0.8)
            radius: 4
            
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.6
                height: parent.height * root.audioPeak
                color: Qt.rgba(0.3, 0.9, 0.2, 0.8)
                radius: 2
            }
        }
    }

    // Mandelbrot Zoom visualization (type 15) — GPU-accelerated via ShaderEffect.
    // Every pixel is iterated in parallel on the GPU; this is typically 10–100×
    // faster than the previous Canvas-based CPU fallback at full wallpaper resolution.
    //
    // The compiled shader (mandelbrot.frag.qsb) is embedded in the wallpaper plugin
    // binary via qt6_add_shaders (or installed to the shaders/ dir by the manual
    // qsb fallback). When the QSB is unavailable the ShaderEffect renders transparent.
    ShaderEffect {
        anchors.fill: parent
        visible: visualizationType === 15

        // Each property maps directly to a uniform in the GLSL buf block.
        // Qt6 ShaderEffect updates them every frame via the binding engine.
        property real time:             root.t
        property real audioPeak:        root.audioPeak
        property real audioSensitivity: root.audioSensitivity
        property real centerX:          -0.5 + Math.sin(root.t * 0.3) * 0.3 * root.audioSensitivity
        property real centerY:           0.0 + Math.cos(root.t * 0.2) * 0.3 * root.audioSensitivity
        property int  colorScheme:      root.colorScheme
        property int  maxIter:          50 + Math.floor(root.audioPeak * 50)

        // Compiled shader embedded in the wallpaper plugin binary at build time
        // via qt6_add_shaders (or qt_add_resources + manual qsb) — prefix "/shaders".
        // If the QSB is absent (build without ShaderTools) the effect renders blank.
        fragmentShader: "qrc:/shaders/mandelbrot.frag.qsb"
    }
    
    // Type 4: Circular Spectrum – 64 radial bars around center
    Canvas {
        anchors.fill: parent
        visible: visualizationType === 4
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var cx = width / 2, cy = height / 2
            var innerR = Math.min(width, height) * 0.12
            var outerR = Math.min(width, height) * 0.47
            var n = 64
            var barW = Math.max(2, (Math.PI * 2 * innerR / n) * 0.7)
            for (var i = 0; i < n; i++) {
                var angle = (i / n) * Math.PI * 2 - Math.PI / 2
                var mag = Math.min(1.0, getRealSpectrumValue(i) * root.audioSensitivity)
                var barLen = (outerR - innerR) * Math.max(0.04, mag)
                ctx.strokeStyle = Qt.hsva((i / n + root.t * 0.05) % 1.0, 0.85, 0.9, 0.9)
                ctx.lineWidth = barW
                ctx.lineCap = "round"
                ctx.beginPath()
                ctx.moveTo(cx + Math.cos(angle) * innerR, cy + Math.sin(angle) * innerR)
                ctx.lineTo(cx + Math.cos(angle) * (innerR + barLen), cy + Math.sin(angle) * (innerR + barLen))
                ctx.stroke()
            }
            ctx.beginPath()
            ctx.arc(cx, cy, innerR * (0.8 + root.audioPeak * 0.4), 0, Math.PI * 2)
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.6 * root.audioPeak)
            ctx.lineWidth = 2
            ctx.stroke()
        }
        Timer { interval: 16; running: parent.visible; repeat: true; onTriggered: parent.requestPaint() }
    }

    // Type 5: Plasma – animated overlapping colored blobs
    Item {
        anchors.fill: parent
        visible: visualizationType === 5
        clip: true
        Rectangle { anchors.fill: parent; color: "#050010" }
        Repeater {
            model: 8
            Item {
                property real spd: 0.2 + index * 0.12
                property real phase: index * 0.785
                property real cx: parent.width  * (0.5 + 0.45 * Math.sin(root.t * spd + phase))
                property real cy: parent.height * (0.5 + 0.45 * Math.cos(root.t * spd * 0.7 + phase * 1.3))
                property real sz: Math.min(parent.width, parent.height) * (0.5 + 0.25 * root.audioPeak) * (0.8 + 0.4 * Math.sin(root.t * spd * 2 + phase))
                x: cx - sz/2; y: cy - sz/2
                width: sz; height: sz
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    opacity: 0.35 + 0.15 * root.audioPeak
                    color: Qt.hsva(((index / 8) + root.t * 0.04 + root.audioPeak * 0.1) % 1.0, 0.85, 1.0, 1.0)
                }
            }
        }
    }

    // Type 6: Starfield – stars flying outward from center
    Item {
        anchors.fill: parent
        visible: visualizationType === 6
        Rectangle { anchors.fill: parent; color: "#000008" }
        Repeater {
            model: 120
            Rectangle {
                property real angle: (index / 120) * Math.PI * 2 + Math.sin(index * 1.7) * 0.5
                property real speed: (0.03 + (index % 10) * 0.015) * (1 + root.audioPeak * 3)
                property real dist: ((root.t * speed + index * 0.05) % 0.55) * Math.min(parent.width, parent.height)
                property real sz: Math.max(1, dist / Math.min(parent.width, parent.height) * 8 * (1 + root.audioPeak))
                x: parent.width/2  + Math.cos(angle) * dist - sz/2
                y: parent.height/2 + Math.sin(angle) * dist - sz/2
                width: sz; height: sz; radius: sz/2
                color: Qt.rgba(0.7 + 0.3*root.trebleLevel, 0.8 + 0.2*root.midLevel, 1.0,
                               Math.min(1.0, dist / (Math.min(parent.width, parent.height) * 0.3)))
            }
        }
    }

    // Type 7: Fireworks – particle bursts on bass beats
    Canvas {
        anchors.fill: parent
        visible: visualizationType === 7
        property var particles: []
        property real lastBeat: 0
        onPaint: {
            var ctx = getContext("2d")
            ctx.fillStyle = Qt.rgba(0, 0, 0, 0.15)
            ctx.fillRect(0, 0, width, height)
            if (root.bassLevel > 0.5 && root.t - lastBeat > 0.3) {
                lastBeat = root.t
                var bx = width * (0.2 + Math.random() * 0.6)
                var by = height * (0.2 + Math.random() * 0.5)
                var hue = Math.random()
                for (var p = 0; p < 40; p++) {
                    var pa = Math.random() * Math.PI * 2
                    var spd = 2 + Math.random() * 5 * (1 + root.bassLevel * 2)
                    particles.push({ x: bx, y: by, vx: Math.cos(pa)*spd, vy: Math.sin(pa)*spd - 2, life: 1.0, hue: hue })
                }
            }
            var alive = []
            for (var i = 0; i < particles.length; i++) {
                var pt = particles[i]
                pt.x += pt.vx; pt.y += pt.vy; pt.vy += 0.1; pt.life -= 0.015
                if (pt.life > 0) {
                    ctx.beginPath()
                    ctx.arc(pt.x, pt.y, 2 + pt.life * 2, 0, Math.PI * 2)
                    ctx.fillStyle = Qt.hsva(pt.hue, 0.9, 1.0, pt.life)
                    ctx.fill()
                    alive.push(pt)
                }
            }
            particles = alive
        }
        Timer { interval: 33; running: parent.visible; repeat: true; onTriggered: parent.requestPaint() }
    }

    // Type 8: Matrix Rain – falling green characters
    Canvas {
        anchors.fill: parent
        visible: visualizationType === 8
        property var columns: []
        property bool initialized: false
        onPaint: {
            var ctx = getContext("2d")
            var colW = 20
            var numCols = Math.floor(width / colW)
            if (!initialized || columns.length !== numCols) {
                columns = []
                for (var c = 0; c < numCols; c++)
                    columns.push({ y: Math.random() * height, speed: 1 + Math.random() * 3 })
                initialized = true
                ctx.fillStyle = "#000"; ctx.fillRect(0, 0, width, height)
            }
            ctx.fillStyle = Qt.rgba(0, 0, 0, 0.05); ctx.fillRect(0, 0, width, height)
            ctx.font = "bold " + colW + "px monospace"
            var chars = "0123456789ABCDEF①②③"
            var speed = 1 + root.audioPeak * 4
            for (var i = 0; i < columns.length; i++) {
                var col = columns[i]
                var intensity = 0.5 + root.trebleLevel * 0.5
                ctx.fillStyle = Qt.rgba(0.7, 1.0, 0.7, intensity)
                ctx.fillText(chars[Math.floor(root.t * 20 + i) % chars.length], i * colW, col.y)
                ctx.fillStyle = Qt.rgba(0.0, 0.8, 0.0, intensity * 0.6)
                ctx.fillText(chars[Math.floor(root.t * 10 + i*3) % chars.length], i * colW, col.y - colW)
                ctx.fillStyle = Qt.rgba(0.0, 0.5, 0.0, intensity * 0.3)
                ctx.fillText(chars[Math.floor(root.t * 5 + i*7) % chars.length], i * colW, col.y - colW*2)
                col.y += col.speed * speed
                if (col.y > height + colW) { col.y = -colW; col.speed = 1 + Math.random() * 3 }
            }
        }
        Timer { interval: 50; running: parent.visible; repeat: true; onTriggered: parent.requestPaint() }
    }

    // Type 9: DNA Helix – two intertwined sine strands with rungs
    Canvas {
        anchors.fill: parent
        visible: visualizationType === 9
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var steps = 60
            var cx = width / 2
            var ampX = width * 0.3 * (0.7 + root.audioPeak * 0.5)
            for (var i = 0; i < steps; i++) {
                var t2 = (i / steps) * Math.PI * 6 + root.t * 2
                var y = (i / steps) * height
                var x1 = cx + Math.cos(t2) * ampX
                var x2 = cx + Math.cos(t2 + Math.PI) * ampX
                if (i > 0) {
                    var tp = ((i-1) / steps) * Math.PI * 6 + root.t * 2
                    var yp = ((i-1) / steps) * height
                    ctx.strokeStyle = Qt.rgba(0.2, 0.6 + root.bassLevel*0.4, 1.0, 0.9)
                    ctx.lineWidth = 3; ctx.beginPath()
                    ctx.moveTo(cx + Math.cos(tp) * ampX, yp); ctx.lineTo(x1, y); ctx.stroke()
                    ctx.strokeStyle = Qt.rgba(1.0, 0.3 + root.trebleLevel*0.4, 0.2, 0.9)
                    ctx.beginPath()
                    ctx.moveTo(cx + Math.cos(tp + Math.PI) * ampX, yp); ctx.lineTo(x2, y); ctx.stroke()
                }
                if (i % 4 === 0) {
                    var alpha = 0.3 + 0.4 * Math.abs(Math.cos(t2))
                    ctx.strokeStyle = Qt.rgba(0.8, 0.8, 0.3, alpha)
                    ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(x1, y); ctx.lineTo(x2, y); ctx.stroke()
                    ctx.fillStyle = Qt.rgba(0.3, 1.0, 0.5, alpha); ctx.beginPath()
                    ctx.arc(x1, y, 4 + root.audioPeak*3, 0, Math.PI*2); ctx.fill()
                    ctx.fillStyle = Qt.rgba(1.0, 0.5, 0.3, alpha); ctx.beginPath()
                    ctx.arc(x2, y, 4 + root.audioPeak*3, 0, Math.PI*2); ctx.fill()
                }
            }
        }
        Timer { interval: 16; running: parent.visible; repeat: true; onTriggered: parent.requestPaint() }
    }

    // Type 10: Particle Storm – orbiting colored dots
    Item {
        anchors.fill: parent
        visible: visualizationType === 10
        Rectangle { anchors.fill: parent; color: "#02000a" }
        Repeater {
            model: 150
            Rectangle {
                property real angle: (index / 150) * Math.PI * 2 + root.t * (0.1 + (index % 7) * 0.05)
                property real dist: Math.min(parent.width, parent.height) * 0.1 +
                                   Math.min(parent.width, parent.height) * 0.4 *
                                   Math.abs(Math.sin(root.t * (0.3 + index * 0.02) + index))
                property real sz: 3 + root.audioPeak * 6 * (1 + (index % 3) * 0.3)
                x: parent.width/2  + Math.cos(angle) * dist - sz/2
                y: parent.height/2 + Math.sin(angle) * dist - sz/2
                width: sz; height: sz; radius: sz/2
                color: Qt.hsva((index / 150 + root.t * 0.03) % 1.0, 0.9, 1.0, 0.8)
            }
        }
    }

    // Type 11: Ripple Effect – expanding concentric rings
    Item {
        anchors.fill: parent
        visible: visualizationType === 11
        Rectangle { anchors.fill: parent; color: "#000a10" }
        Repeater {
            model: 12
            Rectangle {
                property real offset: index / 12
                property real phase: (root.t * 0.8 + offset) % 1.0
                property real sz: Math.min(parent.width, parent.height) * phase * (1.2 + root.audioPeak * 0.5)
                anchors.centerIn: parent
                width: sz; height: sz; radius: sz/2; color: "transparent"
                border.width: 2 + root.bassLevel * 3
                border.color: Qt.hsva(((1 - phase) * 0.6 + root.t * 0.05) % 1.0, 0.8, 1.0,
                                      (1 - phase) * 0.8 * (0.4 + root.audioPeak * 0.6))
            }
        }
    }

    // Type 12: Tunnel Vision – rotating rectangles converging to center
    Item {
        anchors.fill: parent
        visible: visualizationType === 12
        Rectangle { anchors.fill: parent; color: "#050005" }
        Repeater {
            model: 20
            Rectangle {
                property real offset: index / 20
                property real phase: (root.t * 0.4 + offset) % 1.0
                property real w: parent.width  * phase * phase * (1 + root.audioPeak * 0.3)
                property real h: parent.height * phase * phase * (1 + root.audioPeak * 0.3)
                anchors.centerIn: parent
                width: w; height: h; color: "transparent"
                rotation: root.t * 20 + index * 18
                border.width: 2
                border.color: Qt.hsva(((offset + root.t * 0.06) % 1.0), 0.9, 1.0, (1 - phase) * 0.8)
            }
        }
    }

    // Type 13: Spiral Galaxy – dots arranged in 3 rotating spiral arms
    Item {
        anchors.fill: parent
        visible: visualizationType === 13
        Rectangle { anchors.fill: parent; color: "#010008" }
        Repeater {
            model: 200
            Rectangle {
                property int arm: index % 3
                property real armAngle: (arm / 3) * Math.PI * 2
                property real t2: (index / 200) * 5
                property real angle: armAngle + t2 + root.t * (0.15 + root.audioPeak * 0.1) * (arm % 2 === 0 ? 1 : -0.5)
                property real dist: t2 * Math.min(parent.width, parent.height) * 0.08 * (1 + root.audioPeak * 0.3)
                property real sz: Math.max(1.5, 4 - t2 * 0.5 + root.audioPeak * 3)
                x: parent.width/2  + Math.cos(angle) * dist - sz/2
                y: parent.height/2 + Math.sin(angle) * dist - sz/2
                width: sz; height: sz; radius: sz/2
                color: Qt.hsva((arm / 3 + t2 * 0.05 + root.t * 0.02) % 1.0,
                               0.6 + root.midLevel * 0.4, 0.7 + root.trebleLevel * 0.3, 0.7 + root.audioPeak * 0.3)
            }
        }
    }

    // Type 14: Lightning – recursive jagged bolts on beats
    Canvas {
        anchors.fill: parent
        visible: visualizationType === 14
        function drawBolt(ctx, x1, y1, x2, y2, roughness, depth) {
            if (depth <= 0) {
                ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke(); return
            }
            var mx = (x1+x2)/2 + (Math.random()-0.5)*roughness
            var my = (y1+y2)/2 + (Math.random()-0.5)*roughness
            drawBolt(ctx, x1, y1, mx, my, roughness/2, depth-1)
            drawBolt(ctx, mx, my, x2, y2, roughness/2, depth-1)
            if (depth === 2 && Math.random() < 0.4) {
                var bx = mx + (Math.random()-0.5)*roughness*2
                drawBolt(ctx, mx, my, bx, my + roughness*2, roughness/3, depth-1)
            }
        }
        onPaint: {
            var ctx = getContext("2d")
            ctx.fillStyle = Qt.rgba(0, 0, 0.05, 0.3); ctx.fillRect(0, 0, width, height)
            var numBolts = 1 + Math.floor(root.audioPeak * 3)
            for (var b = 0; b < numBolts; b++) {
                var bx = width * (0.2 + Math.random() * 0.6)
                ctx.strokeStyle = Qt.rgba(0.5 + root.trebleLevel*0.5, 0.5, 1.0, 0.4 + root.audioPeak*0.6)
                ctx.lineWidth = 1 + root.audioPeak * 2
                ctx.shadowColor = Qt.rgba(0.5, 0.5, 1.0, 0.8); ctx.shadowBlur = 10
                drawBolt(ctx, bx, 0, bx + (Math.random()-0.5)*100, height*0.7, width*0.15, 4)
            }
        }
        Timer { interval: 50; running: parent.visible; repeat: true; onTriggered: parent.requestPaint() }
    }

    // Type 16: Geometric Dance – rotating polygons driven by audio
    Canvas {
        anchors.fill: parent
        visible: visualizationType === 16
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var cx = width / 2, cy = height / 2
            var minDim = Math.min(width, height)
            var audioBoost = 1 + root.audioPeak * 0.4
            var shapes = [
                { sides: 3, r: 0.15, speed:  1.0, phase: 0.0, cr: 0.9, cg: 0.3, cb: 0.1 },
                { sides: 4, r: 0.22, speed: -0.7, phase: 0.5, cr: 0.1, cg: 0.8, cb: 0.9 },
                { sides: 5, r: 0.30, speed:  0.5, phase: 1.0, cr: 0.9, cg: 0.8, cb: 0.1 },
                { sides: 6, r: 0.38, speed: -0.3, phase: 1.5, cr: 0.5, cg: 0.2, cb: 0.9 },
                { sides: 8, r: 0.45, speed:  0.2, phase: 2.0, cr: 0.1, cg: 0.9, cb: 0.4 }
            ]
            for (var s = 0; s < shapes.length; s++) {
                var sh = shapes[s]
                var angle = root.t * sh.speed + sh.phase
                var radius = minDim * sh.r * audioBoost * (1 + 0.2 * Math.sin(root.t * 3 + s))
                ctx.beginPath()
                for (var v = 0; v <= sh.sides; v++) {
                    var a = angle + (v / sh.sides) * Math.PI * 2
                    if (v === 0) ctx.moveTo(cx + Math.cos(a)*radius, cy + Math.sin(a)*radius)
                    else ctx.lineTo(cx + Math.cos(a)*radius, cy + Math.sin(a)*radius)
                }
                ctx.closePath()
                ctx.strokeStyle = Qt.rgba(sh.cr, sh.cg, sh.cb, 0.8)
                ctx.lineWidth = 2 + root.audioPeak * 3; ctx.stroke()
                ctx.fillStyle = Qt.rgba(sh.cr, sh.cg, sh.cb, 0.05 + root.audioPeak * 0.15); ctx.fill()
            }
            if (root.audioPeak > 0.5) {
                var rays = 12
                for (var ray = 0; ray < rays; ray++) {
                    var ra = (ray / rays) * Math.PI * 2 + root.t * 3
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, (root.audioPeak - 0.5) * 2)
                    ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(cx, cy)
                    ctx.lineTo(cx + Math.cos(ra)*minDim*0.5*root.audioPeak,
                               cy + Math.sin(ra)*minDim*0.5*root.audioPeak); ctx.stroke()
                }
            }
        }
        Timer { interval: 16; running: parent.visible; repeat: true; onTriggered: parent.requestPaint() }
    }

    // Type 17: Audio Bars 3D – spectrum bars in perspective
    Canvas {
        anchors.fill: parent
        visible: visualizationType === 17
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = "#000"; ctx.fillRect(0, 0, width, height)
            var n = 32
            var horizonY = height * 0.55
            var vanishX = width / 2
            ctx.strokeStyle = Qt.rgba(0.1, 0.3, 0.5, 0.4); ctx.lineWidth = 1
            for (var row = 0; row <= 8; row++) {
                var pct = row / 8
                var gy = horizonY + (height - horizonY) * pct
                ctx.beginPath()
                ctx.moveTo(vanishX - width*0.5*pct, gy)
                ctx.lineTo(vanishX + width*0.5*pct, gy); ctx.stroke()
            }
            for (var i = 0; i < n; i++) {
                var mag = Math.min(1.0, getRealSpectrumValue(i*2) * root.audioSensitivity)
                var xNorm = (i + 0.5) / n
                var frontXL = xNorm * width * 0.9 + width * 0.05
                var frontXR = frontXL + width * 0.9 / n * 0.8
                var frontY = height - 20
                var barH = (height - horizonY) * Math.max(0.02, mag)
                var topFY = frontY - barH
                var topVXL = vanishX + (frontXL - vanishX) * 0.3
                var topVXR = vanishX + (frontXR - vanishX) * 0.3
                var topVY  = horizonY + (topFY - horizonY) * 0.3
                var hue = i / n
                var bright = 0.5 + mag * 0.5
                ctx.beginPath()
                ctx.moveTo(frontXL, frontY); ctx.lineTo(frontXR, frontY)
                ctx.lineTo(frontXR, topFY); ctx.lineTo(frontXL, topFY)
                ctx.closePath(); ctx.fillStyle = Qt.hsva(hue, 0.8, bright, 0.9); ctx.fill()
                ctx.beginPath()
                ctx.moveTo(frontXL, topFY); ctx.lineTo(frontXR, topFY)
                ctx.lineTo(topVXR, topVY); ctx.lineTo(topVXL, topVY)
                ctx.closePath(); ctx.fillStyle = Qt.hsva(hue, 0.5, bright * 1.3, 0.9); ctx.fill()
            }
        }
        Timer { interval: 16; running: parent.visible; repeat: true; onTriggered: parent.requestPaint() }
    }

    // Type 18: Kaleidoscope – radially mirrored pattern segments
    Canvas {
        anchors.fill: parent
        visible: visualizationType === 18
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var cx = width / 2, cy = height / 2
            var segments = 8
            var segAngle = Math.PI * 2 / segments
            var r = Math.min(width, height) * 0.5
            for (var seg = 0; seg < segments; seg++) {
                ctx.save()
                ctx.translate(cx, cy)
                ctx.rotate(seg * segAngle + root.t * 0.1)
                ctx.beginPath(); ctx.moveTo(0, 0)
                ctx.arc(0, 0, r, -segAngle/2, segAngle/2)
                ctx.closePath(); ctx.clip()
                if (seg % 2 === 1) ctx.scale(-1, 1)
                for (var layer = 0; layer < 4; layer++) {
                    var lx = r * 0.3 * Math.sin(root.t * (0.5 + layer*0.3) + layer*1.2)
                    var ly = r * 0.2 * Math.cos(root.t * (0.4 + layer*0.2) + layer)
                    var lsz = r * (0.1 + 0.15*layer) * (1 + root.audioPeak * 0.5)
                    ctx.beginPath(); ctx.arc(lx, ly, lsz, 0, Math.PI*2)
                    ctx.fillStyle = Qt.hsva((layer/4 + root.t*0.05 + root.audioPeak*0.2) % 1.0, 0.8, 0.9,
                                            0.35 + root.audioPeak*0.2); ctx.fill()
                    ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(lx + lsz, ly)
                    ctx.strokeStyle = Qt.hsva((layer/4 + 0.3 + root.t*0.05) % 1.0, 0.9, 1.0,
                                              0.3 + root.bassLevel*0.4)
                    ctx.lineWidth = 1 + root.audioPeak*2; ctx.stroke()
                }
                ctx.restore()
            }
        }
        Timer { interval: 16; running: parent.visible; repeat: true; onTriggered: parent.requestPaint() }
    }

    // Information overlay
    Rectangle {
        id: info
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        width: 220  // Slightly wider for better text fit
        height: 110 // Slightly taller to accommodate all lines
        color: Qt.rgba(0,0,0,0.7) // More opaque for visibility
        radius: 6
        visible: root.showInfo
        border.color: "#ffffff"
        border.width: 1
        property int margin: 8
        
        Column {
            anchors.fill: parent
            anchors.margins: info.margin
            spacing: 3  // Reduced spacing for better fit
            Text { 
                text: "LibVisual Wallpaper" 
                color: "white" 
                font.bold: true 
                font.pointSize: 10
                wrapMode: Text.Wrap
                width: parent.width
            }
            Text { 
                text: "Audio: " + root.audioSource
                color: "white" 
                font.pointSize: 9
                wrapMode: Text.Wrap
                width: parent.width
            }
            Text {
                text: "Backend: " + (root.useRealAudio && audioBackend && audioBackend.running ? 
                      "REAL (" + audioBackend.decibels.toFixed(1) + " dB)" : "SIMULATED")
                color: root.useRealAudio && audioBackend && audioBackend.running ? "#00ff00" : "#ffff00"
                font.pointSize: 9
                font.bold: true
                wrapMode: Text.Wrap
                width: parent.width
            }
            Text {
                text: "Mode: " + (["Spectrum","Waveform","Lissajous","Circular Burst",
                                   "Circular Spectrum","Plasma","Starfield","Fireworks",
                                   "Matrix Rain","DNA Helix","Particle Storm","Ripple Effect",
                                   "Tunnel Vision","Spiral Galaxy","Lightning","Mandelbrot (GPU)",
                                   "Geometric Dance","Audio Bars 3D","Kaleidoscope"][root.visualizationType] || "?")
                color: root.visualizationType === 15 ? "#00ccff" : "white"
                font.pointSize: 9
                wrapMode: Text.Wrap
                width: parent.width
            }
            Text { 
                text: "Sensitivity: " + root.audioSensitivity.toFixed(1)
                color: "white" 
                font.pointSize: 9
                wrapMode: Text.Wrap
                width: parent.width
            }
        }
    }

    // Status indicator (small corner indicator)
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        width: 100
        height: 50
        color: Qt.rgba(0, 0, 0, 0.7)
        radius: 6
        border.color: root.useRealAudio && audioBackend && audioBackend.running ? "#00ff00" : "#ff9900"
        border.width: 2
        visible: root.showStatusIndicator
        
        Column {
            anchors.centerIn: parent
            spacing: 2
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.useRealAudio && audioBackend && audioBackend.running ? "●" : "○"
                color: root.useRealAudio && audioBackend && audioBackend.running ? "#00ff00" : "#ff9900"
                font.pixelSize: 16
                font.bold: true
            }
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.useRealAudio && audioBackend && audioBackend.running ? 
                      audioBackend.decibels.toFixed(0) + "dB" : "SIM"
                color: "white"
                font.pixelSize: 10
                font.family: "monospace"
            }
        }
    }

    Component.onCompleted: {
        if (debugAudio) {
            console.log("LibVisual Background WallpaperItem loaded")
            console.log("Configuration - Type:", visualizationType, "Sensitivity:", audioSensitivity, "ShowInfo:", showInfo, "Source:", audioSource)
        }
    }
}
