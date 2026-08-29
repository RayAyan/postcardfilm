import SwiftUI

struct Wordmark: View {
    var body: some View {
        Text(Brand.wordmark)
            .font(AppType.display(18))
            .tracking(0.6)
            .foregroundStyle(AppTheme.textPrimary)
            .accessibilityLabel(Brand.name)
    }
}
