import SwiftUI

/// Monochrome design tokens for Adventure Coder.
///
/// Design philosophy:
/// - Pure black / white as the dominant axis
/// - Grays for hierarchy and chrome
/// - Color reserved exclusively for communicating state (success / warning / error / active)
/// - No neon, no gradients, no decorative color
public enum MonoColor {
    // MARK: - Primary scale
    public static let ink = Color.black                  // #000000 — primary text on light, ink on white
    public static let nearBlack = Color(red: 17/255, green: 17/255, blue: 23/255)   // #111117
    public static let graphite = Color(red: 55/255, green: 55/255, blue: 60/255)    // #37373C
    public static let steel = Color(red: 107/255, green: 107/255, blue: 114/255)    // #6B6B72
    public static let mist = Color(red: 156/255, green: 156/255, blue: 163/255)     // #9C9CA3
    public static let silver = Color(red: 209/255, green: 209/255, blue: 214/255)   // #D1D1D6
    public static let fog = Color(red: 229/255, green: 229/255, blue: 234/255)      // #E5E5EA
    public static let cloud = Color(red: 243/255, green: 243/255, blue: 246/255)    // #F3F3F6
    public static let paper = Color(red: 249/255, green: 249/255, blue: 251/255)    // #F9F9FB
    public static let snow = Color.white

    // MARK: - Backgrounds
    public static var canvas: Color {
        Color(uiColor: .systemBackground)
    }
    public static var panel: Color {
        Color(uiColor: .secondarySystemBackground)
    }
    public static var inset: Color {
        Color(uiColor: .tertiarySystemBackground)
    }
    public static var elevated: Color {
        Color(uiColor: .systemBackground)
    }

    // MARK: - Text
    public static var primaryText: Color {
        Color(uiColor: .label)
    }
    public static var secondaryText: Color {
        Color(uiColor: .secondaryLabel)
    }
    public static var tertiaryText: Color {
        Color(uiColor: .tertiaryLabel)
    }
    public static var quaternaryText: Color {
        Color(uiColor: .quaternaryLabel)
    }

    // MARK: - Separators
    public static var hairline: Color {
        Color(uiColor: .separator)
    }
    public static var opaqueHairline: Color {
        Color(uiColor: .opaqueSeparator)
    }

    // MARK: - State colors (used ONLY to communicate state)
    public static let success = Color(red: 16/255, green: 122/255, blue: 75/255)    // muted green
    public static let successBg = Color(red: 220/255, green: 240/255, blue: 226/255)
    public static let warning = Color(red: 161/255, green: 98/255, blue: 7/255)     // muted amber
    public static let warningBg = Color(red: 252/255, green: 237/255, blue: 205/255)
    public static let error = Color(red: 190/255, green: 52/255, blue: 52/255)      // muted red
    public static let errorBg = Color(red: 248/255, green: 222/255, blue: 222/255)
    public static let active = Color(red: 30/255, green: 95/255, blue: 165/255)     // muted blue, used for active selection only

    // MARK: - Code syntax (monochrome leaning — no neon)
    public enum Code {
        public static let plain = Color(red: 30/255, green: 30/255, blue: 36/255)
        public static let keyword = Color(red: 110/255, green: 60/255, blue: 0/255)    // dark amber
        public static let type = Color(red: 30/255, green: 60/255, blue: 110/255)      // dark blue
        public static let string = Color(red: 30/255, green: 90/255, blue: 50/255)     // dark green
        public static let comment = Color(red: 110/255, green: 110/255, blue: 120/255) // gray
        public static let number = Color(red: 90/255, green: 50/255, blue: 110/255)    // muted purple
        public static let attribute = Color(red: 90/255, green: 90/255, blue: 100/255) // gray
    }
}

public extension Color {
    /// Returns a color suited to the current color scheme by picking from a light/dark pair.
    static func adaptive(light: Color, dark: Color) -> Color {
        UITraitCollection.current.userInterfaceStyle == .dark ? dark : light
    }
}
