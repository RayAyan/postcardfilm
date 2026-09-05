import SwiftUI

// MARK: - Chip primitive

/// Compact selectable box used by all print-text option grids.
struct PrintChoiceChip: View {
    var title: String
    var selected: Bool
    var titleFont: Font = AppType.body(14, weight: .medium)
    var preserveCase: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(titleFont)
                .textCase(preserveCase ? nil : .lowercase)
                .tracking(0.3)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .foregroundStyle(selected ? AppTheme.accentText : AppTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: AppTheme.hitTarget)
                .padding(.horizontal, 6)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected ? AppTheme.accentFill : AppTheme.surfaceRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    selected ? AppTheme.accentFill : AppTheme.hairline.opacity(0.9),
                                    lineWidth: 1
                                )
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// Equal-width row of choice chips.
struct PrintChoiceGrid<Item: Identifiable>: View {
    var items: [Item]
    var title: (Item) -> String
    var titleFont: ((Item) -> Font)?
    var preserveCase: ((Item) -> Bool)?
    var isSelected: (Item) -> Bool
    var onSelect: (Item) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                PrintChoiceChip(
                    title: title(item),
                    selected: isSelected(item),
                    titleFont: titleFont?(item) ?? AppType.body(14, weight: .medium),
                    preserveCase: preserveCase?(item) ?? false
                ) {
                    onSelect(item)
                }
            }
        }
        .listRowInsets(
            EdgeInsets(top: 8, leading: AppTheme.pageGutter, bottom: 8, trailing: AppTheme.pageGutter)
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

/// Leading chrome caption used by Settings and Process print-text sheets.
struct PrintSectionHeader: View {
    var title: String

    var body: some View {
        Text(title)
            .font(AppType.caption(12))
            .appChromeText()
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowInsets(
                EdgeInsets(top: 4, leading: AppTheme.pageGutter, bottom: 2, trailing: AppTheme.pageGutter)
            )
    }
}

// MARK: - Shared style controls

/// Shared font / size / letter-case chip grids for Settings defaults, front strip, and back note.
/// Optional highlight (strip / Settings front only). Extend here — do not fork per surface.
/// Section order: font → size → letter case → highlight (last).
struct PrintTextStyleControls: View {
    @Binding var font: CaptionFont
    @Binding var fontSize: CaptionFontSize
    @Binding var letterCase: DateCaseStyle
    var highlight: Binding<Bool>? = nil
    /// When false, the highlight section is omitted even if `highlight` is provided (e.g. blank mode).
    var showHighlight: Bool = true

    private struct HighlightChoice: Identifiable {
        let id: Bool
        var label: String { id ? "on" : "off" }
    }

    private static let highlightChoices = [
        HighlightChoice(id: true),
        HighlightChoice(id: false),
    ]

    var body: some View {
        Section {
            PrintChoiceGrid(
                items: Array(CaptionFont.allCases),
                title: { $0.label },
                titleFont: { Font($0.previewFont(size: 15)) },
                isSelected: { font == $0 },
                onSelect: { font = $0 }
            )
        } header: {
            PrintSectionHeader(title: "font")
        }

        Section {
            PrintChoiceGrid(
                items: Array(CaptionFontSize.allCases),
                title: { $0.label },
                isSelected: { fontSize == $0 },
                onSelect: { fontSize = $0 }
            )
        } header: {
            PrintSectionHeader(title: "size")
        }

        Section {
            PrintChoiceGrid(
                items: Array(DateCaseStyle.allCases),
                title: { $0.apply($0.label) },
                preserveCase: { _ in true },
                isSelected: { letterCase == $0 },
                onSelect: { letterCase = $0 }
            )
        } header: {
            PrintSectionHeader(title: "letter case")
        }

        if let highlight, showHighlight {
            Section {
                PrintChoiceGrid(
                    items: Self.highlightChoices,
                    title: { $0.label },
                    isSelected: { highlight.wrappedValue == $0.id },
                    onSelect: { highlight.wrappedValue = $0.id }
                )
            } header: {
                PrintSectionHeader(title: "highlight")
            }
        }
    }
}

/// Caption mode chips (date / custom / blank) — Settings + front strip sheet.
struct CaptionModeGrid: View {
    @Binding var mode: CaptionMode
    var onSelectCustom: () -> Void

    var body: some View {
        PrintChoiceGrid(
            items: Array(CaptionMode.allCases),
            title: { $0.label },
            isSelected: { mode == $0 },
            onSelect: { selected in
                if selected == .custom {
                    onSelectCustom()
                } else {
                    mode = selected
                }
            }
        )
    }
}

/// Date format sample chips — Settings + Process front strip (date mode).
struct DateFormatGrid: View {
    @Binding var format: DateFormatOption
    var letterCase: DateCaseStyle

    var body: some View {
        PrintChoiceGrid(
            items: Array(DateFormatOption.allCases),
            title: { option in
                Caption.formatDate(Date(), format: option, letterCase: letterCase)
            },
            preserveCase: { _ in true },
            isSelected: { format == $0 },
            onSelect: { format = $0 }
        )
    }
}

// MARK: - Editor shell + sheets

/// Done chrome shared by Process print-text sheets (edits apply live).
struct PrintTextEditorShell<Content: View>: View {
    var title: String?
    var onDone: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            List {
                content()
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.surface.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done", action: onDone)
                        .fontWeight(.semibold)
                }
            }
            .modifier(OptionalNavigationTitle(title: title))
        }
    }
}

