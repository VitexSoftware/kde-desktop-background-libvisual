import QtQuick 2.15
import QtQuick.Window 2.15
import AudioVisualizer 1.0

Window {
    width: 400
    height: 200
    visible: true
    title: "AudioVisualizer Test"
    
    AudioVisualizer {
        id: visualizer
        Component.onCompleted: {
            console.log("AudioVisualizer loaded successfully!")
            console.log("Device count:", deviceCount)
            console.log("Running:", running)
        }
    }
    
    Rectangle {
        anchors.centerIn: parent
        width: 200
        height: 50
        color: "green"
        Text {
            anchors.centerIn: parent
            text: "AudioVisualizer Test"
            color: "white"
        }
    }
}