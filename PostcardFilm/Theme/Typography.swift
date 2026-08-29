import SwiftUI

/// App UI typography — always serif. Print strip fonts stay on `CaptionFont`.
enum AppType {
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func body(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func caption(_ size: CGFloat = 12, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func micro(_ size: CGFloat = 10, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

extension View {
    /// Lowercase chrome for UI labels. Skip on text fields / strip burns.
    func appChromeText() -> some View {
        self
            .textCase(.lowercase)
            .tracking(0.4)
    }
}
