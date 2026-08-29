import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var showCustomPrompt = false
    @State private var draftCustom = ""
    @State private var creditTapCount = 0
    @State private var creditTapResetTask: Task<Void, Never>?

    var body: some View {
        List {
            Section {
                ForEach(CaptionMode.allCases) { mode in
                    checkRow(
                        title: mode.label,
                        selected: settingsStore.settings.captionMode == mode
                    ) {
                        if mode == .custom {
                            draftCustom = settingsStore.settings.customDefault
                            showCustomPrompt = true
                        } else {
                            settingsStore.update { $0.captionMode = mode }
                        }
                    }
                }
                if settingsStore.settings.captionMode == .custom,
                   !settingsStore.settings.customDefault.isEmpty
                {
                    Text(settingsStore.settings.customDefault)
                        .font(AppType.body(15))
                        .foregroundStyle(AppTheme.textSecondary)
                        .onTapGesture {
                            draftCustom = settingsStore.settings.customDefault
                            showCustomPrompt = true
                        }
                }
            } header: {
                Text("film front caption")
                    .font(AppType.caption(12))
                    .appChromeText()
            }

            Section {
                ForEach(CaptionFont.allCases) { font in
                    checkRow(
                        title: font.label,
                        selected: settingsStore.settings.captionFont == font,
                        font: Font(font.previewFont())
                    ) {
                        settingsStore.update { $0.captionFont = font }
                    }
                }
            } header: {
                Text("font")
                    .font(AppType.caption(12))
                    .appChromeText()
            }

            Section {
                ForEach(DateFormatOption.allCases) { format in
                    let sample = Caption.formatDate(
                        Date(),
                        format: format,
                        letterCase: settingsStore.settings.dateCase
                    )
                    checkRow(
                        title: sample,
                        selected: settingsStore.settings.dateFormat == format
                    ) {
                        settingsStore.update { $0.dateFormat = format }
                    }
                }
            } header: {
                Text("date format")
                    .font(AppType.caption(12))
                    .appChromeText()
            }

            Section {
                ForEach(DateCaseStyle.allCases) { style in
                    checkRow(
                        title: style.apply(style.label),
                        selected: settingsStore.settings.dateCase == style,
                        preserveCase: true
                    ) {
                        settingsStore.update { $0.dateCase = style }
                    }
                }
            } header: {
                Text("date case")
                    .font(AppType.caption(12))
                    .appChromeText()
            }

            VStack(spacing: 6) {
                Text(AppVersion.label)
                    .font(AppType.caption(12))
                    .appChromeText()
                    .foregroundStyle(AppTheme.textSecondary)
                Text(Brand.credit)
                    .font(AppType.caption(12))
                    .appChromeText()
                    .foregroundStyle(AppTheme.textSecondary)
                    .onTapGesture { handleCreditTap() }
                    .accessibilityHint("Tap three times to email the maker")
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .padding(.top, 8)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.surface.ignoresSafeArea())
        .navigationTitle("settings")
        .navigationBarTitleDisplayMode(.large)
        .onDisappear { creditTapResetTask?.cancel() }
        .sheet(isPresented: $showCustomPrompt) {
            CustomCaptionPrompt(
                text: $draftCustom,
                title: "custom text",
                placeholder: "default custom text",
                onCancel: { showCustomPrompt = false },
                onSave: {
                    settingsStore.update {
                        $0.captionMode = .custom
                        $0.customDefault = Caption.truncateCaption(draftCustom)
                    }
                    showCustomPrompt = false
                }
            )
        }
    }

    private func handleCreditTap() {
        creditTapResetTask?.cancel()
        creditTapCount += 1
        if creditTapCount >= 3 {
            creditTapCount = 0
            if let url = URL(string: "mailto:mailayanray@gmail.com") {
                UIApplication.shared.open(url)
            }
            return
        }
        creditTapResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            creditTapCount = 0
        }
    }

    private func checkRow(
        title: String,
        selected: Bool,
        font: Font? = nil,
        preserveCase: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(font ?? AppType.body(17))
                    .textCase(preserveCase ? nil : .lowercase)
                    .tracking(0.4)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(AppTheme.textPrimary)
                        .fontWeight(.semibold)
                }
            }
            .frame(minHeight: AppTheme.hitTarget)
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
