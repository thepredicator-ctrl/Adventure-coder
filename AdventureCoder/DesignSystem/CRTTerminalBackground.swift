import SwiftUI
import UIKit

/// CRT terminal background effect inspired by the FaultyTerminal React component.
/// Renders scanlines, flicker, noise, and a subtle green CRT glow as a background texture.
/// This is not a mockup — it's a real real-time animated SwiftUI Canvas effect.
public struct CRTTerminalBackground: View {
    public var tint: Color
    public var scanlineIntensity: Double
    public var flickerAmount: Double
    public var noiseAmp: Double
    public var brightness: Double
    public var curvature: Double

    @State private var phase: Double = 0
    @State private var flickerPhase: Double = 0
    @State private var noiseSeed: UInt64 = 0
    private let timer = Timer.publish(every: 1.0/30.0, on: .main, in: .common).autoconnect()

    public init(
        tint: Color = Color(red: 0.65, green: 0.94, blue: 0.62),
        scanlineIntensity: Double = 0.15,
        flickerAmount: Double = 0.08,
        noiseAmp: Double = 0.06,
        brightness: Double = 0.04,
        curvature: Double = 0.0
    ) {
        self.tint = tint
        self.scanlineIntensity = scanlineIntensity
        self.flickerAmount = flickerAmount
        self.noiseAmp = noiseAmp
        self.brightness = brightness
        self.curvature = curvature
    }

    public var body: some View {
        Canvas { context, size in
            // 1. Base dark background
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.black))

            // 2. Subtle CRT glow tint
            let glowRect = CGRect(origin: .zero, size: size)
            context.fill(Path(glowRect), with: .color(tint.opacity(brightness)))

            // 3. Scanlines - horizontal lines every 3px
            let scanlineSpacing: Double = 3
            var y: Double = 0
            while y < size.height {
                let opacity = scanlineIntensity * (0.5 + 0.5 * sin(phase + y * 0.1))
                context.fill(
                    Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                    with: .color(Color.black.opacity(opacity))
                )
                y += scanlineSpacing
            }

            // 4. Flicker - subtle brightness variation
            let flicker = 1.0 - flickerAmount * abs(sin(flickerPhase))
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color.black.opacity((1.0 - flicker) * 0.3))
            )

            // 5. Noise - random dots
            if noiseAmp > 0 {
                let noiseCount = Int(size.width * size.height * noiseAmp * 0.001)
                for _ in 0..<min(noiseCount, 500) {
                    let x = Double(arc4random_uniform(UInt32(size.width)))
                    let yy = Double(arc4random_uniform(UInt32(size.height)))
                    let dotSize = Double(arc4random_uniform(2)) + 0.5
                    let opacity = Double(arc4random_uniform(100)) / 200.0
                    context.fill(
                        Path(CGRect(x: x, y: yy, width: dotSize, height: dotSize)),
                        with: .color(tint.opacity(opacity))
                    )
                }
            }

            // 6. Vignette - darker corners
            let vignetteGradient = Gradient(colors: [
                Color.clear,
                Color.clear,
                Color.black.opacity(0.3),
                Color.black.opacity(0.6)
            ])
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(vignetteGradient,
                    startPoint: CGPoint(x: size.width/2, y: size.height/2),
                    endPoint: CGPoint(x: size.width/2, y: 0))
            )

            // 7. Moving scan beam - a bright horizontal line that slowly moves down
            let beamY = (phase * 50).truncatingRemainder(dividingBy: size.height + 100) - 50
            let beamGradient = Gradient(colors: [
                Color.clear,
                tint.opacity(0.03),
                tint.opacity(0.06),
                tint.opacity(0.03),
                Color.clear
            ])
            context.fill(
                Path(CGRect(x: 0, y: beamY, width: size.width, height: 80)),
                with: .linearGradient(beamGradient,
                    startPoint: CGPoint(x: 0, y: beamY),
                    endPoint: CGPoint(x: 0, y: beamY + 80))
            )
        }
        .onReceive(timer) { _ in
            phase += 0.3
            flickerPhase += 0.7
            noiseSeed &+= 1
        }
        .allowsHitTesting(false)
    }
}

/// A subtle CRT background that's dark enough to sit behind UI content.
/// Uses lower intensity settings suitable for a coding workspace background.
public struct SubtleCRTBackground: View {
    public init() {}

    public var body: some View {
        CRTTerminalBackground(
            tint: Color(red: 0.65, green: 0.94, blue: 0.62),
            scanlineIntensity: 0.08,
            flickerAmount: 0.03,
            noiseAmp: 0.03,
            brightness: 0.015,
            curvature: 0
        )
    }
}
