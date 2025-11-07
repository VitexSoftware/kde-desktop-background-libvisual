#!/usr/bin/env qml

import QtQuick 2.15
import QtQuick.Window 2.15
import LibVisualBackend 1.0

Window {
    width: 640
    height: 480
    visible: true
    title: "LibVisual Backend Test"
    color: "black"
    
    LibVisualBackend {
        id: backend
        Component.onCompleted: {
            console.log("LibVisualBackend loaded successfully!")
            console.log("Audio devices available:", backend.deviceCount)
            console.log("Is running:", backend.running)
        }
        
        onRunningChanged: {
            console.log("Backend running state changed:", running)
        }
        
        onAudioDataChanged: {
            console.log("Audio data received, length:", audioData.length)
        }
    }
    
    Rectangle {
        anchors.centerIn: parent
        width: 200
        height: 50
        color: backend.running ? "green" : "red"
        
        Text {
            anchors.centerIn: parent
            text: backend.running ? "AUDIO ACTIVE" : "AUDIO INACTIVE"
            color: "white"
            font.bold: true
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (backend.running) {
                    backend.stop()
                } else {
                    backend.start()
                }
            }
        }
    }
    
    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Click rectangle to start/stop audio capture"
        color: "white"
    }
}