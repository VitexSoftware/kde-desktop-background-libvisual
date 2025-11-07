import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configRoot
    
    property alias cfg_audioDevice: audioDeviceCombo.currentText
    property alias cfg_sensitivity: sensitivitySlider.value
    property alias cfg_colorScheme: colorSchemeCombo.currentIndex
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
                // TODO: Populate with actual audio devices
            }
            
            Component.onCompleted: {
                // Load available audio devices
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
                    // Trigger test mode
                    if (typeof AudioVisualizerBackend !== 'undefined') {
                        AudioVisualizerBackend.testMode()
                    }
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
            text: i18n("Version 1.0.0 - VitexSoftware")
            color: Kirigami.Theme.disabledTextColor
            Kirigami.FormData.label: i18n("Version:")
        }
    }
}