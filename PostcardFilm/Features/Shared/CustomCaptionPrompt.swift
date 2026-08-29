import SwiftUI

/// Shared custom-caption editor with visible character limit.
struct CustomCaptionPrompt: View {
    @Binding var text: String
    var title: String = "custom text"
    var placeholder: String = "write something"
    var onCancel: () -> Void
    var onSave: () -> Void

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
            .padding(16)
            .background(AppTheme.surface.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save", action: onSave)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
