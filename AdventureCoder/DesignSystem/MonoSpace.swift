import SwiftUI

/// Spacing and layout tokens used throughout the workspace.
public enum MonoSpace {
    public static let none: CGFloat = 0
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 48

    public static let cornerRadiusSm: CGFloat = 4
    public static let cornerRadius: CGFloat = 6
    public static let cornerRadiusLg: CGFloat = 10
    public static let cornerRadiusXl: CGFloat = 14

    public static let panelMin: CGFloat = 220
    public static let sidebarDefault: CGFloat = 240
    public static let chatDefault: CGFloat = 360
    public static let agentsDefault: CGFloat = 280
    public static let terminalDefault: CGFloat = 240
    public static let editorMin: CGFloat = 400

    public static let rowHeight: CGFloat = 28
    public static let tabBarHeight: CGFloat = 36
    public static let statusBarHeight: CGFloat = 24
}

public extension CGFloat {
    static let monoXXS = MonoSpace.xxs
    static let monoXS = MonoSpace.xs
    static let monoSM = MonoSpace.sm
    static let monoMD = MonoSpace.md
    static let monoLG = MonoSpace.lg
    static let monoXL = MonoSpace.xl
}
