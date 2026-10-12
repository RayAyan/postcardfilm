#if DEBUG
import SwiftUI

/// DEBUG + test-branch only: force a film stock / expression before shutter.
/// See `.cursor/rules/film-debug-picker.mdc`.
@MainActor
final class FilmDebugSession: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case auto
        case manual
        var id: String { rawValue }
    }

    /// Midpoints of `FilmExpression` gentle / medium / bold bands.
    enum ExpressionBand: String, CaseIterable, Identifiable {
        case gentle
        case medium
        case bold

        var id: String { rawValue }

        var label: String {
            switch self {
            case .gentle: return "Gentle"
            case .medium: return "Medium"
            case .bold: return "Bold"
            }
        }

        var strength: Double {
            switch self {
            case .gentle: return 0.52
            case .medium: return 0.72
            case .bold: return 0.91
            }
        }
    }

    @Published var mode: Mode = .auto
    @Published var stock: FilmStock = .onestep
    @Published var band: ExpressionBand = .medium

    /// Visible only on Debug builds from the `test` git branch.
    static var isAvailable: Bool { BuildChannel.isTestBranch }

    /// `nil` → pipeline draws stock as usual.
    var overrideStock: FilmStock? {
        guard Self.isAvailable, mode == .manual else { return nil }
        return stock
    }

    /// `nil` → pipeline resolves expression as usual.
    var overrideStrength: Double? {
        guard Self.isAvailable, mode == .manual else { return nil }
        return band.strength
    }

    var chipLabel: String {
        switch mode {
        case .auto:
            return "auto"
        case .manual:
            return "manual · \(stock.cameraName)"
        }
    }
}

struct FilmDebugChip: View {
    @ObservedObject var session: FilmDebugSession
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(session.chipLabel)
                .font(AppType.micro(10))
                .appChromeText()
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .overlay(
                    Capsule()
                        .stroke(AppTheme.hairline, lineWidth: 1)
                )
        }
        .accessibilityLabel("Film debug \(session.chipLabel)")
        .buttonStyle(.plain)
    }
}

struct FilmDebugPickerSheet: View {
    @ObservedObject var session: FilmDebugSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Mode", selection: $session.mode) {
                        ForEach(FilmDebugSession.Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    Text("draw")
                } footer: {
                    Text("auto keeps the random pack draw. manual skips stock generation for the next shutter.")
                }

                if session.mode == .manual {
                    Section("stock") {
                        ForEach(FilmStock.allCases, id: \.self) { stock in
                            Button {
                                session.stock = stock
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(stock.cameraName)
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text(stock.rawValue)
                                            .font(AppType.micro(10))
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                    Spacer()
                                    if session.stock == stock {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(AppTheme.textPrimary)
                                    }
                                }
                            }
                        }
                    }

                    Section {
                        Picker("Expression", selection: $session.band) {
                            ForEach(FilmDebugSession.ExpressionBand.allCases) { band in
                                Text(band.label).tag(band)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    } header: {
                        Text("expression")
                    } footer: {
                        Text("gentle / medium / bold midpoints (\(String(format: "%.2f", FilmDebugSession.ExpressionBand.gentle.strength)) / \(String(format: "%.2f", FilmDebugSession.ExpressionBand.medium.strength)) / \(String(format: "%.2f", FilmDebugSession.ExpressionBand.bold.strength))).")
                    }
                }
            }
            .navigationTitle("film debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
#endif
