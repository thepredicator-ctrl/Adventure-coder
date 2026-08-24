import SwiftUI

/// Root view that adapts between iPad and iPhone layouts based on horizontal size class.
public struct AdaptiveLayout: View {
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize

    public init() {}

    public var body: some View {
        if hSize == .regular && vSize == .regular {
            // iPad / Mac in standard window
            WorkspaceView()
        } else if hSize == .regular {
            // iPad in split view (wide but short)
            WorkspaceView()
        } else {
            // iPhone / iPad in slide-over
            iPhoneLayout()
        }
    }
}
