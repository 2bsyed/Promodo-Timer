import SwiftUI
import AppKit
import AVFoundation

// Low-latency procedural sound synthesizer for the "kit-kit" mechanical click
class SoundManager {
    static let shared = SoundManager()
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var clickBuffer: AVAudioPCMBuffer?

    init() {
        setupClickSound()
    }

    private func setupClickSound() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)

        // Generate a mechanical "tick" buffer (very short burst of noise + decaying sine wave)
        let sampleRate = 44100.0
        let duration = 0.005 // 5 milliseconds - very short and clicky!
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        let channelData = buffer.floatChannelData![0]
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            // Decaying sine wave at 2200Hz for a crisp mechanical click
            let sine = sin(2.0 * .pi * 2200.0 * t)
            // Add a little bit of white noise
            let noise = Double.random(in: -1.0...1.0)
            let envelope = exp(-t * 1500.0) // very fast decay
            channelData[frame] = Float((sine * 0.5 + noise * 0.5) * envelope * 0.05) // quiet, subtle click!
        }

        self.audioEngine = engine
        self.playerNode = player
        self.clickBuffer = buffer

        do {
            try engine.start()
            player.play()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    func playClick() {
        guard let playerNode = playerNode, let clickBuffer = clickBuffer, let audioEngine = audioEngine else { return }
        if !audioEngine.isRunning {
            try? audioEngine.start()
        }
        playerNode.scheduleBuffer(clickBuffer, at: nil, options: [], completionHandler: nil)
    }
}

// AppKit view to intercept 2-finger scroll/swipe gestures on trackpad and tap clicks
struct ScrollGestureView: NSViewRepresentable {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var tickSpacing: CGFloat
    var onIncrement: (Double) -> Void
    var onTapTick: (Double) -> Void

    func makeNSView(context: Context) -> ScrollInterceptingNSView {
        let view = ScrollInterceptingNSView()
        view.onScroll = { deltaX in
            // deltaX is positive when swiping right (scrolls left)
            // We want swiping left (negative deltaX) to increase value
            let sensitivity: Double = 0.04 // slightly lower for finer control
            let change = Double(-deltaX) * sensitivity
            let rawValue = value + change
            // Completely smooth: no rounding to steps during sliding!
            let clamped = min(max(rawValue, range.lowerBound), range.upperBound)
            if clamped != value {
                value = clamped
                onIncrement(clamped)
            }
        }
        view.onTap = { clickX in
            onTapTick(clickX)
        }
        return view
    }


    func updateNSView(_ nsView: ScrollInterceptingNSView, context: Context) {}
}

class ScrollInterceptingNSView: NSView {
    var onScroll: ((CGFloat) -> Void)?
    var onTap: ((CGFloat) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        let deltaX = event.hasPreciseScrollingDeltas ? event.scrollingDeltaX : event.deltaX * 8
        if deltaX != 0 {
            onScroll?(deltaX)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let localPoint = self.convert(event.locationInWindow, from: nil)
        onTap?(localPoint.x)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if self.bounds.contains(point) {
            return self
        }
        return nil
    }
}


struct RulerTicksView: View {
    let value: Double
    let range: ClosedRange<Double>
    let tickSpacing: CGFloat
    let canvasHeight: CGFloat
    let tickColor: Color
    let unselectedTickColor: Color
    let labelColor: Color
    let unselectedLabelColor: Color
    let totalWidth: CGFloat

    var body: some View {
        Canvas { context, size in
            let centerX = size.width / 2
            let baseY: CGFloat = 46
            let tickHeight: CGFloat = 30

            // Calculate visible tick range to optimize rendering
            let halfVisibleTicks = Int(size.width / (2 * tickSpacing)) + 5
            let currentValInt = Int(value)
            let minTick = max(Int(range.lowerBound), currentValInt - halfVisibleTicks)
            let maxTick = min(Int(range.upperBound), currentValInt + halfVisibleTicks)

            for i in minTick...maxTick {
                let isSelected = Double(i) <= value
                let x = centerX + CGFloat(Double(i) - value) * tickSpacing

                // 1. Draw Tick mark
                var path = Path()
                path.move(to: CGPoint(x: x, y: baseY - tickHeight))
                path.addLine(to: CGPoint(x: x, y: baseY))

                context.stroke(
                    path,
                    with: .color(isSelected ? tickColor : unselectedTickColor),
                    lineWidth: 2.2
                )

                // Ticks category logic:
                // Under 60m: major ticks every 5m.
                // Over 60m: major ticks every 15m (60, 75, 90, 105, 120, 135, 150, 165, 180) to avoid crowding.
                let isMajor: Bool
                if i < 60 {
                    isMajor = i % 5 == 0
                } else {
                    isMajor = i % 15 == 0
                }

                // 2. Draw Label (if major tick)
                if isMajor {
                    let labelString = formatLabel(for: i)
                    let text = Text(labelString)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(isSelected ? labelColor : unselectedLabelColor)
                    
                    let resolved = context.resolve(text)
                    let textSize = resolved.measure(in: size)
                    // Center horizontally, position near the top of the tick
                    context.draw(
                        resolved,
                        at: CGPoint(x: x, y: baseY - tickHeight - textSize.height / 2 - 2),
                        anchor: .center
                    )
                }
            }
        }
    }