private struct OptionalNavigationTitle: ViewModifier {
    var title: String?

    func body(content: Content) -> some View {
        if let title {
            content.navigationTitle(title)
        } else {
            content
        }
    }
}

struct FrontCaptionEditSheet: View {
    @Binding var draftMode: CaptionMode
    @Binding var draftCustom: String
    @Binding var draftFont: CaptionFont
    @Binding var draftFontSize: CaptionFontSize
    @Binding var draftCase: DateCaseStyle
    @Binding var draftHighlight: Bool
    @Binding var draftDateFormat: DateFormatOption
    var onDone: () -> Void

    @State private var showCustomPrompt = false

    var body: some View {
        PrintTextEditorShell(onDone: onDone) {
            Section {
                CaptionModeGrid(
                    mode: $draftMode,
                    onSelectCustom: { showCustomPrompt = true }
                )
                if draftMode == .custom, !draftCustom.isEmpty {
                    Text(draftCustom)
                        .font(AppType.body(15))
                        .foregroundStyle(AppTheme.textSecondary)
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
                        .onTapGesture { showCustomPrompt = true }
                }
            } header: {
                PrintSectionHeader(title: "strip text")
            }

            if draftMode == .date {
                Section {
                    DateFormatGrid(format: $draftDateFormat, letterCase: draftCase)
                } header: {
                    PrintSectionHeader(title: "date format")
                }
            }

            PrintTextStyleControls(
                font: $draftFont,
                fontSize: $draftFontSize,
                letterCase: $draftCase,
                highlight: $draftHighlight,
                showHighlight: draftMode != .blank
            )
        }
        .sheet(isPresented: $showCustomPrompt) {
            CustomCaptionPrompt(
                text: $draftCustom,
                onDone: {
                    draftMode = .custom
                    draftCustom = Caption.truncateCaption(draftCustom)
                    showCustomPrompt = false
                }
            )
        }
    }
}

struct BackNoteEditSheet: View {
    @Binding var draftNote: String
    @Binding var draftFont: CaptionFont
    @Binding var draftFontSize: CaptionFontSize
    @Binding var draftCase: DateCaseStyle
    var onDone: () -> Void

    var body: some View {
        PrintTextEditorShell(title: "back note", onDone: onDone) {
            Section {
                TextEditor(text: $draftNote)
                    .font(Font(draftFont.previewFont(size: 17)))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(minHeight: 140)
                    .listRowInsets(
                        EdgeInsets(
                            top: 8,
                            leading: AppTheme.pageGutter,
                            bottom: 8,
                            trailing: AppTheme.pageGutter
                        )
                    )
                    .listRowBackground(Color.clear)
                    .onChange(of: draftNote) { _, newValue in
                        if newValue.count > Caption.backMaxLength {
                            draftNote = String(newValue.prefix(Caption.backMaxLength))
                        }
                    }

                Text("\(draftNote.count)/\(Caption.backMaxLength)")
                    .font(AppType.caption(13, weight: .medium).monospacedDigit())
                    .appChromeText()
                    .foregroundStyle(
                        draftNote.count >= Caption.backMaxLength
                            ? AppTheme.destructive
                            : AppTheme.textSecondary
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .listRowInsets(
                        EdgeInsets(
                            top: 0,
                            leading: AppTheme.pageGutter,
                            bottom: 8,
                            trailing: AppTheme.pageGutter
                        )
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } header: {
                PrintSectionHeader(title: "note")
            }

            PrintTextStyleControls(
                font: $draftFont,
                fontSize: $draftFontSize,
                letterCase: $draftCase
            )
        }
    }
}

/// Disables the navigation edge-swipe pop while gallery paging owns horizontal gestures.
struct InteractivePopGestureDisabler: UIViewControllerRepresentable {
    var disabled: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            uiViewController.navigationController?
                .interactivePopGestureRecognizer?.isEnabled = !disabled
        }
    }

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: ()) {
        uiViewController.navigationController?
            .interactivePopGestureRecognizer?.isEnabled = true
    }
}
