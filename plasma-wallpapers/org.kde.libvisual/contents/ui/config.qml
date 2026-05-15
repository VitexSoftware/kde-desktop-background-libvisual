import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import AudioVisualizer 1.0

KCM.SimpleKCM {
    id: configRoot
    
    // cfg_audioDevice stores the PulseAudio source name (e.g. "alsa_input.pci-...")
    property string cfg_audioDevice: "default"
    property alias cfg_sensitivity: sensitivitySlider.value
    property alias cfg_audioSensitivity: sensitivitySlider.value
    property alias cfg_colorScheme: colorSchemeCombo.currentIndex
    property alias cfg_visualizationType: visualizationCombo.currentIndex
    property alias cfg_showStatusIndicator: statusIndicatorCheck.checked
    property alias cfg_smoothing: smoothingSlider.value
    property string cfg_projectMPresetPath: "/usr/share/projectM/presets"
    property bool   cfg_projectMShuffle: true
    property int    cfg_projectMDuration: 30
    property int    cfg_projectMPreset: -1

    // Parallel list of raw PA source names (indices match audioDeviceCombo model)
    property var paSourceNames: ["default"]

    // Real audio backend — reads from whichever device is selected in the combo
    AudioVisualizer {
        id: configAudio
        audioSource: configRoot.cfg_audioDevice
        Component.onCompleted: start()
        Component.onDestruction: stop()
    }
    
    Kirigami.FormLayout {
        id: formLayout
        anchors.fill: parent
        
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("Audio Settings")
            Kirigami.FormData.isSection: true
        }
        
ComboBox {
            id: audioDeviceCombo
            Kirigami.FormData.label: i18n("Input Device:")
            model: ListModel {
                id: audioDeviceModel
                ListElement { text: "Default Input Device" }
            }

            // When the user picks a different device, persist the PA source name
            onActivated: {
                if (currentIndex >= 0 && currentIndex < configRoot.paSourceNames.length)
                    configRoot.cfg_audioDevice = configRoot.paSourceNames[currentIndex]
            }

            Component.onCompleted: {
                var sources = configAudio.getInputSources()
                audioDeviceModel.clear()
                configRoot.paSourceNames = []
                var names = []
                for (var i = 0; i < sources.length; i++) {
                    audioDeviceModel.append({"text": sources[i].description})
                    names.push(sources[i].name)
                }
                configRoot.paSourceNames = names

                // Restore previously saved selection
                var savedIdx = names.indexOf(configRoot.cfg_audioDevice)
                currentIndex = savedIdx >= 0 ? savedIdx : 0
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

                // Driven by the real audio backend — -60 dB when no signal / no mic
                readonly property real currentLevel: configAudio.decibels

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
                i18n("Lissajous"),
                i18n("Circular Burst"),
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
                i18n("Kaleidoscope"),
                i18n("ProjectM Visualizer")
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
                
                Canvas {
                    id: previewCanvas
                    anchors.fill: parent
                    anchors.margins: 2

                    onPaint: {
                        var ctx = getContext("2d")
                        var t = visualizationPreview.previewTime
                        var type = visualizationCombo.currentIndex
                        var W = width, H = height
                        var cx = W/2, cy = H/2
                        ctx.clearRect(0, 0, W, H)
                        ctx.fillStyle = "#111"; ctx.fillRect(0, 0, W, H)

                        if (type === 0) {
                            // Spectrum bars
                            var n = 18
                            for (var i = 0; i < n; i++) {
                                var h = 4 + Math.abs(Math.sin(t*3 + i*0.5)) * (H - 8)
                                var hue = i/n
                                ctx.fillStyle = Qt.hsva(hue, 0.9, 0.9, 1)
                                ctx.fillRect(i*(W/n)+1, H-h, W/n-2, h)
                            }
                        } else if (type === 1) {
                            // Waveform
                            ctx.strokeStyle = "#00ffff"; ctx.lineWidth = 2; ctx.beginPath()
                            for (var x = 0; x < W; x += 2) {
                                var wy = cy + Math.sin(t*4 + x*0.12)*14 + Math.cos(t*6 + x*0.08)*7
                                if (x===0) ctx.moveTo(x,wy); else ctx.lineTo(x,wy)
                            }
                            ctx.stroke()
                        } else if (type === 2) {
                            // Lissajous
                            ctx.strokeStyle = "#00ff88"; ctx.lineWidth = 1.5; ctx.beginPath()
                            var steps = 120
                            for (var s = 0; s <= steps; s++) {
                                var a = (s/steps)*Math.PI*4 + t*2
                                var lx = cx + Math.sin(a*2+t)*cx*0.7
                                var ly = cy + Math.cos(a*3+t)*cy*0.7
                                if (s===0) ctx.moveTo(lx,ly); else ctx.lineTo(lx,ly)
                            }
                            ctx.stroke()
                        } else if (type === 3) {
                            // Circular Burst
                            for (var r = 0; r < 5; r++) {
                                var cr = 8 + r*8 + Math.sin(t*2+r)*4
                                ctx.beginPath(); ctx.arc(cx,cy,cr,0,Math.PI*2)
                                ctx.strokeStyle = Qt.hsva(r/5+t*0.05, 0.8, 1, 0.7+r*0.06)
                                ctx.lineWidth = 1.5; ctx.stroke()
                            }
                        } else if (type === 4) {
                            // Circular Spectrum
                            var cn = 24, ir = Math.min(cx,cy)*0.25, or2 = Math.min(cx,cy)*0.85
                            for (var i = 0; i < cn; i++) {
                                var ang = (i/cn)*Math.PI*2 - Math.PI/2
                                var mag = 0.2 + 0.8*Math.abs(Math.sin(t*3+i*0.4))
                                var bl = (or2-ir)*mag
                                ctx.strokeStyle = Qt.hsva((i/cn+t*0.05)%1, 0.9, 0.9, 0.9)
                                ctx.lineWidth = 2.5; ctx.lineCap = "round"; ctx.beginPath()
                                ctx.moveTo(cx+Math.cos(ang)*ir, cy+Math.sin(ang)*ir)
                                ctx.lineTo(cx+Math.cos(ang)*(ir+bl), cy+Math.sin(ang)*(ir+bl))
                                ctx.stroke()
                            }
                        } else if (type === 5) {
                            // Plasma blobs
                            for (var b = 0; b < 5; b++) {
                                var bx = cx + Math.sin(t*(0.3+b*0.1)+b*1.2)*cx*0.6
                                var by = cy + Math.cos(t*(0.2+b*0.1)+b*0.8)*cy*0.6
                                var bs = Math.min(cx,cy) * (0.4+0.2*Math.sin(t*(0.5+b*0.1)+b))
                                var gr = ctx.createRadialGradient(bx,by,0,bx,by,bs)
                                gr.addColorStop(0, Qt.hsva((b/5+t*0.04)%1, 0.9, 1.0, 0.5))
                                gr.addColorStop(1, Qt.hsva((b/5+t*0.04)%1, 0.9, 1.0, 0.0))
                                ctx.fillStyle = gr; ctx.beginPath()
                                ctx.arc(bx,by,bs,0,Math.PI*2); ctx.fill()
                            }
                        } else if (type === 6) {
                            // Starfield
                            for (var i = 0; i < 40; i++) {
                                var ang = (i/40)*Math.PI*2 + Math.sin(i*1.7)*0.5
                                var spd = 0.04 + (i%10)*0.012
                                var d = ((t*spd + i*0.05) % 0.55) * Math.min(cx,cy) * 1.8
                                var ss = Math.max(1, d/Math.min(cx,cy)*5)
                                ctx.fillStyle = Qt.rgba(0.8,0.9,1.0, Math.min(1,d/(Math.min(cx,cy)*0.5)))
                                ctx.beginPath(); ctx.arc(cx+Math.cos(ang)*d, cy+Math.sin(ang)*d, ss, 0, Math.PI*2); ctx.fill()
                            }
                        } else if (type === 7) {
                            // Fireworks
                            ctx.fillStyle = Qt.rgba(0,0,0,0.1); ctx.fillRect(0,0,W,H)
                            for (var b = 0; b < 3; b++) {
                                var bx = W*(0.2+b*0.3), by = H*(0.2+Math.sin(t*0.7+b)*0.25)
                                for (var p = 0; p < 10; p++) {
                                    var pa = (p/10)*Math.PI*2 + t*(0.5+b*0.3)
                                    var pd = 12+Math.sin(t*2+p+b)*8
                                    ctx.beginPath(); ctx.arc(bx+Math.cos(pa)*pd, by+Math.sin(pa)*pd, 2, 0, Math.PI*2)
                                    ctx.fillStyle = Qt.hsva((b/3+p*0.1+t*0.05)%1, 0.9, 1, 0.8); ctx.fill()
                                }
                            }
                        } else if (type === 8) {
                            // Matrix Rain
                            ctx.font = "bold 8px monospace"
                            var cols = Math.floor(W/8), chars = "01ABEF"
                            for (var c = 0; c < cols; c++) {
                                var cy2 = ((t*(1+c%3)*0.3 + c*0.07) % 1.0) * H
                                ctx.fillStyle = "#00ff00"; ctx.fillText(chars[Math.floor(t*5+c)%chars.length], c*8, cy2)
                                ctx.fillStyle = "#006600"; ctx.fillText(chars[Math.floor(t*3+c*2)%chars.length], c*8, cy2-8)
                                ctx.fillStyle = "#003300"; ctx.fillText(chars[Math.floor(t*2+c*3)%chars.length], c*8, cy2-16)
                            }
                        } else if (type === 9) {
                            // DNA Helix
                            var ampX2 = cx*0.6
                            for (var i = 1; i < 20; i++) {
                                var a1 = (i/20)*Math.PI*4 + t*1.5
                                var a0 = ((i-1)/20)*Math.PI*4 + t*1.5
                                var y1 = (i/20)*H, y0 = ((i-1)/20)*H
                                ctx.strokeStyle = "#4488ff"; ctx.lineWidth=2; ctx.beginPath()
                                ctx.moveTo(cx+Math.cos(a0)*ampX2, y0); ctx.lineTo(cx+Math.cos(a1)*ampX2, y1); ctx.stroke()
                                ctx.strokeStyle = "#ff4444"; ctx.beginPath()
                                ctx.moveTo(cx+Math.cos(a0+Math.PI)*ampX2, y0); ctx.lineTo(cx+Math.cos(a1+Math.PI)*ampX2, y1); ctx.stroke()
                                if (i%3===0) {
                                    ctx.strokeStyle = Qt.rgba(0.8,0.8,0.3,0.6); ctx.lineWidth=1; ctx.beginPath()
                                    ctx.moveTo(cx+Math.cos(a1)*ampX2, y1); ctx.lineTo(cx+Math.cos(a1+Math.PI)*ampX2, y1); ctx.stroke()
                                }
                            }
                        } else if (type === 10) {
                            // Particle Storm
                            for (var i = 0; i < 50; i++) {
                                var ang = (i/50)*Math.PI*2 + t*(0.1+(i%7)*0.02)
                                var d = Math.min(cx,cy)*0.1 + Math.min(cx,cy)*0.75*Math.abs(Math.sin(t*(0.3+i*0.02)+i))
                                var ps = 2+Math.sin(t+i)*1
                                ctx.fillStyle = Qt.hsva((i/50+t*0.03)%1, 0.9, 1, 0.8)
                                ctx.beginPath(); ctx.arc(cx+Math.cos(ang)*d, cy+Math.sin(ang)*d, ps, 0, Math.PI*2); ctx.fill()
                            }
                        } else if (type === 11) {
                            // Ripple Effect
                            for (var r = 0; r < 6; r++) {
                                var phase = (t*0.8 + r/6) % 1.0
                                var rr = Math.min(cx,cy) * phase * 1.4
                                ctx.beginPath(); ctx.arc(cx,cy,rr,0,Math.PI*2)
                                ctx.strokeStyle = Qt.hsva(((1-phase)*0.6+t*0.05)%1, 0.8, 1, (1-phase)*0.9)
                                ctx.lineWidth = 1.5; ctx.stroke()
                            }
                        } else if (type === 12) {
                            // Tunnel Vision
                            for (var r = 0; r < 7; r++) {
                                var phase = (t*0.4 + r/7) % 1.0
                                var tw = W * phase*phase * 0.95
                                var th = H * phase*phase * 0.95
                                ctx.save(); ctx.translate(cx,cy); ctx.rotate(t*0.3+r*0.4)
                                ctx.strokeStyle = Qt.hsva(((phase+t*0.05)%1), 0.9, 1, (1-phase)*0.85)
                                ctx.lineWidth=1.5; ctx.strokeRect(-tw/2,-th/2,tw,th); ctx.restore()
                            }
                        } else if (type === 13) {
                            // Spiral Galaxy
                            for (var i = 0; i < 60; i++) {
                                var arm = i%3, armAng = (arm/3)*Math.PI*2
                                var it2 = (i/60)*5
                                var ang = armAng + it2 + t*0.2*(arm%2===0?1:-0.5)
                                var d = it2 * Math.min(cx,cy) * 0.17
                                var ps = Math.max(1, 2.5-it2*0.3)
                                ctx.fillStyle = Qt.hsva((arm/3+it2*0.05+t*0.02)%1, 0.7, 0.9, 0.8)
                                ctx.beginPath(); ctx.arc(cx+Math.cos(ang)*d, cy+Math.sin(ang)*d, ps, 0, Math.PI*2); ctx.fill()
                            }
                        } else if (type === 14) {
                            // Lightning
                            function bolt(x1,y1,x2,y2,r,d) {
                                if(d<=0){ctx.beginPath();ctx.moveTo(x1,y1);ctx.lineTo(x2,y2);ctx.stroke();return}
                                var mx=(x1+x2)/2+(Math.random()-0.5)*r, my=(y1+y2)/2+(Math.random()-0.5)*r
                                bolt(x1,y1,mx,my,r/2,d-1); bolt(mx,my,x2,y2,r/2,d-1)
                            }
                            ctx.strokeStyle=Qt.rgba(0.6,0.6,1,0.9); ctx.lineWidth=1
                            bolt(cx,0,cx+(Math.random()-0.5)*30,H*0.7,W*0.18,4)
                        } else if (type === 15) {
                            // Mandelbrot (CPU, low-res preview)
                            var maxIter=25, zoom=0.5+Math.sin(t)*0.3
                            for (var px=0; px<W; px+=3) {
                                for (var py=0; py<H; py+=3) {
                                    var x0=(px/W-0.5)*3*zoom-0.5, y0=(py/H-0.5)*2*zoom
                                    var x=0,y=0,it=0
                                    while(x*x+y*y<=4&&it<maxIter){var xt=x*x-y*y+x0;y=2*x*y+y0;x=xt;it++}
                                    if(it<maxIter){ctx.fillStyle=Qt.hsva(it/maxIter,0.8,0.8,1);ctx.fillRect(px,py,3,3)}
                                }
                            }
                        } else if (type === 16) {
                            // Geometric Dance
                            var polys = [{s:3,r:0.20,sp:1.2},{s:5,r:0.38,sp:-0.7},{s:6,r:0.55,sp:0.5}]
                            for (var pi=0; pi<polys.length; pi++) {
                                var p=polys[pi], ang=t*p.sp+pi, rad=Math.min(cx,cy)*p.r
                                ctx.beginPath()
                                for (var v=0;v<=p.s;v++){var a=ang+(v/p.s)*Math.PI*2;if(v===0)ctx.moveTo(cx+Math.cos(a)*rad,cy+Math.sin(a)*rad);else ctx.lineTo(cx+Math.cos(a)*rad,cy+Math.sin(a)*rad)}
                                ctx.strokeStyle=Qt.hsva((pi/3+t*0.04)%1,0.9,1,0.9); ctx.lineWidth=1.5; ctx.stroke()
                            }
                        } else if (type === 17) {
                            // Audio Bars 3D
                            var nb=12, hY=H*0.5, vX=cx
                            for (var i=0; i<nb; i++) {
                                var mag=0.15+0.85*Math.abs(Math.sin(t*3+i*0.5))
                                var fxl=i*(W/nb)+1, fxr=fxl+W/nb-2, bh=(H-hY)*mag
                                var tfy=H-10-bh, tvl=vX+(fxl-vX)*0.3, tvr=vX+(fxr-vX)*0.3, tvy=hY+(tfy-hY)*0.3
                                var hue=i/nb
                                ctx.beginPath(); ctx.moveTo(fxl,H-10); ctx.lineTo(fxr,H-10); ctx.lineTo(fxr,tfy); ctx.lineTo(fxl,tfy); ctx.closePath()
                                ctx.fillStyle=Qt.hsva(hue,0.8,0.6+mag*0.4,0.9); ctx.fill()
                                ctx.beginPath(); ctx.moveTo(fxl,tfy); ctx.lineTo(fxr,tfy); ctx.lineTo(tvr,tvy); ctx.lineTo(tvl,tvy); ctx.closePath()
                                ctx.fillStyle=Qt.hsva(hue,0.5,0.9,0.9); ctx.fill()
                            }
                        } else if (type === 18) {
                            // Kaleidoscope
                            var segs=8, sAng=Math.PI*2/segs
                            for (var seg=0; seg<segs; seg++) {
                                ctx.save(); ctx.translate(cx,cy); ctx.rotate(seg*sAng+t*0.1)
                                ctx.beginPath(); ctx.moveTo(0,0); ctx.arc(0,0,Math.min(cx,cy)*1.05,-sAng/2,sAng/2); ctx.closePath(); ctx.clip()
                                if(seg%2===1) ctx.scale(-1,1)
                                for (var l=0; l<3; l++) {
                                    var lx=Math.min(cx,cy)*0.3*Math.sin(t*(0.5+l*0.3)+l*1.2)
                                    var ly=Math.min(cx,cy)*0.2*Math.cos(t*(0.4+l*0.2)+l)
                                    var ls=Math.min(cx,cy)*(0.12+0.12*l)
                                    ctx.beginPath(); ctx.arc(lx,ly,ls,0,Math.PI*2)
                                    ctx.fillStyle=Qt.hsva((l/3+t*0.05)%1,0.8,0.9,0.4); ctx.fill()
                                }
                                ctx.restore()
                            }
                        } else if (type === 19) {
                            // ProjectM — animated psychedelic blob preview
                            ctx.fillStyle = "#050010"; ctx.fillRect(0, 0, W, H)
                            for (var i = 0; i < 6; i++) {
                                var ang = (i / 6) * Math.PI * 2 + t * 0.5
                                var r2 = Math.min(cx, cy) * (0.3 + 0.5 * Math.abs(Math.sin(t * 0.7 + i)))
                                var gr = ctx.createRadialGradient(
                                    cx + Math.cos(ang) * cx * 0.25, cy + Math.sin(ang) * cy * 0.25, 0,
                                    cx + Math.cos(ang) * cx * 0.25, cy + Math.sin(ang) * cy * 0.25, r2)
                                gr.addColorStop(0, Qt.hsva((i / 6 + t * 0.04) % 1, 0.95, 1.0, 0.55))
                                gr.addColorStop(1, Qt.hsva((i / 6 + t * 0.04) % 1, 0.95, 1.0, 0.0))
                                ctx.fillStyle = gr
                                ctx.beginPath()
                                ctx.arc(cx + Math.cos(ang) * cx * 0.25,
                                        cy + Math.sin(ang) * cy * 0.25,
                                        r2 * 0.7, 0, Math.PI * 2)
                                ctx.fill()
                            }
                        }
                    }

                    onVisibleChanged: if (visible) requestPaint()
                }

                Timer {
                    interval: 80
                    running: true
                    repeat: true
                    onTriggered: {
                        visualizationPreview.previewTime += 0.08
                        previewCanvas.requestPaint()
                    }
                }
            }
            
            Item { Layout.fillWidth: true }
        }
        
        Kirigami.Separator {
            Kirigami.FormData.label: i18n("ProjectM Settings")
            Kirigami.FormData.isSection: true
            visible: visualizationCombo.currentIndex === 19
        }

        ComboBox {
            id: presetCombo
            Kirigami.FormData.label: i18n("Preset:")
            visible: visualizationCombo.currentIndex === 19
            model: {
                var names = configAudio.scanProjectMPresets(configRoot.cfg_projectMPresetPath)
                var result = [i18n("Shuffle (auto)")]
                for (var i = 0; i < names.length; i++) result.push(names[i])
                return result
            }
            currentIndex: Math.max(0, configRoot.cfg_projectMPreset + 1)
            onActivated: configRoot.cfg_projectMPreset = currentIndex - 1
        }

        CheckBox {
            id: projectMShuffleCheck
            Kirigami.FormData.label: i18n("Auto-shuffle:")
            visible: visualizationCombo.currentIndex === 19
            checked: configRoot.cfg_projectMShuffle
            onToggled: configRoot.cfg_projectMShuffle = checked
        }

        SpinBox {
            id: projectMDurationSpin
            Kirigami.FormData.label: i18n("Duration per preset (s):")
            visible: visualizationCombo.currentIndex === 19
            from: 5; to: 300; value: configRoot.cfg_projectMDuration
            onValueModified: configRoot.cfg_projectMDuration = value
        }

        Label {
            visible: visualizationCombo.currentIndex === 19
            text: i18n("Works on Wayland (EGL/OpenGL) and X11.\nOn Vulkan backends set QSG_RHI_BACKEND=opengl.")
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.disabledTextColor
            Kirigami.FormData.label: i18n("Backend note:")
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
            text: i18n("Version 1.2.0 - VitexSoftware")
            color: Kirigami.Theme.disabledTextColor
            Kirigami.FormData.label: i18n("Version:")
        }
    }
}