    private func formatLabel(for minutes: Int) -> String {
        if minutes == 0 { return "0" }
        if minutes < 60 {
            return "\(minutes)"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours)H"
            } else {
                return "\(hours)H\(mins)"
            }
        }
    }
}

struct RulerSliderView: View {
    @Binding var value: Double // minutes
    var range: ClosedRange<Double> = 0...180
    var step: Double = 1

    private let tickSpacing: CGFloat = 8.0 // pixels per minute
    private let canvasHeight: CGFloat = 60
    private let tickColor = Color(red: 241/255, green: 152/255, blue: 70/255)
    private let unselectedTickColor = Color(red: 241/255, green: 152/255, blue: 70/255).opacity(0.3)
    private let labelColor = Color(red: 241/255, green: 152/255, blue: 70/255).opacity(0.9)
    private let unselectedLabelColor = Color(red: 241/255, green: 152/255, blue: 70/255).opacity(0.45)


    @State private var lastHapticValue: Int = -1

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let centerX = totalWidth / 2
            let baseY: CGFloat = 46

            ZStack {
                // Sharp Center Dial
                RulerTicksView(
                    value: value,
                    range: range,
                    tickSpacing: tickSpacing,
                    canvasHeight: canvasHeight,
                    tickColor: tickColor,
                    unselectedTickColor: unselectedTickColor,
                    labelColor: labelColor,
                    unselectedLabelColor: unselectedLabelColor,
                    totalWidth: totalWidth
                )
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .clear, location: 0.08),
                            .init(color: .black, location: 0.32),
                            .init(color: .black, location: 0.68),
                            .init(color: .clear, location: 0.92),
                            .init(color: .clear, location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

                // Blurred Edge Dial (creates cylinder depth)
                RulerTicksView(
                    value: value,
                    range: range,
                    tickSpacing: tickSpacing,
                    canvasHeight: canvasHeight,
                    tickColor: tickColor,
                    unselectedTickColor: unselectedTickColor,
                    labelColor: labelColor,
                    unselectedLabelColor: unselectedLabelColor,
                    totalWidth: totalWidth
                )
                .blur(radius: 4.8)
                .opacity(0.85)
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .black, location: 0.0),
                            .init(color: .black, location: 0.12),
                            .init(color: .clear, location: 0.34),
                            .init(color: .clear, location: 0.66),
                            .init(color: .black, location: 0.88),
                            .init(color: .black, location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

                // Vignette shadow overlay to darken the far left and right edges
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.black.opacity(0.60), location: 0.0),
                        .init(color: Color.black.opacity(0.40), location: 0.08),
                        .init(color: Color.black.opacity(0.0), location: 0.28),
                        .init(color: Color.black.opacity(0.0), location: 0.72),
                        .init(color: Color.black.opacity(0.40), location: 0.92),
                        .init(color: Color.black.opacity(0.60), location: 1.0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .allowsHitTesting(false)

                // 3. Draw fixed center triangle indicator pointing up (always sharp!)
                Canvas { context, size in
                    var trianglePath = Path()
                    trianglePath.move(to: CGPoint(x: centerX, y: baseY + 3))
                    trianglePath.addLine(to: CGPoint(x: centerX + 6, y: baseY + 11))
                    trianglePath.addLine(to: CGPoint(x: centerX - 6, y: baseY + 11))
                    trianglePath.closeSubpath()

                    context.fill(
                        trianglePath,
                        with: .color(tickColor)
                    )
                }
                .frame(height: canvasHeight)

                // Overlay the transparent scroll interceptor
                ScrollGestureView(
                    value: $value,
                    range: range,
                    step: step,
                    tickSpacing: tickSpacing,
                    onIncrement: { newValue in
                        let currentInt = Int(newValue)
                        if currentInt != lastHapticValue {
                            lastHapticValue = currentInt
                            // Play both tactile mechanical sound and system trackpad haptics
                            SoundManager.shared.playClick()
                            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                        }
                    },
                    onTapTick: { clickX in
                        let deltaX = clickX - centerX
                        let clickedValue = value + Double(deltaX / tickSpacing)
                        let nearestMultipleOf5 = (clickedValue / 5.0).rounded() * 5.0
                        if abs(clickedValue - nearestMultipleOf5) < 2.0 {
                            let clamped = min(max(nearestMultipleOf5, range.lowerBound), range.upperBound)
                            if value != clamped {
                                value = clamped
                                SoundManager.shared.playClick()
                                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
                            }
                        }
                    }
                )
            }
        }
        .frame(height: canvasHeight)
    }
}




struct RulerSliderView_Previews: PreviewProvider {
    static var previews: some View {
        RulerSliderView(value: .constant(15))
            .padding()
            .background(Color.black)
    }
}
