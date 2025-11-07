/*
 * SPDX-FileCopyrightText: 2025 VitexSoftware <vitex@vitexsoftware.cz>
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.plasmoid 2.0
import LibVisualBackend 1.0

WallpaperItem {
    id: root
    
    // Configuration properties bound to main.xml
    property int visualizationType: root.configuration.visualizationType
    property real audioSensitivity: root.configuration.audioSensitivity  
    property bool showInfo: root.configuration.showInfo
    property string audioSource: root.configuration.audioSource
    property real t: 0
    
    // Audio backend configuration
    property bool useRealAudio: true  // Toggle between real and simulated audio
    property bool debugAudio: false  // Enable audio debug logging
    
    // Real audio backend instance
    LibVisualBackend {
        id: audioBackend
        Component.onCompleted: {
            if (root.debugAudio) {
                console.log("LibVisualBackend - Audio backend initialized")
                console.log("LibVisualBackend - FFT Size:", fftSize)
                console.log("LibVisualBackend - Initial audio active:", audioActive)
            }
        }
        
        onAudioActiveChanged: {
            if (root.debugAudio) {
                console.log("LibVisualBackend - Audio active changed:", audioActive)
            }
        }
        
        onDecibelsChanged: {
            if (root.debugAudio && Math.random() < 0.01) { // Log 1% of the time to avoid spam
                console.log("LibVisualBackend - Audio level:", decibels.toFixed(1), "dB")
            }
        }
    }
    
    // Legacy backend property for compatibility
    property var backend: audioBackend

    // Configuration change handlers
    onVisualizationTypeChanged: {
        console.log("Wallpaper - Visualization type changed to:", visualizationType)
    }
    
    onAudioSensitivityChanged: {
        console.log("Wallpaper - Audio sensitivity changed to:", audioSensitivity)
    }
    
    onShowInfoChanged: {
        console.log("Wallpaper - Show info changed to:", showInfo)
    }
    
    onAudioSourceChanged: {
        console.log("Wallpaper - Audio source changed to:", audioSource)
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
        if (root.useRealAudio && audioBackend && audioBackend.audioActive) {
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
        root.audioPeak = Math.max(0.1, dbNormalized * root.audioSensitivity)
        
        // Extract frequency band levels from spectrum
        if (audioBackend.spectrum && audioBackend.spectrum.length >= 64) {
            // Bass: bins 0-15 (roughly 0-1kHz)
            let bassSum = 0
            for (let i = 0; i < 16; i++) {
                bassSum += audioBackend.spectrum[i] || 0
            }
            root.bassLevel = Math.max(0.1, (bassSum / 16) * root.audioSensitivity)
            
            // Mid: bins 16-39 (roughly 1-4kHz)  
            let midSum = 0
            for (let i = 16; i < 40; i++) {
                midSum += audioBackend.spectrum[i] || 0
            }
            root.midLevel = Math.max(0.1, (midSum / 24) * root.audioSensitivity)
            
            // Treble: bins 40-63 (roughly 4-8kHz)
            let trebleSum = 0
            for (let i = 40; i < Math.min(64, audioBackend.spectrum.length); i++) {
                trebleSum += audioBackend.spectrum[i] || 0
            }
            root.trebleLevel = Math.max(0.1, (trebleSum / 24) * root.audioSensitivity)
        } else {
            // Fallback if spectrum is not available
            root.bassLevel = root.audioPeak * 0.8
            root.midLevel = root.audioPeak * 0.9  
            root.trebleLevel = root.audioPeak * 0.7
        }
        
        if (root.debugAudio && Math.random() < 0.005) { // Log occasionally
            console.log("Real Audio - Peak:", root.audioPeak.toFixed(2), 
                       "Bass:", root.bassLevel.toFixed(2),
                       "Mid:", root.midLevel.toFixed(2), 
                       "Treble:", root.trebleLevel.toFixed(2))
        }
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
            return 0.1 // Fallback when no real spectrum available
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

    // Background gradient shifting subtly
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { 
                position: 0.0; 
                color: visualizationType === 0 ? Qt.rgba(0.0, 0.25 + 0.25*Math.sin(root.t*0.2), 0.5, 1) :
                       visualizationType === 1 ? Qt.rgba(0.5, 0.25 + 0.25*Math.sin(root.t*0.2), 0.0, 1) :
                       visualizationType === 2 ? Qt.rgba(0.25 + 0.25*Math.sin(root.t*0.2), 0.0, 0.5, 1) :
                       Qt.rgba(0.5, 0.0, 0.25 + 0.25*Math.sin(root.t*0.2), 1)
            }
            GradientStop { 
                position: 1.0; 
                color: visualizationType === 0 ? Qt.rgba(0.0, 0.05, 0.15 + 0.15*Math.cos(root.t*0.2), 1) :
                       visualizationType === 1 ? Qt.rgba(0.15 + 0.15*Math.cos(root.t*0.2), 0.05, 0.0, 1) :
                       visualizationType === 2 ? Qt.rgba(0.05, 0.0, 0.15 + 0.15*Math.cos(root.t*0.2), 1) :
                       Qt.rgba(0.15 + 0.15*Math.cos(root.t*0.2), 0.0, 0.05, 1)
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
            readonly property real mag: root.useRealAudio && audioBackend && audioBackend.audioActive ? 
                                       Math.max(0.05, realSpectrum * root.audioSensitivity) : 
                                       simulatedMag
            
            // Fixed positioning and sizing
            width: Math.max(6, parent.width / 64 * 0.8)
            height: Math.max(30, parent.height * 0.8 * Math.min(mag, 1.0))
            anchors.bottom: parent.bottom
            x: index * (parent.width / 64)
            radius: 2
            
            // Enhanced reactive coloring with guaranteed visibility
            color: Qt.rgba(
                Math.max(0.4, 0.2 + 0.6 * Math.min(mag, 1.0)), 
                Math.max(0.3, 0.3 + 0.5 * root.audioPeak), 
                Math.max(0.5, 0.6 + 0.4 * freqMultiplier), 
                0.95 // High opacity for visibility
            )
            
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
        anchors.centerIn: parent
        width: parent.width * 0.9
        height: parent.height * 0.6
        visible: visualizationType === 1
        
        // Main waveform path
        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                
                ctx.strokeStyle = Qt.rgba(0.3 + 0.5 * root.audioPeak, 0.7, 0.9, 0.8)
                ctx.lineWidth = 2 + root.audioPeak * 4
                ctx.beginPath()
                
                var centerY = height / 2
                var steps = 200
                for (var i = 0; i < steps; i++) {
                    var x = (i / steps) * width
                    var progress = i / steps * Math.PI * 8
                    
                    // Multi-layered waveform with audio reactivity
                    var amplitude = (height * 0.2) * root.audioSensitivity * 
                                  (0.5 + 0.5 * Math.sin(progress + root.t * 4)) *
                                  (0.7 + 0.3 * Math.sin(progress * 0.3 + root.t * 2.5)) *
                                  (1.0 + root.audioPeak * Math.sin(progress * 2 + root.t * 8))
                    
                    var y = centerY + amplitude * Math.sin(progress + root.t * 6)
                    
                    if (i === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.stroke()
                
                // Secondary harmonic wave
                ctx.strokeStyle = Qt.rgba(0.9, 0.4 + 0.4 * root.midLevel, 0.6, 0.5)
                ctx.lineWidth = 1 + root.midLevel * 3
                ctx.beginPath()
                for (var i = 0; i < steps; i++) {
                    var x = (i / steps) * width
                    var progress = i / steps * Math.PI * 12
                    var amplitude = (height * 0.15) * root.audioSensitivity * root.midLevel *
                                  (0.6 + 0.4 * Math.cos(progress * 0.5 + root.t * 3))
                    var y = centerY + amplitude * Math.cos(progress + root.t * 4)
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

    // Information overlay
    Rectangle {
        id: info
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        width: 200
        height: 100
        color: Qt.rgba(0,0,0,0.7) // More opaque for visibility
        radius: 6
        visible: root.showInfo
        border.color: "#ffffff"
        border.width: 1
        property int margin: 8
        
        Column {
            anchors.fill: parent
            anchors.margins: info.margin
            spacing: 4
            Text { 
                text: "LibVisual Wallpaper" 
                color: "white" 
                font.bold: true 
                font.pointSize: 10
            }
            Text { 
                text: "Audio: " + root.audioSource
                color: "white" 
                font.pointSize: 9 
            }
            Text {
                text: "Backend: " + (root.useRealAudio && audioBackend && audioBackend.audioActive ? 
                      "REAL (" + audioBackend.decibels.toFixed(1) + " dB)" : "SIMULATED")
                color: root.useRealAudio && audioBackend && audioBackend.audioActive ? "#00ff00" : "#ffff00"
                font.pointSize: 9
                font.bold: true
            }
            Text { 
                text: "Mode: " + (root.visualizationType === 0 ? "Spectrum" : 
                              root.visualizationType === 1 ? "Waveform" :
                              root.visualizationType === 2 ? "Oscilloscope" : "Fractal")
                color: "white" 
                font.pointSize: 9 
            }
            Text { 
                text: "Sensitivity: " + root.audioSensitivity.toFixed(1)
                color: "white" 
                font.pointSize: 9 
            }
        }
    }

    Component.onCompleted: {
        console.log("LibVisual Background WallpaperItem loaded")
        console.log("Configuration - Type:", visualizationType, "Sensitivity:", audioSensitivity, "ShowInfo:", showInfo, "Source:", audioSource)
    }
}