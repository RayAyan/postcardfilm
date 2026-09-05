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
                Text(Brand.settingsSubtext)
                    .font(AppType.caption(12))
                    .appChromeText()
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(
                        EdgeInsets(top: 2, leading: AppTheme.pageGutter, bottom: 4, trailing: AppTheme.pageGutter)
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                CaptionModeGrid(
                    mode: Binding(
                        get: { settingsStore.settings.captionMode },
                        set: { value in settingsStore.update { $0.captionMode = value } }
                    ),
                    onSelectCustom: {
                        draftCustom = settingsStore.settings.customDefault
                        showCustomPrompt = true
                    }
                )
                if settingsStore.settings.captionMode == .custom,
                   !settingsStore.settings.customDefault.isEmpty
                {
                    Text(settingsStore.settings.customDefault)
                        .font(AppType.body(15))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(
                            EdgeInsets(
                                top: 8,
                                leading: AppTheme.pageGutter,
                                bottom: 8,
                                trailing: AppTheme.pageGutter
                            )
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .onTapGesture {
                            draftCustom = settingsStore.settings.customDefault
                            showCustomPrompt = true
                        }
                }
            } header: {
                PrintSectionHeader(title: "strip text")
            }

            if settingsStore.settings.captionMode == .date {
                Section {
                    DateFormatGrid(
                        format: binding(\.dateFormat),
                        letterCase: settingsStore.settings.dateCase
                    )
                } header: {
                    PrintSectionHeader(title: "date format")
                }
            }

            PrintTextStyleControls(
                font: binding(\.captionFont),
                fontSize: binding(\.captionFontSize),
                letterCase: binding(\.dateCase),
                highlight: binding(\.captionHighlight),
                showHighlight: settingsStore.settings.captionMode != .blank
            )

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
            .listRowInsets(
                EdgeInsets(top: 16, leading: AppTheme.pageGutter, bottom: 8, trailing: AppTheme.pageGutter)
            )
        }
        .listStyle(.plain)
        .listSectionSpacing(8)
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
                onDone: {
                    settingsStore.update {
                        $0.captionMode = .custom
                        $0.customDefault = Caption.truncateCaption(draftCustom)
                    }
                    showCustomPrompt = false
                }
            )
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { settingsStore.settings[keyPath: keyPath] },
            set: { value in settingsStore.update { $0[keyPath: keyPath] = value } }
        )
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
}
