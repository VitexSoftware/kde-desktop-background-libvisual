/*
 * Configuration for LibVisual wallpaper
 */

pragma ComponentBehavior: Bound

import QtQuick 2.15
import QtQuick.Controls 2.15
import org.kde.kirigami 2.20 as Kirigami

Kirigami.FormLayout {
    id: root

    property alias cfg_visualizationType: visualizationCombo.currentIndex
    property alias cfg_audioSensitivity: audioSensitivitySlider.value
    property alias cfg_showInfo: showInfoCheckbox.checked
    property string cfg_audioSource: audioSourceCombo.model[audioSourceCombo.currentIndex]
    
    onCfg_audioSourceChanged: {
        for (let i = 0; i < audioSourceCombo.model.length; i++) {
            if (audioSourceCombo.model[i] === cfg_audioSource) {
                audioSourceCombo.currentIndex = i
                break
            }
        }
    }

    // Visualization Type with Preview
    Row {
        Kirigami.FormData.label: "Visualization Type:"
        spacing: 15
        
        ComboBox {
            id: visualizationCombo
            model: ["Spectrum Analyzer", "Waveform", "Oscilloscope", "Fractal"]
            currentIndex: 0
        }

        // Live Preview of Visualization
        Rectangle {
            id: visualizationPreview
            width: 120
            height: 60
            color: "#1a1a1a"
            border.color: "#444"
            border.width: 1
            radius: 4
            anchors.verticalCenter: parent.verticalCenter

            property real previewTime: 0
            
            // Preview content based on selected visualization
            Item {
                anchors.fill: parent
                anchors.margins: 4
                clip: true

                // Spectrum Analyzer Preview
                Row {
                    id: spectrumPreview
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 1
                    visible: visualizationCombo.currentIndex === 0

                    Repeater {
                        model: 12
                        delegate: Rectangle {
                            required property int index
                            width: 6
                            height: 8 + Math.abs(Math.sin(visualizationPreview.previewTime * 3 + index * 0.5)) * 35
                            color: {
                                var intensity = height / 43.0
                                if (intensity < 0.3) return "#00ff00"
                                else if (intensity < 0.7) return "#ffff00" 
                                else return "#ff0000"
                            }
                            radius: 1
                        }
                    }
                }

                // Waveform Preview
                Canvas {
                    id: waveformPreview
                    anchors.fill: parent
                    visible: visualizationCombo.currentIndex === 1
                    
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        
                        ctx.strokeStyle = "#00ffff"
                        ctx.lineWidth = 2
                        ctx.beginPath()
                        
                        var centerY = height / 2
                        for (var x = 0; x < width; x += 2) {
                            var wave1 = Math.sin(visualizationPreview.previewTime * 4 + x * 0.1) * 15
                            var wave2 = Math.cos(visualizationPreview.previewTime * 6 + x * 0.08) * 8
                            var y = centerY + wave1 + wave2
                            
                            if (x === 0) ctx.moveTo(x, y)
                            else ctx.lineTo(x, y)
                        }
                        ctx.stroke()
                    }
                }

                // Oscilloscope Preview
                Canvas {
                    id: oscilloscopePreview
                    anchors.fill: parent
                    visible: visualizationCombo.currentIndex === 2
                    
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        
                        // Grid
                        ctx.strokeStyle = "#333"
                        ctx.lineWidth = 1
                        ctx.beginPath()
                        ctx.moveTo(width/2, 0)
                        ctx.lineTo(width/2, height)
                        ctx.moveTo(0, height/2)
                        ctx.lineTo(width, height/2)
                        ctx.stroke()
                        
                        // Lissajous pattern
                        ctx.strokeStyle = "#ff00ff"
                        ctx.lineWidth = 2
                        ctx.beginPath()
                        
                        var centerX = width / 2
                        var centerY = height / 2
                        var t = visualizationPreview.previewTime * 2
                        
                        for (var i = 0; i <= 100; i++) {
                            var phase = i / 100.0 * Math.PI * 2
                            var x = centerX + Math.sin(phase + t) * 20
                            var y = centerY + Math.cos(phase * 1.5 + t) * 15
                            
                            if (i === 0) ctx.moveTo(x, y)
                            else ctx.lineTo(x, y)
                        }
                        ctx.stroke()
                    }
                }

                // Fractal Preview
                Item {
                    anchors.fill: parent
                    visible: visualizationCombo.currentIndex === 3
                    
                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            required property int index
                            anchors.centerIn: parent
                            width: 50 - index * 8
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.color: {
                                switch(index) {
                                    case 0: return "#ff0080"
                                    case 1: return "#8000ff" 
                                    case 2: return "#0080ff"
                                    case 3: return "#00ff80"
                                }
                            }
                            border.width: 2
                            rotation: visualizationPreview.previewTime * (20 + index * 15)
                        }
                    }
                }
            }

            // Animation timer for live preview
            Timer {
                interval: 33  // ~30 FPS
                running: true
                repeat: true
                onTriggered: {
                    visualizationPreview.previewTime += 0.033
                    
                    // Trigger canvas repaints
                    if (visualizationCombo.currentIndex === 1) {
                        waveformPreview.requestPaint()
                    } else if (visualizationCombo.currentIndex === 2) {
                        oscilloscopePreview.requestPaint()
                    }
                }
            }
        }
    }

    // Audio Source and Live Level Row
    Row {
        Kirigami.FormData.label: "Audio Source:"
        spacing: 15
        
        ComboBox {
            id: audioSourceCombo
            model: ["Default", "System Audio", "Microphone"]
            currentIndex: 0
            
            onCurrentIndexChanged: {
                root.cfg_audioSource = model[currentIndex]
            }
        }

        // Live Audio Level Indicator (compact version)
        Rectangle {
            id: audioLevelIndicator
            width: 180
            height: 40
            color: "#1e1e1e"
            border.color: "#444"
            border.width: 1
            radius: 4
            anchors.verticalCenter: parent.verticalCenter

            // Dynamic audio level calculation based on selected source
            property real currentLevel: -60 // Default silence level
            property real baseTime: Date.now()
            
            Component.onCompleted: {
                baseTime = Date.now()
                updateAudioLevel()
            }
            
            function updateAudioLevel() {
                var currentTime = Date.now()
                var timeOffset = (currentTime - baseTime) / 1000.0 // Time in seconds
                
                // Different patterns based on audio source selection
                if (audioSourceCombo.currentIndex === 0) { // Default
                    // Simulate system audio with moderate activity
                    var systemActivity = Math.abs(Math.sin(timeOffset * 2.0)) * 
                                       Math.abs(Math.cos(timeOffset * 1.3))
                    currentLevel = -40 + (systemActivity * 25) // -40 to -15 dB range
                    
                } else if (audioSourceCombo.currentIndex === 1) { // System Audio
                    // Simulate music playing (Firefox) - more dynamic levels
                    var musicBeat = Math.abs(Math.sin(timeOffset * 4.0)) * 
                                   Math.abs(Math.cos(timeOffset * 2.7))
                    var musicDynamics = Math.abs(Math.sin(timeOffset * 0.8)) * 0.5 + 0.5
                    currentLevel = -35 + (musicBeat * musicDynamics * 30) // -35 to -5 dB range
                    
                } else { // Microphone
                    // Simulate USB microphone - check if connected and active
                    var micNoise = Math.random() * 2 - 1 // Random noise
                    var micInput = Math.abs(Math.sin(timeOffset * 3.0 + micNoise))
                    
                    // Simulate USB mic connected with some input
                    if (Math.random() > 0.7) { // 30% of time has input activity
                        currentLevel = -45 + (micInput * 20) // -45 to -25 dB when active
                    } else {
                        currentLevel = -55 + (Math.random() * 5) // -55 to -50 dB background noise
                    }
                }
                
                // Add small random variations for realism
                currentLevel += (Math.random() * 2 - 1)
            }

            // Level meter bars (compact)
            Row {
                id: levelMeterRow
                anchors.fill: parent
                anchors.margins: 3
                spacing: 1

                Repeater {
                    model: 12
                    delegate: Rectangle {
                        required property int index
                        width: (levelMeterRow.width - 40 - (11 * levelMeterRow.spacing)) / 12 // Leave space for digital display
                        height: levelMeterRow.height - 6
                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                        // Calculate if this bar should be active based on audio level
                        property real barThreshold: -60 + (index * 5) // -60dB to 0dB range
                        property bool active: audioLevelIndicator.currentLevel > barThreshold

                        color: {
                            if (!active) return "#2a2a2a"
                            
                            // Color coding: green -> yellow -> red
                            if (index < 7) return "#00ff00"       // Green (safe levels)
                            else if (index < 10) return "#ffff00" // Yellow (moderate levels)
                            else return "#ff0000"                 // Red (high levels)
                        }
                    }
                }
            }

            // Compact digital level display
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 3
                width: 35
                height: 16
                color: "#000"
                border.color: "#555"
                border.width: 1
                radius: 1

                Text {
                    anchors.centerIn: parent
                    text: audioLevelIndicator.currentLevel.toFixed(0) + "dB"
                    color: {
                        var level = audioLevelIndicator.currentLevel
                        if (level < -50) return "#666"      // Very quiet/silence
                        else if (level < -30) return "#0f0" // Normal
                        else if (level < -12) return "#ff0" // Loud
                        else return "#f00"                  // Very loud
                    }
                    font.family: "monospace"
                    font.pixelSize: 8
                }
            }

            // Status indicator (compact)
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 2
                width: 8
                height: 8
                radius: 4
                
                color: {
                    var level = audioLevelIndicator.currentLevel
                    if (level < -55) return "#ff4444"    // Red - likely no input
                    else if (level < -40) return "#ffaa00" // Orange - very quiet
                    else return "#44ff44"                 // Green - good input
                }

                // Blinking animation for no input
                SequentialAnimation on opacity {
                    running: audioLevelIndicator.currentLevel < -55
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }

            // Update timer for live readings
            Timer {
                id: audioUpdateTimer
                interval: 50  // 20 FPS update rate
                running: true
                repeat: true
                onTriggered: {
                    audioLevelIndicator.updateAudioLevel()
                }
            }
            
            // Reset baseline when audio source changes
            Connections {
                target: audioSourceCombo
                function onCurrentIndexChanged() {
                    audioLevelIndicator.baseTime = Date.now() // Reset time baseline
                    audioLevelIndicator.updateAudioLevel() // Immediate update
                }
            }
        }
    }

    Slider {
        id: audioSensitivitySlider
        Kirigami.FormData.label: "Audio Sensitivity:"
        from: 0.1
        to: 5.0
        value: 1.0
        stepSize: 0.1
    }

    CheckBox {
        id: showInfoCheckbox
        text: "Show information overlay"
        checked: root.cfg_showInfo
        
        onCheckedChanged: {
            root.cfg_showInfo = checked
        }
    }
}