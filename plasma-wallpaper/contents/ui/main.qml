import QtQuick 2.15
import QtQuick.Canvas 2.15
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.audiovisualizer 1.0

Rectangle {
    id: wallpaper
    
    color: "black"
    
    property var audioBackend: null
    property bool initialized: false
    property var spectrumData: []
    
    // Configuration properties from wallpaper configuration
    property string audioDevice: wallpaper.configuration.audioDevice || "Default"
    property real sensitivity: wallpaper.configuration.sensitivity || 1.0
    property int colorScheme: wallpaper.configuration.colorScheme || 0
    property bool showStatusIndicator: wallpaper.configuration.showStatusIndicator || false
    property real smoothing: wallpaper.configuration.smoothing || 0.8
    
    Component.onCompleted: {
        console.log("Audio Visualizer Wallpaper loaded")
        initializeBackend()
    }
    
    Component.onDestruction: {
        if (audioBackend) {
            audioBackend.stopVisualization()
        }
    }
    
    function initializeBackend() {
        try {
            // Create audio backend using QML import
            audioBackend = AudioVisualizerBackend.createInstance()
            if (audioBackend) {
                audioBackend.spectrumUpdated.connect(updateSpectrum)
                audioBackend.startVisualization()
                initialized = true
                console.log("Audio backend initialized successfully")
            } else {
                console.log("Failed to create AudioVisualizerBackend, using demo mode")
                demoTimer.start()
            }
        } catch (error) {
            console.error("Failed to initialize audio backend:", error)
            // Fallback to demo mode
            demoTimer.start()
        }
    }
    
    function updateSpectrum(newSpectrumData) {
        spectrumData = newSpectrumData
        canvas.requestPaint()
    }
    
    // Demo timer for testing without audio backend
    Timer {
        id: demoTimer
        interval: 50
        repeat: true
        running: false
        onTriggered: {
            // Generate fake spectrum data for demo
            var fakeData = []
            for (var i = 0; i < 128; i++) {
                var value = Math.sin(Date.now() * 0.001 + i * 0.1) * 0.5 + 0.5
                value *= Math.random() * 0.8 + 0.2
                fakeData.push(value)
            }
            updateSpectrum(fakeData)
        }
    }
    
    Canvas {
        id: canvas
        anchors.fill: parent
        
        property real barWidth: width / (spectrumData.length || 128)
        property real maxBarHeight: height * 0.8
        
        onPaint: {
            var ctx = getContext("2d")
            
            // Clear canvas
            ctx.fillStyle = "black"
            ctx.fillRect(0, 0, width, height)
            
            if (spectrumData.length === 0) {
                return
            }
            
            // Draw spectrum bars
            for (var i = 0; i < spectrumData.length; i++) {
                var intensity = (spectrumData[i] || 0) * sensitivity
                intensity = Math.min(intensity, 1.0) // Clamp to max
                var barHeight = intensity * maxBarHeight
                var x = i * barWidth
                var y = height - barHeight
                
                // Color scheme selection
                var hue, saturation, lightness
                switch (colorScheme) {
                    case 0: // Rainbow Spectrum
                        hue = (i / spectrumData.length) * 300
                        saturation = 80
                        lightness = Math.min(50 + intensity * 50, 90)
                        break
                    case 1: // Blue Gradient
                        hue = 220
                        saturation = Math.min(60 + intensity * 40, 100)
                        lightness = Math.min(30 + intensity * 60, 90)
                        break
                    case 2: // Fire
                        hue = intensity > 0.5 ? 0 : 30
                        saturation = 100
                        lightness = Math.min(20 + intensity * 70, 90)
                        break
                    case 3: // Plasma
                        hue = 280 + intensity * 40
                        saturation = 80
                        lightness = Math.min(40 + intensity * 50, 90)
                        break
                    default: // Monochrome
                        hue = 0
                        saturation = 0
                        lightness = Math.min(20 + intensity * 70, 90)
                }
                
                ctx.fillStyle = "hsl(" + hue + ", " + saturation + "%, " + lightness + "%)"
                ctx.fillRect(x, y, barWidth - 1, barHeight)
                
                // Add glow effect for high frequencies
                if (intensity > 0.6) {
                    ctx.shadowColor = ctx.fillStyle
                    ctx.shadowBlur = 10
                    ctx.fillRect(x, y, barWidth - 1, barHeight)
                    ctx.shadowBlur = 0
                }
            }
            
            // Add subtle background gradient
            var gradient = ctx.createLinearGradient(0, 0, 0, height)
            gradient.addColorStop(0, "rgba(20, 20, 40, 0.1)")
            gradient.addColorStop(1, "rgba(0, 0, 0, 0.8)")
            ctx.fillStyle = gradient
            ctx.fillRect(0, 0, width, height)
        }
    }
    
    // Performance optimization
    Timer {
        interval: 16  // 60 FPS
        repeat: true
        running: wallpaper.visible && initialized
        onTriggered: {
            if (audioBackend && audioBackend.hasNewData()) {
                canvas.requestPaint()
            }
        }
    }
    
    // Status indicator (for debugging)
    Rectangle {
        id: statusIndicator
        width: 10
        height: 10
        radius: 5
        color: initialized ? "green" : "red"
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        opacity: showStatusIndicator ? 0.7 : 0
        visible: showStatusIndicator
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                console.log("Wallpaper status - Initialized:", initialized, 
                           "Backend available:", audioBackend !== null,
                           "Spectrum data points:", spectrumData.length,
                           "Config - Device:", audioDevice, "Sensitivity:", sensitivity)
            }
        }
    }
}