import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configRoot
    
    property alias cfg_audioDevice: audioDeviceCombo.currentText
    property alias cfg_sensitivity: sensitivitySlider.value
    property alias cfg_audioSensitivity: sensitivitySlider.value
    property alias cfg_colorScheme: colorSchemeCombo.currentIndex
    property alias cfg_visualizationType: visualizationCombo.currentIndex
    property alias cfg_showStatusIndicator: statusIndicatorCheck.checked
    property alias cfg_smoothing: smoothingSlider.value
    
    Kirigami.FormLayout {
        id: formLayout
        anchors.fill: parent
        
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Audio Settings")
            Kirigami.FormData.isSection: true
        }
        
ComboBox {
            id: audioDeviceCombo
            Kirigami.FormData.label: i18n("Audio Device:")
            model: ListModel {
                ListElement { text: "Default" }
                ListElement { text: "Built-in Audio" }
                ListElement { text: "USB Audio" }
            }
            
            Component.onCompleted: {
                if (typeof AudioVisualizerBackend !== 'undefined') {
                    try {
                        var devices = AudioVisualizerBackend.getAudioDevices()
                        model.clear()
                        for (var i = 0; i < devices.length; i++) {
                            model.append({"text": devices[i]})
                        }
                    } catch (error) {
                        console.error("Failed to load audio devices:", error)
                    }
                }
            }
        }
        
        RowLayout {
            Kirigami.FormData.label: i18n("Audio Level:")
            spacing: 10
            
            Rectangle {
                id: audioLevelIndicator
                Layout.preferredWidth: 180
                Layout.preferredHeight: 40
                color: "#1e1e1e"
                border.color: "#444"
                border.width: 1

                property real currentLevel: -60
                property real baseTime: Date.now()
                
                Component.onCompleted: {
                    baseTime = Date.now()
                }
                
                function updateAudioLevel() {
                    var currentTime = Date.now()
                    var timeOffset = (currentTime - baseTime) / 1000.0
                    var activity = Math.abs(Math.sin(timeOffset * 2.0)) * Math.abs(Math.cos(timeOffset * 1.3))
                    currentLevel = -40 + (activity * 25)
                    currentLevel += (Math.random() * 2 - 1)
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 1

                    Repeater {
                        model: 12
                        Rectangle {
                            width: 12
                            height: parent.height - 6
                            anchors.verticalCenter: parent.verticalCenter

                            property real barThreshold: -60 + (index * 5)
                            property bool active: audioLevelIndicator.currentLevel > barThreshold

                            color: {
                                if (!active) return "#2a2a2a"
                                if (index < 7) return "#00ff00"
                                else if (index < 10) return "#ffff00"
                                else return "#ff0000"
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 3
                    width: 38
                    height: 16
                    color: "#000"
                    border.color: "#555"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: audioLevelIndicator.currentLevel.toFixed(0) + "dB"
                        color: {
                            var level = audioLevelIndicator.currentLevel
                            if (level < -50) return "#666"
                            else if (level < -30) return "#0f0"
                            else if (level < -12) return "#ff0"
                            else return "#f00"
                        }
                        font.family: "monospace"
                        font.pixelSize: 8
                    }
                }

                Timer {
                    interval: 50
                    running: true
                    repeat: true
                    onTriggered: audioLevelIndicator.updateAudioLevel()
                }
            }
            
            Item { Layout.fillWidth: true }
        }
        
        Slider {
            id: sensitivitySlider
            Kirigami.FormData.label: i18n("Sensitivity:")
            
            from: 0.1
            to: 5.0
            value: 1.0
            stepSize: 0.1
            
            ToolTip {
                parent: sensitivitySlider.handle
                visible: sensitivitySlider.pressed
                text: sensitivitySlider.value.toFixed(1)
            }
        }
        
        Slider {
            id: smoothingSlider
            Kirigami.FormData.label: i18n("Smoothing:")
            
            from: 0.0
            to: 1.0
            value: 0.8
            stepSize: 0.05
            
            ToolTip {
                parent: smoothingSlider.handle
                visible: smoothingSlider.pressed
                text: Math.round(smoothingSlider.value * 100) + "%"
            }
        }
        
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Visual Settings")
            Kirigami.FormData.isSection: true
        }
        
ComboBox {
            id: visualizationCombo
            Kirigami.FormData.label: i18n("Visualization Type:")
            model: [
                i18n("Spectrum Analyzer"),
                i18n("Waveform"),
                i18n("Radial Burst"),
                i18n("Oscilloscope"),
                i18n("Circular Spectrum"),
                i18n("Plasma"),
                i18n("Starfield"),
                i18n("Fireworks"),
                i18n("Matrix Rain"),
                i18n("DNA Helix"),
                i18n("Particle Storm"),
                i18n("Ripple Effect"),
                i18n("Tunnel Vision"),
                i18n("Spiral Galaxy"),
                i18n("Lightning"),
                i18n("Mandelbrot Zoom"),
                i18n("Geometric Dance"),
                i18n("Audio Bars 3D"),
                i18n("Kaleidoscope")
            ]
            currentIndex: 0
        }
        
        RowLayout {
            Kirigami.FormData.label: i18n("Preview:")
            spacing: 10
            
            Rectangle {
                id: visualizationPreview
                Layout.preferredWidth: 120
                Layout.preferredHeight: 60
                color: "#1a1a1a"
                border.color: "#444"
                border.width: 1

                property real previewTime: 0
                
                Item {
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true

                    Row {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 1
                        visible: visualizationCombo.currentIndex === 0

                        Repeater {
                            model: 12
                            Rectangle {
                                width: 6
                                height: 8 + Math.abs(Math.sin(visualizationPreview.previewTime * 3 + index * 0.5)) * 35
                                color: {
                                    var intensity = height / 43.0
                                    if (intensity < 0.3) return "#00ff00"
                                    else if (intensity < 0.7) return "#ffff00" 
                                    else return "#ff0000"
                                }
                            }
                        }
                    }

                    Canvas {
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

                    // Mandelbrot preview (type 15)
                    Canvas {
                        anchors.fill: parent
                        visible: visualizationCombo.currentIndex === 15
                        property real zoom: 0.5
                        
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            
                            var maxIter = 30
                            var zoomLevel = 0.5 + Math.sin(visualizationPreview.previewTime) * 0.3
                            
                            for (var px = 0; px < width; px += 2) {
                                for (var py = 0; py < height; py += 2) {
                                    var x0 = (px / width - 0.5) * 3 * zoomLevel - 0.5
                                    var y0 = (py / height - 0.5) * 2 * zoomLevel
                                    
                                    var x = 0, y = 0, iteration = 0
                                    while (x*x + y*y <= 4 && iteration < maxIter) {
                                        var xtemp = x*x - y*y + x0
                                        y = 2*x*y + y0
                                        x = xtemp
                                        iteration++
                                    }
                                    
                                    if (iteration < maxIter) {
                                        var ratio = iteration / maxIter
                                        var hue = ratio * 360
                                        ctx.fillStyle = Qt.hsva(hue, 0.8, 0.8, 1)
                                        ctx.fillRect(px, py, 2, 2)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Generic preview for other types
                    Item {
                        anchors.fill: parent
                        visible: visualizationCombo.currentIndex >= 2 && visualizationCombo.currentIndex !== 15
                        
                        Repeater {
                            model: 4
                            Rectangle {
                                anchors.centerIn: parent
                                width: 50 - index * 8
                                height: width
                                color: "transparent"
                                border.color: ["#ff0080", "#8000ff", "#0080ff", "#00ff80"][index]
                                border.width: 2
                                rotation: visualizationPreview.previewTime * (20 + index * 15)
                            }
                        }
                    }
                }

                Timer {
                    interval: 100
                    running: true
                    repeat: true
                    onTriggered: {
                        visualizationPreview.previewTime += 0.1
                        // Repaint waveform canvas
                        if (visualizationCombo.currentIndex === 1) {
                            visualizationPreview.children[0].children[1].requestPaint()
                        }
                        // Repaint Mandelbrot canvas
                        if (visualizationCombo.currentIndex === 15) {
                            visualizationPreview.children[0].children[2].requestPaint()
                        }
                    }
                }
            }
            
            Item { Layout.fillWidth: true }
        }
        
        ComboBox {
            id: colorSchemeCombo
            Kirigami.FormData.label: i18n("Color Scheme:")
            
            model: [
                i18n("Rainbow Spectrum"),
                i18n("Blue Gradient"),
                i18n("Fire"),
                i18n("Plasma"),
                i18n("Monochrome")
            ]
            currentIndex: 0
        }
        
        CheckBox {
            id: statusIndicatorCheck
            Kirigami.FormData.label: i18n("Show Status Indicator")
            text: i18n("Display a small indicator showing wallpaper status")
            checked: false
        }
        
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Performance")
            Kirigami.FormData.isSection: true
        }
        
        Label {
            text: i18n("Frame Rate: 60 FPS")
            Kirigami.FormData.label: i18n("Rendering:")
        }
        
        Label {
            text: i18n("Hardware-accelerated Canvas2D")
            Kirigami.FormData.label: i18n("Acceleration:")
        }
        
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("About")
            Kirigami.FormData.isSection: true
        }
        
        Label {
            text: i18n("Real-time audio spectrum visualization using FFTW3 library")
            wrapMode: Text.WordWrap
            Kirigami.FormData.label: i18n("Description:")
        }
        
        RowLayout {
            Kirigami.FormData.label: i18n("Test Audio:")
            
            Button {
                text: i18n("Test Visualization")
                icon.name: "media-playback-start"
                onClicked: {
                    // Play test tone
                    Qt.openUrlExternally("file:///usr/share/sounds/alsa/Front_Center.wav")
                }
            }
            
            Button {
                text: i18n("Reset Settings")
                icon.name: "edit-reset"
                onClicked: {
                    audioDeviceCombo.currentIndex = 0
                    sensitivitySlider.value = 1.0
                    colorSchemeCombo.currentIndex = 0
                    statusIndicatorCheck.checked = false
                    smoothingSlider.value = 0.8
                }
            }
        }
        
        Label {
            text: i18n("Version 1.1.4 - VitexSoftware")
            color: Kirigami.Theme.disabledTextColor
            Kirigami.FormData.label: i18n("Version:")
        }
    }
}