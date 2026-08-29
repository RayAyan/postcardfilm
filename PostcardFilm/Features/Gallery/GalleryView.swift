import SwiftUI

struct GalleryView: View {
    @EnvironmentObject private var store: PolaroidStore
    @Environment(\.dismiss) private var dismiss
    @Binding var path: NavigationPath

    @State private var isSelecting = false
    @State private var selectedIDs: Set<String> = []
    @State private var showDeleteConfirm = false
    @State private var alertMessage: String?
    @State private var showAlert = false
    /// Blocks the tap that follows a long-press so Process does not open.
    @State private var suppressOpen = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    /// Matches current Polaroid canvas proportions (image + borders + strip).
    private var cellAspect: CGFloat {
        let layout = FrameGeometry.computeFrameLayout()
        return CGFloat(layout.canvasWidth) / CGFloat(layout.canvasHeight)
    }

    private var allSelected: Bool {
        !store.items.isEmpty && selectedIDs.count == store.items.count
    }

    var body: some View {
        Group {
            if store.items.isEmpty {
                VStack(spacing: 12) {
                    Text(Brand.emptyGallery)
                        .font(AppType.body(17))
                        .appChromeText()
                        .foregroundStyle(AppTheme.textSecondary)
                    Button {
                        dismiss()
                    } label: {
                        Text(Brand.takeOne)
                            .font(AppType.body(17, weight: .semibold))
                            .appChromeText()
                            .foregroundStyle(AppTheme.accentText)
                            .frame(minHeight: AppTheme.hitTarget)
                            .padding(.horizontal, 20)
                            .background(AppTheme.accentFill)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .accessibilityLabel("Take one")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(Brand.gallerySubtext)
                        .font(AppType.caption(12))
                        .appChromeText()
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 8)

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(store.items) { item in
                            galleryCell(item)
                                .id(item.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(AppTheme.surface.ignoresSafeArea())
        .navigationTitle(isSelecting ? selectedTitle : "gallery")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .confirmationDialog(deleteTitle, isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("delete", role: .destructive) { performDelete() }
            Button("cancel", role: .cancel) {}
        }
        .alert("something went wrong", isPresented: $showAlert) {
            Button("ok", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .onAppear { store.reload() }
        .onChange(of: store.items.count) { _, count in
            if count == 0 {
                exitSelection()
            } else {
                selectedIDs = selectedIDs.intersection(Set(store.items.map(\.id)))
            }
        }
    }

    private var selectedTitle: String {
        selectedIDs.isEmpty ? "select" : "\(selectedIDs.count) selected"
    }

    private var deleteTitle: String {
        let n = selectedIDs.count
        return n == 1 ? "delete this print?" : "delete \(n) prints?"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .topBarLeading) {
                Button(allSelected ? "deselect all" : "select all") {
                    if allSelected {
                        selectedIDs.removeAll()
                    } else {
                        selectedIDs = GallerySelectionLogic.selectAll(ids: store.items.map(\.id))
                    }
                }
                .font(AppType.body(17))
                .appChromeText()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("delete", role: .destructive) {
                    showDeleteConfirm = true
                }
                .font(AppType.body(17, weight: .semibold))
                .appChromeText()
                .disabled(selectedIDs.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("cancel") {
                    exitSelection()
                }
                .font(AppType.body(17))
                .appChromeText()
            }
        } else if !store.items.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                Button("select") {
                    isSelecting = true
                }
                .font(AppType.body(17))
                .appChromeText()
                .accessibilityLabel("Select prints")
            }
        }
    }

    @ViewBuilder
    private func galleryCell(_ item: PolaroidRecord) -> some View {
        let selected = selectedIDs.contains(item.id)
        let thumb = PolaroidThumb(
            url: store.polaroidURL(for: item.id),
            mode: .gridFill,
            aspect: cellAspect
        )
        .overlay(alignment: .topTrailing) {
            if isSelecting {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        selected ? AppTheme.accentText : AppTheme.textPrimary,
                        selected ? AppTheme.accentFill : Color.black.opacity(0.35)
                    )
                    .padding(6)
            }
        }
        .contentShape(Rectangle())
        .accessibilityLabel(galleryLabel(for: item))
        .accessibilityAddTraits(selected ? [.isSelected] : [])

        if isSelecting {
            Button {
                selectedIDs = GallerySelectionLogic.toggle(item.id, in: selectedIDs)
            } label: {
                thumb
            }
            .buttonStyle(.plain)
        } else {
            Button {
                if suppressOpen {
                    suppressOpen = false
                    return
                }
                path.append(PrintRoute.saved(id: item.id))
            } label: {
                thumb
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45)
                    .onEnded { _ in
                        Haptics.lightTap()
                        suppressOpen = true
                        let result = GallerySelectionLogic.enterLongPress(
                            id: item.id,
                            selecting: isSelecting,
                            selected: selectedIDs
                        )
                        isSelecting = result.selecting
                        selectedIDs = result.selected
                    }
            )
        }
    }

    private func galleryLabel(for item: PolaroidRecord) -> String {
        var parts: [String] = []
        if item.caption.isEmpty {
            parts.append("Print, blank strip")
        } else {
            parts.append("Print, \(item.caption)")
        }
        if item.hasBackNote {
            parts.append("has a note on the back")
        }
        return parts.joined(separator: ", ")
    }

    private func exitSelection() {
        isSelecting = false
        selectedIDs.removeAll()
        suppressOpen = false
    }

    private func performDelete() {
        let ids = Array(selectedIDs)
        do {
            try store.delete(ids: ids)
            exitSelection()
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}

enum PolaroidThumbMode {
    case fit
    case gridFill
}

struct PolaroidThumb: View {
    let url: URL
    var refreshToken: Int = 0
    var mode: PolaroidThumbMode = .fit
    var aspect: CGFloat = 0.82

    var body: some View {
        Group {
            if let image = UIImage(contentsOfFile: url.path) {
                switch mode {
                case .fit:
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                        .id(refreshToken)
                case .gridFill:
                    Color.clear
                        .aspectRatio(aspect, contentMode: .fit)
                        .overlay(
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        )
                        .clipped()
                        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                        .id(refreshToken)
                }
            } else {
                Rectangle()
                    .fill(AppTheme.surfaceRaised)
                    .aspectRatio(aspect, contentMode: .fit)
            }
        }
        .accessibilityAddTraits(.isImage)
    }
}
