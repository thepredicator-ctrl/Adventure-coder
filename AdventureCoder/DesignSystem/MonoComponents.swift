import SwiftUI

/// Reusable, monochrome SwiftUI components.
public struct MonoComponents {
    public static func PrimaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(MonoType.headline)
                .foregroundColor(MonoColor.snow)
                .padding(.horizontal, MonoSpace.lg)
                .padding(.vertical, MonoSpace.md)
                .frame(maxWidth: .infinity)
                .background(MonoColor.nearBlack)
                .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))
        }
        .buttonStyle(.plain)
    }

    public static func SecondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(MonoType.headline)
                .foregroundColor(MonoColor.primaryText)
                .padding(.horizontal, MonoSpace.lg)
                .padding(.vertical, MonoSpace.md)
                .frame(maxWidth: .infinity)
                .background(MonoColor.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: MonoSpace.cornerRadius)
                        .stroke(MonoColor.hairline, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: MonoSpace.cornerRadius))
        }
        .buttonStyle(.plain)
    }
}

/// A monochrome status pill that uses color only to communicate state.
public struct StatusPill: View {
    public enum Kind {
        case idle, working, success, warning, error, info

        var label: String {
            switch self {
            case .idle: return "Idle"
            case .working: return "Working"
            case .success: return "Success"
            case .warning: return "Warning"
            case .error: return "Failed"
            case .info: return "Info"
            }
        }
        var color: Color {
            switch self {
            case .idle: return MonoColor.steel
            case .working: return MonoColor.warning
            case .success: return MonoColor.success
            case .warning: return MonoColor.warning
            case .error: return MonoColor.error
            case .info: return MonoColor.steel
            }
        }
        var background: Color {
            switch self {
            case .idle: return MonoColor.cloud
            case .working: return MonoColor.warningBg
            case .success: return MonoColor.successBg
            case .warning: return MonoColor.warningBg
            case .error: return MonoColor.errorBg
            case .info: return MonoColor.cloud
            }
        }
    }

    let kind: Kind
    let text: String?
    public init(_ kind: Kind, text: String? = nil) {
        self.kind = kind
        self.text = text
    }
    public var body: some View {
        HStack(spacing: MonoSpace.xs) {
            Circle()
                .fill(kind.color)
                .frame(width: 6, height: 6)
            Text(text ?? kind.label)
                .font(MonoType.caption.weight(.medium))
                .foregroundColor(kind.color)
        }
        .padding(.horizontal, MonoSpace.sm)
        .padding(.vertical, MonoSpace.xxs + 1)
        .background(kind.background)
        .clipShape(Capsule())
    }
}

/// A minimal section header used to label groups in sidebars and panels.
public struct SectionHeader: View {
    let title: String
    var accessory: AnyView? = nil
    public init(_ title: String, accessory: AnyView? = nil) {
        self.title = title
        self.accessory = accessory
    }
    public var body: some View {
        HStack {
            Text(title.uppercased())
                .font(MonoType.microLabel)
                .tracking(0.8)
                .foregroundColor(MonoColor.tertiaryText)
            Spacer()
            if let accessory = accessory { accessory }
        }
        .padding(.horizontal, MonoSpace.md)
        .padding(.vertical, MonoSpace.sm)
    }
}

/// A thin separator that adapts to color scheme.
public struct HairlineDivider: View {
    var vertical: Bool = false
    public init(vertical: Bool = false) { self.vertical = vertical }
    public var body: some View {
        if vertical {
            Rectangle()
                .fill(MonoColor.hairline)
                .frame(width: 1)
        } else {
            Rectangle()
                .fill(MonoColor.hairline)
                .frame(height: 1)
        }
    }
}

/// A selectable row used in file trees, agent lists, etc.
public struct SelectableRow<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    let content: Content
    public init(isSelected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.action = action
        self.content = content()
    }
    public var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, MonoSpace.md)
                .padding(.vertical, MonoSpace.xs + 1)
                .background(isSelected ? MonoColor.cloud : Color.clear)
                .overlay(alignment: .leading) {
                    if isSelected {
                        Rectangle()
                            .fill(MonoColor.nearBlack)
                            .frame(width: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

/// Empty-state view used when a pane has nothing to display.
public struct EmptyState: View {
    let title: String
    let message: String
    var systemImage: String = "tray"
    public init(title: String, message: String, systemImage: String = "tray") {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }
    public var body: some View {
        VStack(spacing: MonoSpace.md) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .light))
                .foregroundColor(MonoColor.tertiaryText)
            Text(title)
                .font(MonoType.headline)
                .foregroundColor(MonoColor.primaryText)
            Text(message)
                .font(MonoType.footnote)
                .foregroundColor(MonoColor.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .padding(MonoSpace.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
