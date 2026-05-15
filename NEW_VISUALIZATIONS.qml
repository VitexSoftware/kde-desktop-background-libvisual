// NEW VISUALIZATIONS TO ADD TO main.qml
// Insert these between line 521 (after oscilloscope) and line 523 (before info overlay)

    // 4. Circular Spectrum - Radial audio bars
    Item {
        anchors.fill: parent
        visible: visualizationType === 4
        
        Repeater {
            model: 64
            Rectangle {
                property real spec: getRealSpectrumValue(index) * root.audioSensitivity
                property real angle: (index / 64) * Math.PI * 2
                property real radius: Math.min(parent.width, parent.height) * 0.15
                property real length: Math.max(20, spec * Math.min(parent.width, parent.height) * 0.35)
                
                width: 6
                height: length
                color: Qt.hsva(index / 64, 0.8, 0.6 + spec * 0.4, 0.9)
                radius: 3
                
                x: parent.width/2 + Math.cos(angle + root.t) * radius - width/2
                y: parent.height/2 + Math.sin(angle + root.t) * radius
                rotation: angle * 180 / Math.PI + 90 + root.t * 10
                transformOrigin: Item.Bottom
            }
        }
    }

    // 5. Plasma - Classic demo scene effect
    Canvas {
        anchors.fill: parent
        visible: visualizationType === 5
        
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            
            var imageData = ctx.createImageData(width, height)
            var data = imageData.data
            
            for (var y = 0; y < height; y += 2) {
                for (var x = 0; x < width; x += 2) {
                    var value = Math.sin(x * 0.01 + root.t * root.audioPeak) +
                               Math.sin(y * 0.01 + root.t * root.bassLevel) +
                               Math.sin((x + y) * 0.007 + root.t * root.midLevel) +
                               Math.sin(Math.sqrt(x*x + y*y) * 0.01 + root.t * 2)
                    
                    var index = (y * width + x) * 4
                    data[index] = Math.floor(128 + 128 * Math.sin(value + root.t))
                    data[index + 1] = Math.floor(128 + 128 * Math.sin(value + root.t + 2))
                    data[index + 2] = Math.floor(128 + 128 * Math.sin(value + root.t + 4))
                    data[index + 3] = 255
                }
            }
            ctx.putImageData(imageData, 0, 0)
        }
        
        Timer {
            interval: 33; running: parent.visible; repeat: true
            onTriggered: parent.requestPaint()
        }
    }

    // 6. Starfield - 3D moving stars
    Item {
        anchors.fill: parent
        visible: visualizationType === 6
        
        Repeater {
            model: 200
            Rectangle {
                id: star
                property real z: 100 + (index * 50) % 1000
                property real sx: (index * 157) % 200 - 100
                property real sy: (index * 211) % 200 - 100
                property real speed: 2 + root.audioPeak * 10
                
                width: Math.max(1, 10 / (z / 100))
                height: width
                radius: width/2
                color: Qt.rgba(1, 1, 1, Math.min(1, 500/z))
                
                x: parent.width/2 + (sx / z) * parent.width/2 * (1 + root.bassLevel)
                y: parent.height/2 + (sy / z) * parent.height/2 * (1 + root.trebleLevel)
                
                Timer {
                    interval: 33; running: parent.visible; repeat: true
                    onTriggered: {
                        star.z -= star.speed
                        if (star.z < 1) star.z = 1000
                    }
                }
            }
        }
    }

    // 7. Fireworks - Explosive particles
    Item {
        anchors.fill: parent
        visible: visualizationType === 7
        
        Repeater {
            model: root.audioPeak > 0.5 ? 100 : 0
            Rectangle {
                property real angle: Math.random() * Math.PI * 2
                property real velocity: 2 + Math.random() * 5 * root.audioSensitivity
                property real life: 1.0
                
                width: 4; height: 4; radius: 2
                color: Qt.hsva(Math.random(), 1, 1, life)
                
                x: parent.width/2 + Math.cos(angle) * velocity * (1 - life) * 200
                y: parent.height/2 + Math.sin(angle) * velocity * (1 - life) * 200 + (1-life) * (1-life) * 100
                
                PropertyAnimation on life {
                    from: 1.0; to: 0.0; duration: 2000
                    onFinished: life = 1.0
                }
            }
        }
    }

    // 8. Matrix Rain - Falling characters
    Item {
        anchors.fill: parent
        visible: visualizationType === 8
        
        Repeater {
            model: 40
            Column {
                property real fallSpeed: 2 + (index % 5) * root.audioPeak
                property real yPos: -(index * 50) % (parent.height + 500)
                
                x: (index * 37) % parent.width
                y: yPos
                spacing: 2
                
                Repeater {
                    model: 20
                    Text {
                        text: String.fromCharCode(0x30A0 + Math.floor(Math.random() * 96))
                        color: Qt.rgba(0, 0.8, 0, 1 - (index / 20))
                        font.family: "monospace"
                        font.pixelSize: 16
                    }
                }
                
                Timer {
                    interval: 50; running: parent.visible; repeat: true
                    onTriggered: {
                        parent.yPos += parent.fallSpeed
                        if (parent.yPos > parent.parent.height) parent.yPos = -500
                    }
                }
            }
        }
    }

    // 9. DNA Helix - Rotating double helix
    Item {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.8
        height: width
        visible: visualizationType === 9
        rotation: root.t * 20 * root.audioPeak
        
        Repeater {
            model: 50
            Item {
                property real phase: (index / 50) * Math.PI * 4 + root.t * 2
                property real yPos: (index / 50) * parent.height - parent.height/2
                
                Rectangle {
                    width: 15 + root.bassLevel * 10
                    height: width
                    radius: width/2
                    color: Qt.rgba(0.2 + root.audioPeak * 0.5, 0.3, 0.8, 0.8)
                    x: parent.parent.width/2 + Math.cos(phase) * parent.parent.width * 0.25
                    y: parent.parent.height/2 + yPos
                }
                
                Rectangle {
                    width: 15 + root.trebleLevel * 10
                    height: width
                    radius: width/2
                    color: Qt.rgba(0.8, 0.3, 0.2 + root.audioPeak * 0.5, 0.8)
                    x: parent.parent.width/2 - Math.cos(phase) * parent.parent.width * 0.25
                    y: parent.parent.height/2 + yPos
                }
            }
        }
    }

    // 10. Particle Storm - Chaotic particle system
    Item {
        anchors.fill: parent
        visible: visualizationType === 10
        
        Repeater {
            model: 150
            Rectangle {
                property real vx: (Math.random() - 0.5) * 4
                property real vy: (Math.random() - 0.5) * 4
                property real px: Math.random() * parent.width
                property real py: Math.random() * parent.height
                
                width: 3 + root.audioPeak * 5
                height: width
                radius: width/2
                color: Qt.hsva((index / 150 + root.t * 0.1) % 1, 0.8, 0.9, 0.7)
                x: px
                y: py
                
                Timer {
                    interval: 33; running: parent.visible; repeat: true
                    onTriggered: {
                        var force = root.audioSensitivity * root.audioPeak * 0.5
                        parent.vx += (Math.random() - 0.5) * force
                        parent.vy += (Math.random() - 0.5) * force
                        parent.px += parent.vx
                        parent.py += parent.vy
                        
                        if (parent.px < 0 || parent.px > parent.parent.width) parent.vx *= -0.8
                        if (parent.py < 0 || parent.py > parent.parent.height) parent.vy *= -0.8
                        
                        parent.px = Math.max(0, Math.min(parent.parent.width, parent.px))
                        parent.py = Math.max(0, Math.min(parent.parent.height, parent.py))
                    }
                }
            }
        }
    }

    // 11. Ripple Effect - Concentric waves
    Item {
        anchors.fill: parent
        visible: visualizationType === 11
        
        Repeater {
            model: 15
            Rectangle {
                anchors.centerIn: parent
                width: 50 + index * 100 * (1 + root.audioPeak)
                height: width
                radius: width/2
                color: "transparent"
                border.color: Qt.hsva((index / 15 + root.t * 0.1) % 1, 0.8, 0.9, 0.6 - index * 0.04)
                border.width: 3 + root.bassLevel * 3
                rotation: root.t * (10 + index * 2)
            }
        }
    }

    // 12. Tunnel Vision - 3D tunnel effect
    Canvas {
        anchors.fill: parent
        visible: visualizationType === 12
        
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            
            var centerX = width / 2
            var centerY = height / 2
            
            for (var i = 20; i > 0; i--) {
                var size = i * 50 * (1 + root.audioPeak * 0.5)
                var hue = ((i / 20) + root.t * 0.2) % 1
                
                ctx.strokeStyle = "hsl(" + (hue * 360) + ", 80%, 50%)"
                ctx.lineWidth = 3 + root.bassLevel * 2
                ctx.strokeRect(centerX - size/2, centerY - size/2, size, size)
            }
        }
        
        Timer {
            interval: 33; running: parent.visible; repeat: true
            onTriggered: parent.requestPaint()
        }
    }

    // 13. Spiral Galaxy - Rotating spiral arms
    Item {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        visible: visualizationType === 13
        rotation: root.t * 15
        
        Repeater {
            model: 6
            Repeater {
                model: 40
                Rectangle {
                    property real armAngle: (parent.index / 6) * Math.PI * 2
                    property real dist: index * 10
                    property real spiralAngle: armAngle + (index * 0.2)
                    
                    width: 4 + root.audioPeak * 6
                    height: width
                    radius: width/2
                    color: Qt.hsva((index / 40 + root.t * 0.1) % 1, 0.9, 0.9, 0.8)
                    
                    x: parent.parent.parent.width/2 + Math.cos(spiralAngle) * dist
                    y: parent.parent.parent.height/2 + Math.sin(spiralAngle) * dist
                }
            }
        }
    }

    // 14. Lightning - Electric bolts
    Canvas {
        anchors.fill: parent
        visible: visualizationType === 14
        
        onPaint: {
            if (root.audioPeak < 0.3) return
            
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            
            ctx.strokeStyle = Qt.rgba(0.7, 0.7, 1, 0.9)
            ctx.lineWidth = 2 + root.audioPeak * 3
            ctx.shadowColor = "cyan"
            ctx.shadowBlur = 15
            
            for (var bolt = 0; bolt < 3; bolt++) {
                ctx.beginPath()
                var x = Math.random() * width
                var y = 0
                ctx.moveTo(x, y)
                
                while (y < height) {
                    x += (Math.random() - 0.5) * 100 * root.audioSensitivity
                    y += Math.random() * 50 + 30
                    ctx.lineTo(x, y)
                }
                ctx.stroke()
            }
        }
        
        Timer {
            interval: 100; running: parent.visible; repeat: true
            onTriggered: if (Math.random() < root.audioPeak) parent.requestPaint()
        }
    }

    // 15. Mandelbrot Zoom - Fractal zoom
    Canvas {
        anchors.fill: parent
        visible: visualizationType === 15
        
        property real zoom: 1 + root.t * 0.1
        
        onPaint: {
            var ctx = getContext("2d")
            var imageData = ctx.createImageData(width, height)
            var data = imageData.data
            
            for (var py = 0; py < height; py += 4) {
                for (var px = 0; px < width; px += 4) {
                    var x0 = (px / width - 0.5) * 4 / zoom - 0.5
                    var y0 = (py / height - 0.5) * 4 / zoom
                    
                    var x = 0, y = 0, iteration = 0, max_iteration = 50
                    while (x*x + y*y <= 4 && iteration < max_iteration) {
                        var xtemp = x*x - y*y + x0
                        y = 2*x*y + y0
                        x = xtemp
                        iteration++
                    }
                    
                    var index = (py * width + px) * 4
                    var hue = (iteration / max_iteration + root.t * 0.1) % 1
                    var color = Qt.hsva(hue, 0.8, iteration < max_iteration ? 0.8 : 0, 1)
                    data[index] = color.r * 255
                    data[index + 1] = color.g * 255
                    data[index + 2] = color.b * 255
                    data[index + 3] = 255
                }
            }
            ctx.putImageData(imageData, 0, 0)
        }
        
        Timer {
            interval: 100; running: parent.visible; repeat: true
            onTriggered: parent.requestPaint()
        }
    }

    // 16. Geometric Dance - Pulsing polygons
    Item {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.8
        height: width
        visible: visualizationType === 16
        
        Repeater {
            model: 5
            Item {
                anchors.centerIn: parent
                rotation: root.t * (30 + index * 10) + index * 72
                
                Repeater {
                    model: 5
                    Rectangle {
                        property real angle: (index / 5) * Math.PI * 2
                        property real dist: 100 + parent.index * 50
                        
                        width: 30 + root.audioPeak * 20
                        height: width
                        radius: 5
                        color: Qt.hsva((parent.index / 5 + root.t * 0.1) % 1, 0.8, 0.8, 0.7)
                        rotation: root.t * 45
                        
                        x: parent.parent.width/2 + Math.cos(angle) * dist - width/2
                        y: parent.parent.height/2 + Math.sin(angle) * dist - height/2
                    }
                }
            }
        }
    }

    // 17. Audio Bars 3D - Perspective spectrum
    Item {
        anchors.fill: parent
        visible: visualizationType === 17
        
        Repeater {
            model: 32
            Item {
                property real spec: getRealSpectrumValue(index * 2) * root.audioSensitivity
                property real depth: index / 32
                property real scale: 0.3 + depth * 0.7
                
                Rectangle {
                    width: (parent.parent.width / 32) * scale
                    height: Math.max(10, spec * parent.parent.height * 0.7 * scale)
                    color: Qt.hsva(depth, 0.8, 0.6 + spec * 0.4, 0.9)
                    x: index * (parent.parent.width / 32)
                    y: parent.parent.height - height - parent.parent.height * (1 - depth) * 0.3
                    
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        width: parent.width
                        height: parent.width
                        color: Qt.lighter(parent.color, 1.5)
                    }
                }
            }
        }
    }

    // 18. Kaleidoscope - Symmetric patterns
    Item {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        visible: visualizationType === 18
        clip: true
        
        Repeater {
            model: 8
            Item {
                anchors.centerIn: parent
                rotation: index * 45
                
                Repeater {
                    model: 20
                    Rectangle {
                        width: 5 + root.bassLevel * 10
                        height: width
                        radius: width/2
                        color: Qt.hsva((index / 20 + root.t * 0.2) % 1, 0.9, 0.9, 0.7)
                        
                        x: parent.parent.width/2
                        y: parent.parent.height/2 - index * 20 * (1 + root.audioPeak * 0.5)
                        
                        rotation: root.t * (50 + index * 10)
                    }
                }
            }
        }
    }
