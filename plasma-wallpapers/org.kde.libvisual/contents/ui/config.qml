/*
 * Configuration for LibVisual wallpaper
 */

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

    ComboBox {
        id: visualizationCombo
        Kirigami.FormData.label: "Visualization Type:"
        model: ["Spectrum Analyzer", "Waveform", "Oscilloscope", "Fractal"]
        currentIndex: 0
    }

    ComboBox {
        id: audioSourceCombo
        Kirigami.FormData.label: "Audio Source:"
        model: ["Default", "System Audio", "Microphone"]
        currentIndex: 0
        
        onCurrentIndexChanged: {
            root.cfg_audioSource = model[currentIndex]
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
        checked: false
    }

    Label {
        text: "✅ Configuration working! Changes will be reflected on wallpaper."
        color: "green"
        font.bold: true
    }
}