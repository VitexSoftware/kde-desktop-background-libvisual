#!/usr/bin/env qml

import QtQuick 2.15
import LibVisualBackend 1.0

Rectangle {
    width: 400
    height: 200
    color: "black"
    
    LibVisualBackend {
        id: backend
        Component.onCompleted: {
            console.log("Backend loaded successfully!")
            console.log("FFT Size:", fftSize)
            console.log("Audio Active:", audioActive)
            console.log("Decibels:", decibels)
            console.log("Spectrum length:", spectrum.length)
        }
    }
    
    Text {
        anchors.centerIn: parent
        color: "white"
        text: "Backend Test\n" +
              "FFT Size: " + backend.fftSize + "\n" +
              "Audio: " + (backend.audioActive ? "active" : "inactive") + "\n" +
              "dB: " + backend.decibels.toFixed(1) + "\n" +
              "Spectrum bins: " + backend.spectrum.length
        font.pointSize: 12
    }
}