import SwiftUI

/// Centered destructive confirm used by Process (one print) and Gallery (one or many).
struct DeleteConfirmModal: View {
    var message: String
    var onDelete: () -> Void
    var onGoBack: () -> Void

    var body: some View {
        ZStack {
            AppTheme.overlay
                .ignoresSafeArea()
                .onTapGesture(perform: onGoBack)
                .accessibilityHidden(true)

            VStack(spacing: 20) {
                Text(message)
                    .font(AppType.body(17, weight: .medium))
                    .appChromeText()
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    Button(action: onDelete) {
                        Text(Brand.deleteAction)
                            .font(AppType.body(17, weight: .semibold))
                            .appChromeText()
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: AppTheme.hitTarget)
                            .background(AppTheme.destructive)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Brand.deleteAction)

                    Button(action: onGoBack) {
                        Text(Brand.deleteGoBack)
                            .font(AppType.body(17, weight: .medium))
                            .appChromeText()
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: AppTheme.hitTarget)
                            .background(AppTheme.surfaceRaised)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(AppTheme.hairline, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Brand.deleteGoBack)
                }
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(AppTheme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppTheme.hairline, lineWidth: 1)
            )
            .padding(.horizontal, 28)
            .accessibilityAddTraits(.isModal)
        }
    }
}

extension View {
    /// Dimmed centered delete confirm. Prefer this over `.confirmationDialog`.
    func deleteConfirmModal(
        isPresented: Binding<Bool>,
        message: String,
        onDelete: @escaping () -> Void
    ) -> some View {
        overlay {
            if isPresented.wrappedValue {
                DeleteConfirmModal(
                    message: message,
                    onDelete: {
                        isPresented.wrappedValue = false
                        onDelete()
                    },
                    onGoBack: { isPresented.wrappedValue = false }
                )
                .transition(.opacity)
                .zIndex(1000)
            }
        }
        .animation(.easeOut(duration: 0.18), value: isPresented.wrappedValue)
    }
}
