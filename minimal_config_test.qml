/*
 * Test minimal configuration for LibVisual wallpaper
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

Kirigami.FormLayout {
    id: root

    property alias cfg_visualizationType: visualizationCombo.currentIndex
    property alias cfg_audioSensitivity: audioSensitivitySlider.value
    property alias cfg_showInfo: showInfoCheckbox.checked

    ComboBox {
        id: visualizationCombo
        Kirigami.FormData.label: "Visualization Type:"
        model: ["Spectrum Analyzer", "Waveform", "Oscilloscope", "Fractal"]
        currentIndex: 0
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
        text: "✅ Minimal configuration test - working!"
        color: "green"
        font.bold: true
    }
}