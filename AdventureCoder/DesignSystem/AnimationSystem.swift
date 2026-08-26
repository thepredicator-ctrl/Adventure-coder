import SwiftUI

// MARK: - Animation Constants

/// Centralized animation timing and easing for consistent motion language.
public enum AppAnimation {
    public static let fast = Animation.easeInOut(duration: 0.15)
    public static let standard = Animation.easeInOut(duration: 0.25)
    public static let smooth = Animation.spring(response: 0.4, dampingFraction: 0.8)
    public static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.65)
    public static let gentle = Animation.spring(response: 0.6, dampingFraction: 0.85)
    public static let transition = Animation.spring(response: 0.35, dampingFraction: 0.85)
}

// MARK: - Fade In (React Bits: Blur Fade)

/// A view that fades in with an optional blur effect on appear.
public struct FadeIn<Content: View>: View {
    let content: Content
    let delay: Double
    let blur: Bool
    @State private var isVisible = false

    public init(delay: Double = 0, blur: Bool = true, @ViewBuilder content: () -> Content) {
        self.delay = delay
        self.blur = blur
        self.content = content()
    }

    public var body: some View {
        content
            .opacity(isVisible ? 1 : 0)
            .blur(radius: blur && !isVisible ? 8 : 0)
            .offset(y: isVisible ? 0 : 8)
            .onAppear {
                withAnimation(AppAnimation.gentle.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Scale In (React Bits: Scale Fade)

public struct ScaleIn<Content: View>: View {
    let content: Content
    let delay: Double
    @State private var isVisible = false

    public init(delay: Double = 0, @ViewBuilder content: () -> Content) {
        self.delay = delay
        self.content = content()
    }

    public var body: some View {
        content
            .scaleEffect(isVisible ? 1 : 0.85)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(AppAnimation.bouncy.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Slide In (React Bits: Slide Fade)

public struct SlideIn<Content: View>: View {
    let content: Content
    let direction: Edge
    let delay: Double
    @State private var isVisible = false

    public init(from direction: Edge = .leading, delay: Double = 0, @ViewBuilder content: () -> Content) {
        self.direction = direction
        self.delay = delay
        self.content = content()
    }

    public var body: some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(x: isVisible ? 0 : (direction == .leading ? -20 : (direction == .trailing ? 20 : 0)),
                    y: isVisible ? 0 : (direction == .top ? -20 : (direction == .bottom ? 20 : 0)))
            .onAppear {
                withAnimation(AppAnimation.smooth.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Staggered List (React Bits: Stagger)

/// Applies a staggered fade-in animation to each child.
public struct StaggeredContainer<Content: View>: View {
    let content: Content
    let spacing: Double
    @State private var isVisible = false

    public init(spacing: Double = 0.05, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(AppAnimation.smooth) { isVisible = true }
            }
    }
}

// MARK: - Shimmer (React Bits: Shiny Text / Loading)

/// A shimmering loading effect for skeletons and loading states.
public struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1

    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.08),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 1.5)
                    .offset(x: phase * geo.size.width * 1.5)
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            phase = 1
                        }
                    }
                }
            )
            .clipped()
    }
}

extension View {
    public func shimmer() -> some View { modifier(Shimmer()) }
}

// MARK: - Glow Border (React Bits: Glowing Border)

/// A subtle glowing border that can be used on cards and buttons.
public struct GlowBorder: ViewModifier {
    let color: Color
    let radius: CGFloat
    let isActive: Bool

    public func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(
                        color.opacity(isActive ? 0.4 : 0),
                        lineWidth: 1
                    )
                    .shadow(color: color.opacity(isActive ? 0.3 : 0), radius: 8)
                    .animation(AppAnimation.standard, value: isActive)
            )
    }
}

extension View {
    public func glowBorder(color: Color = .white, radius: CGFloat = 10, isActive: Bool = true) -> some View {
        modifier(GlowBorder(color: color, radius: radius, isActive: isActive))
    }
}

// MARK: - Pressable Button (React Bits: Magnetic / Pressable)

/// A button style with press feedback — scales down slightly on press.
public struct PressableButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(AppAnimation.fast, value: configuration.isPressed)
    }
}

// MARK: - Hover Card (React Bits: Card Hover)

/// A card that elevates on hover with a subtle background change.
public struct HoverCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    @State private var isHovered = false

    public init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isHovered ? Color.white.opacity(0.05) : Color.white.opacity(0.02))
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .onHover { isHovered = $0 }
            .animation(AppAnimation.fast, value: isHovered)
    }
}

// MARK: - Typing Indicator (AI Thinking)

/// Animated dots that indicate the AI is thinking/generating.
public struct TypingIndicator: View {
    @State private var animate = false

    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 6, height: 6)
                    .scaleEffect(animate ? 1.3 : 0.7)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
        .onDisappear { animate = false }
    }
}

// MARK: - Animated Checkmark

/// An animated checkmark that springs in on success.
public struct AnimatedCheckmark: View {
    let color: Color
    let size: CGFloat
    @State private var show = false

    public init(color: Color = .green, size: CGFloat = 48) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: size))
            .foregroundColor(color)
            .scaleEffect(show ? 1.0 : 0.3)
            .opacity(show ? 1.0 : 0.0)
            .onAppear {
                withAnimation(AppAnimation.bouncy) { show = true }
            }
    }
}

// MARK: - Loading Skeleton

/// A skeleton placeholder for loading content.
public struct SkeletonRow: View {
    public init() {}
    public var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 32, height: 32)
                .shimmer()
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 120, height: 10)
                    .shimmer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.03))
                    .frame(width: 80, height: 8)
                    .shimmer()
            }
            Spacer()
        }
    }
}

// MARK: - Smooth Transition Modifier

/// Applies a consistent page transition.
public struct SmoothTransition: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.97)).animation(AppAnimation.transition),
                removal: .opacity.animation(.easeIn(duration: 0.15))
            ))
    }
}

extension View {
    public func smoothTransition() -> some View {
        modifier(SmoothTransition())
    }
}

// MARK: - Modal Presentation Modifier

/// Applies a smooth modal presentation with blur backdrop.
public struct SmoothModal: ViewModifier {
    @Binding var isPresented: Bool

    public func body(content: Content) -> some View {
        ZStack {
            if isPresented {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(AppAnimation.standard) { isPresented = false } }
                    .transition(.opacity)

                content
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity).animation(AppAnimation.bouncy),
                        removal: .scale(scale: 0.95).combined(with: .opacity).animation(AppAnimation.fast)
                    ))
            }
        }
        .animation(AppAnimation.standard, value: isPresented)
    }
}

extension View {
    public func smoothModal(isPresented: Binding<Bool>) -> some View {
        modifier(SmoothModal(isPresented: isPresented))
    }
}

// MARK: - Pulsing Status Dot

/// A small dot that pulses to indicate active/connected status.
public struct PulsingDot: View {
    let color: Color
    let size: CGFloat
    @State private var isPulsing = false

    public init(color: Color, size: CGFloat = 8) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.4), lineWidth: 2)
                    .scaleEffect(isPulsing ? 2.5 : 1)
                    .opacity(isPulsing ? 0 : 0.6)
                    .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
            )
            .onAppear { isPulsing = true }
    }
}
