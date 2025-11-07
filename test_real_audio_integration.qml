#!/usr/bin/env qml

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import LibVisualBackend 1.0

ApplicationWindow {
    id: window
    width: 800
    height: 600
    title: "Real Audio Backend Integration Test"
    visible: true
    
    property real testSensitivity: 1.0
    
    LibVisualBackend {
        id: backend
        
        Component.onCompleted: {
            console.log("=== Real Audio Backend Integration Test ===")
            console.log("Backend initialized successfully!")
            console.log("FFT Size:", fftSize)
            console.log("Initial audio active:", audioActive)
            console.log("Initial decibels:", decibels)
            console.log("Spectrum array length:", spectrum.length)
        }
        
        onAudioActiveChanged: {
            console.log("Audio active state changed:", audioActive)
            statusText.text = audioActive ? "AUDIO ACTIVE" : "AUDIO INACTIVE"
            statusText.color = audioActive ? "green" : "red"
        }
        
        onDecibelsChanged: {
            if (Math.random() < 0.05) { // Log 5% of the time
                console.log("Audio level:", decibels.toFixed(1), "dB")
            }
        }
    }
    
    // Main test interface
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        
        Text {
            id: statusText
            text: "INITIALIZING..."
            font.pointSize: 24
            font.bold: true
            color: "blue"
            Layout.alignment: Qt.AlignHCenter
        }
        
        GroupBox {
            title: "Backend Status"
            Layout.fillWidth: true
            
            GridLayout {
                columns: 2
                anchors.fill: parent
                
                Label { text: "FFT Size:" }
                Label { text: backend.fftSize }
                
                Label { text: "Audio Active:" }
                Label { 
                    text: backend.audioActive ? "YES" : "NO"
                    color: backend.audioActive ? "green" : "red"
                    font.bold: true
                }
                
                Label { text: "Decibels:" }
                Label { 
                    text: backend.decibels.toFixed(1) + " dB"
                    color: backend.decibels > -50 ? "green" : "gray"
                }
                
                Label { text: "Spectrum Bins:" }
                Label { text: backend.spectrum.length }
            }
        }
        
        GroupBox {
            title: "Audio Level Simulation (like main wallpaper)"
            Layout.fillWidth: true
            
            GridLayout {
                columns: 2
                anchors.fill: parent
                
                Label { text: "Audio Peak:" }
                Label { 
                    property real audioPeak: backend.audioActive ? 
                        Math.max(0.1, (backend.decibels + 60) / 60 * testSensitivity) : 0.1
                    text: audioPeak.toFixed(2)
                    color: "orange"
                }
                
                Label { text: "Bass Level (0-15):" }
                Label { 
                    property real bassLevel: getBandLevel(0, 15)
                    text: bassLevel.toFixed(2)
                    color: "red"
                }
                
                Label { text: "Mid Level (16-39):" }
                Label { 
                    property real midLevel: getBandLevel(16, 39)
                    text: midLevel.toFixed(2) 
                    color: "yellow"
                }
                
                Label { text: "Treble Level (40-63):" }
                Label { 
                    property real trebleLevel: getBandLevel(40, 63)
                    text: trebleLevel.toFixed(2)
                    color: "cyan"
                }
            }
        }
        
        GroupBox {
            title: "Real-time Spectrum Preview"
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            Rectangle {
                anchors.fill: parent
                color: "black"
                
                Row {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2
                    
                    Repeater {
                        model: Math.min(32, backend.spectrum.length)
                        
                        Rectangle {
                            width: 10
                            height: Math.max(5, (backend.spectrum[index] || 0) * 200 * testSensitivity)
                            color: index < 8 ? "red" : index < 16 ? "yellow" : index < 24 ? "green" : "cyan"
                            
                            Text {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: -15
                                text: index
                                color: "white"
                                font.pointSize: 8
                            }
                        }
                    }
                }
            }
        }
        
        RowLayout {
            Label { text: "Test Sensitivity:" }
            Slider {
                from: 0.1
                to: 3.0
                value: testSensitivity
                onValueChanged: testSensitivity = value
                Layout.fillWidth: true
            }
            Label { text: testSensitivity.toFixed(1) }
        }
        
        Button {
            text: "Generate Test Audio Instructions"
            Layout.alignment: Qt.AlignHCenter
            onClicked: {
                console.log("=== To test audio capture ===")
                console.log("1. Play music or speak into microphone") 
                console.log("2. Watch for 'Audio Active' to turn green")
                console.log("3. Observe spectrum bars responding to audio")
                console.log("4. Check decibel levels changing above -50 dB")
            }
        }
    }
    
    function getBandLevel(startBin, endBin) {
        if (!backend.audioActive || !backend.spectrum || backend.spectrum.length === 0) {
            return 0.1
        }
        
        let sum = 0
        let count = 0
        for (let i = startBin; i <= endBin && i < backend.spectrum.length; i++) {
            sum += backend.spectrum[i] || 0
            count++
        }
        return count > 0 ? Math.max(0.1, (sum / count) * testSensitivity) : 0.1
    }
}