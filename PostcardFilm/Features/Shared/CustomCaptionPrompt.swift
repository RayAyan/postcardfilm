import SwiftUI

/// Shared custom-caption editor with visible character limit.
/// Edits apply through the binding; only a done button dismisses.
struct CustomCaptionPrompt: View {
    @Binding var text: String
    var title: String = "custom text"
    var placeholder: String = "write something"
    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField(placeholder, text: $text)
                    .font(AppType.body(17))
                    .foregroundStyle(AppTheme.textPrimary)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .padding(12)
                    .background(AppTheme.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onChange(of: text) { _, newValue in
                        if newValue.count > Caption.maxLength {
                            text = String(newValue.prefix(Caption.maxLength))
                        }
                    }

                Text("\(text.count)/\(Caption.maxLength)")
                    .font(AppType.caption(13, weight: .medium).monospacedDigit())
                    .appChromeText()
                    .foregroundStyle(
                        text.count >= Caption.maxLength
                            ? AppTheme.destructive
                            : AppTheme.textSecondary
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Spacer()
            }
            .padding(AppTheme.pageGutter)
            .background(AppTheme.surface.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done", action: onDone)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
