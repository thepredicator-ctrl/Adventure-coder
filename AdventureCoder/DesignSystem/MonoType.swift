import SwiftUI

/// Typography scale for Adventure Coder.
///
/// Uses Apple's system typography for UI text and SF Mono for code, preserving
/// the calm, professional aesthetic of the workspace.
public enum MonoType {
    public static let uiFont = Font.system(.body, design: .default)

    // MARK: - UI scale
    public static let largeTitle = Font.system(size: 28, weight: .semibold, design: .default)
    public static let title = Font.system(size: 20, weight: .semibold, design: .default)
    public static let title2 = Font.system(size: 17, weight: .semibold, design: .default)
    public static let headline = Font.system(size: 15, weight: .semibold, design: .default)
    public static let body = Font.system(size: 14, weight: .regular, design: .default)
    public static let callout = Font.system(size: 13, weight: .regular, design: .default)
    public static let subheadline = Font.system(size: 13, weight: .regular, design: .default)
    public static let footnote = Font.system(size: 12, weight: .regular, design: .default)
    public static let caption = Font.system(size: 11, weight: .regular, design: .default)
    public static let caption2 = Font.system(size: 10, weight: .regular, design: .default)
    public static let microLabel = Font.system(size: 10, weight: .semibold, design: .default)

    // MARK: - Code scale
    public static func code(_ size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }

    public static let codeBody = code(13)
    public static let codeSmall = code(12)
    public static let codeLarge = code(15)
    public static let lineNumber = code(11)

    // MARK: - UIKit bridges (for UITextView-based editor)
    public static func uiCodeFont(_ size: CGFloat = 13, weight: UIFont.Weight = .regular) -> UIFont {
        UIFont.monospacedSystemFont(ofSize: size, weight: weight)
    }
    public static func uiUIFont(_ size: CGFloat = 14, weight: UIFont.Weight = .regular) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: weight)
    }
}

public extension View {
    func monoText(_ style: Font, color: Color = MonoColor.primaryText) -> some View {
        self.font(style).foregroundColor(color)
    }
}
