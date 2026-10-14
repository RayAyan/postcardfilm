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
    @State private var showPhotosDenied = false
    @State private var isDownloading = false
    /// Blocks the tap that follows a long-press so Process does not open.
    @State private var suppressOpen = false
    @State private var scrollProgress: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var isRailScrubbing = false
    @State private var scrollScrubber = GalleryScrollScrubber()
    /// Height of the leading subtext block so the rail aligns with the grid top.
    @State private var gridTopInset: CGFloat = 28

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    /// Matches current Polaroid canvas proportions (image + borders + strip).
    private var cellAspect: CGFloat {
        FrameGeometry.canvasAspect
    }

    private var allSelected: Bool {
        !store.items.isEmpty && selectedIDs.count == store.items.count
    }

    /// Long albums always get a rail; also show when measured content overflows.
    private var railNeeded: Bool {
        store.items.count >= 7 || contentHeight > viewportHeight + 24
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
                galleryScroll
            }
        }
        .background(AppTheme.surface.ignoresSafeArea())
        .navigationTitle(isSelecting ? selectedTitle : "gallery")
        .navigationBarTitleDisplayMode(isSelecting ? .inline : .large)
        .toolbar { toolbarContent }
        .deleteConfirmModal(
            isPresented: $showDeleteConfirm,
            message: Brand.deleteConfirm(count: selectedIDs.count),
            onDelete: { performDelete() }
        )
        .alert("photos access is off", isPresented: $showPhotosDenied) {
            Button("cancel", role: .cancel) {}
            Button("open settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("allow adding photos so prints can be saved to your library.")
        }
        .alert("something went wrong", isPresented: $showAlert) {
            Button("ok", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .onAppear {
            store.reload()
            warmGalleryThumbs()
        }
        .onChange(of: store.items.count) { _, count in
            if count == 0 {
                exitSelection()
            } else {
                selectedIDs = selectedIDs.intersection(Set(store.items.map(\.id)))
                warmGalleryThumbs()
            }
        }
    }

    private var galleryScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(Brand.gallerySubtext)
                    .font(AppType.caption(12))
                    .appChromeText()
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppTheme.pageGutter)
                    .padding(.top, 2)
                    .padding(.bottom, 4)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: GallerySubtextHeightKey.self,
                                value: geo.size.height
                            )
                        }
                    )

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(store.items) { item in
                        galleryCell(item)
                            .id(item.id)
                    }
                }
                // Symmetric gutters — rail overlays the trailing edge without shifting the grid.
                .padding(.horizontal, AppTheme.pageGutter)
                .padding(.bottom, 16)
            }
            .background {
                GalleryScrollObserver(scrubber: scrollScrubber) { offsetY, contentH, viewportH in
                    contentHeight = contentH
                    viewportHeight = viewportH
                    guard !isRailScrubbing else { return }
                    let overflow = contentH - viewportH
                    guard overflow > 1 else {
                        scrollProgress = 0
                        return
                    }
                    scrollProgress = min(max(offsetY / overflow, 0), 1)
                }
            }
        }
        // Custom rail for longer albums; system indicator as fallback for short lists.
        .scrollIndicators(railNeeded ? .hidden : .visible, axes: .vertical)
        .onPreferenceChange(GallerySubtextHeightKey.self) { gridTopInset = $0 }
        .overlay(alignment: .topTrailing) {
            GalleryScrollRail(
                itemCount: store.items.count,
                progress: scrollProgress,
                isNeeded: railNeeded,
                onScrubActive: { active in
                    isRailScrubbing = active
                },
                onScrub: { fraction in
                    scrub(to: fraction)
                }
            )
            // Align rail with the top of the photo grid (below subtext).
            .padding(.top, gridTopInset)
            .padding(.bottom, 12)
        }
    }

    private var selectedTitle: String {
        selectedIDs.isEmpty ? "select" : "\(selectedIDs.count) selected"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .topBarLeading) {
                Button(allSelected ? "deselect all" : "select all") {
                    withAnimation(.easeOut(duration: 0.12)) {
                        if allSelected {
                            selectedIDs.removeAll()
                        } else {
                            selectedIDs = GallerySelectionLogic.selectAll(ids: store.items.map(\.id))
                        }
                    }
                }
                .font(AppType.body(17))
                .appChromeText()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.destructive)
                }
                .accessibilityLabel("delete")
                .disabled(selectedIDs.isEmpty || isDownloading)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await performDownload() }
                } label: {
                    Image(systemName: "photo.badge.arrow.down")
                        .font(.system(size: 17, weight: .semibold))
                }
                .accessibilityLabel("download")
                .disabled(selectedIDs.isEmpty || isDownloading)
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
        PolaroidThumb(
            url: store.polaroidURL(for: item.id),
            maxPixel: ThumbnailCache.gridMaxPixel,
            mode: .gridFill,
            aspect: cellAspect
        )
        .overlay {
            if isSelecting, selected {
                AppTheme.accentFill.opacity(0.22)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if isSelecting, selected {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(AppTheme.accentFill, lineWidth: 2.5)
                    .allowsHitTesting(false)
            }
        }
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
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if item.hasBackNote {
                NoteFoldBadge()
            }
        }
        .contentShape(Rectangle())
        .accessibilityLabel(galleryLabel(for: item))
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
        .animation(.easeOut(duration: 0.12), value: selected)
        // Tap / long-press without Button so vertical pan stays with ScrollView (older devices).
        .onTapGesture {
            handleCellTap(item)
        }
        .onLongPressGesture(minimumDuration: 0.45) {
            handleCellLongPress(item)
        }
    }

    private func handleCellTap(_ item: PolaroidRecord) {
        if isSelecting {
            toggleSelection(item.id)
            return
        }
        if suppressOpen {
            suppressOpen = false
            return
        }
        path.append(PrintRoute.saved(id: item.id))
    }

    private func handleCellLongPress(_ item: PolaroidRecord) {
        guard !isSelecting else { return }
        Haptics.lightTap()
        suppressOpen = true
        let result = GallerySelectionLogic.enterLongPress(
            id: item.id,
            selecting: isSelecting,
            selected: selectedIDs
        )
        withAnimation(.easeOut(duration: 0.12)) {
            isSelecting = result.selecting
            selectedIDs = result.selected
        }
    }

    private func scrub(to fraction: CGFloat) {
        let clamped = min(max(fraction, 0), 1)
        scrollProgress = clamped
        scrollScrubber.scrub(to: clamped)
    }

    private func toggleSelection(_ id: String) {
        Haptics.lightTap()
        withAnimation(.easeOut(duration: 0.12)) {
            selectedIDs = GallerySelectionLogic.toggle(id, in: selectedIDs)
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

    private func warmGalleryThumbs() {
        let urls = store.items.prefix(24).map { store.polaroidURL(for: $0.id) }
        ThumbnailCache.prefetch(urls: Array(urls), maxPixel: ThumbnailCache.gridMaxPixel)
    }

    private func exitSelection() {
        isSelecting = false
        selectedIDs.removeAll()
        suppressOpen = false
    }

    private func performDelete() {
        let ids = Array(selectedIDs)
        for id in ids {
            ThumbnailCache.invalidate(url: store.polaroidURL(for: id))
        }
        do {
            try store.delete(ids: ids)
            exitSelection()
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    @MainActor
    private func performDownload() async {
        guard !isDownloading, !selectedIDs.isEmpty else { return }
        isDownloading = true
        defer { isDownloading = false }

        var urls: [URL] = []
        for id in selectedIDs {
            urls.append(store.polaroidURL(for: id))
            if let item = store.items.first(where: { $0.id == id }), item.hasBackNote {
                let back = store.backURL(for: id)
                if FileManager.default.fileExists(atPath: back.path) {
                    urls.append(back)
                }
            }
        }
        let result = await PhotoLibrarySaver.saveImages(at: urls)
        switch result {
        case .saved:
            Haptics.success()
            exitSelection()
        case .denied:
            showPhotosDenied = true
        case .failed(let message):
            alertMessage = message
            showAlert = true
        }
    }
}

private struct GallerySubtextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 28
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

enum PolaroidThumbMode {
    case fit
    case gridFill
}

struct PolaroidThumb: View {
    let url: URL
    var refreshToken: Int = 0
    var maxPixel: Int = ThumbnailCache.gridMaxPixel
    var mode: PolaroidThumbMode = .fit
    var aspect: CGFloat = FrameGeometry.canvasAspect

    @State private var image: UIImage?

    private var requestKey: String {
        "\(url.path)#\(refreshToken)#\(maxPixel)"
    }

    var body: some View {
        Group {
            if let image {
                switch mode {
                case .fit:
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
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
                }
            } else {
                Rectangle()
                    .fill(AppTheme.surfaceRaised)
                    .aspectRatio(aspect, contentMode: .fit)
            }
        }
        .accessibilityAddTraits(.isImage)
        .task(id: requestKey) {
            if let cached = ThumbnailCache.cachedImage(
                at: url,
                refreshToken: refreshToken,
                maxPixel: maxPixel
            ) {
                image = cached
                return
            }
            image = await ThumbnailCache.loadImage(
                at: url,
                refreshToken: refreshToken,
                maxPixel: maxPixel
            )
        }
    }
}
