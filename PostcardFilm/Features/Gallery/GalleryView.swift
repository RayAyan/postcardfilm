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
    /// Toolbar download morphs to checkmark after a successful batch save.
    @State private var downloadSaved = false
    /// IDs fading out before batch delete commits.
    @State private var deletingIDs: Set<String> = []
    /// Blocks the tap that follows a long-press so Process does not open.
    @State private var suppressOpen = false
    @State private var scrollProgress: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var isRailScrubbing = false
    @State private var scrollScrubber = GalleryScrollScrubber()
    /// Height of the leading subtext block so the rail aligns with the grid top.
    @State private var gridTopInset: CGFloat = 28

    // Drag-select stroke (Apple Photos–style paint).
    @State private var cellFrames: [String: CGRect] = [:]
    @State private var dragSelectMode: GallerySelectionLogic.DragPaintMode?
    @State private var dragSelectVisited: Set<String> = []
    @State private var isDragSelecting = false
    /// Vertical pan won this stroke — never paint / never lock scroll.
    @State private var dragSelectScrollOnly = false
    /// First cell under the finger before paint locks.
    @State private var dragSelectAnchorID: String?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]
    private let gridCoordinateSpace = "galleryGrid"

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

    private var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
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
        .background {
            InteractivePopGestureDisabler(disabled: isSelecting)
        }
        .navigationTitle(isSelecting ? selectedTitle : "gallery")
        // Always large — switching large↔inline on enter-select causes a nav-bar flicker.
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(isSelecting)
        .toolbar { toolbarContent }
        .deleteConfirmModal(
            isPresented: $showDeleteConfirm,
            message: Brand.deleteConfirm(count: selectedIDs.count),
            onDelete: { Task { await performDelete() } }
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
                .padding(.horizontal, AppTheme.pageGutter)
                .padding(.bottom, 16)
                .coordinateSpace(name: gridCoordinateSpace)
                .onPreferenceChange(GalleryCellFramesKey.self) { cellFrames = $0 }
                .galleryDragSelectGesture(enabled: isSelecting, dragSelectGesture)
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
        .scrollDisabled(isDragSelecting)
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
            .padding(.top, gridTopInset)
            .padding(.bottom, 12)
        }
    }

    private var dragSelectGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .named(gridCoordinateSpace))
            .onChanged { value in
                handleDragSelectChanged(at: value.location, in: value.startLocation)
            }
            .onEnded { _ in
                endDragSelect()
            }
    }

    private var selectedTitle: String {
        selectedIDs.isEmpty ? "select" : "\(selectedIDs.count) selected"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .topBarLeading) {
                Button("cancel") {
                    withAnimation(.easeOut(duration: 0.12)) {
                        exitSelection()
                    }
                }
                .font(AppType.body(17))
                .appChromeText()
                .disabled(isDownloading || !deletingIDs.isEmpty || downloadSaved)
            }
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
                .disabled(isDownloading || !deletingIDs.isEmpty || downloadSaved)
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
                .disabled(selectedIDs.isEmpty || isDownloading || !deletingIDs.isEmpty || downloadSaved)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await performDownload() }
                } label: {
                    if isDownloading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(AppTheme.textPrimary)
                    } else {
                        Image(systemName: downloadSaved ? "checkmark" : "photo.badge.arrow.down")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(downloadSaved ? AppTheme.accentFill : AppTheme.textPrimary)
                    }
                }
                .accessibilityLabel(
                    isDownloading
                        ? "downloading"
                        : (downloadSaved ? "saved to photos" : "download")
                )
                .disabled(selectedIDs.isEmpty || isDownloading || !deletingIDs.isEmpty || downloadSaved)
            }
        } else if !store.items.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                Button("select") {
                    withAnimation(.easeOut(duration: 0.12)) {
                        isSelecting = true
                    }
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
        let fading = deletingIDs.contains(item.id)
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
        .opacity(fading ? 0 : 1)
        .scaleEffect(fading ? 0.92 : 1)
        .contentShape(Rectangle())
        .accessibilityLabel(galleryLabel(for: item))
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
        // Skip implicit animation while paint-dragging — per-hit thrash feels sticky on first stroke.
        .animation(isDragSelecting ? nil : .easeOut(duration: 0.12), value: selected)
        .background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: GalleryCellFramesKey.self,
                    value: [item.id: geo.frame(in: .named(gridCoordinateSpace))]
                )
            }
        }
        // Tap / long-press without Button so vertical pan stays with ScrollView (older devices).
        .onTapGesture {
            handleCellTap(item)
        }
        .onLongPressGesture(minimumDuration: 0.45) {
            handleCellLongPress(item)
        }
    }

    private func handleDragSelectChanged(at location: CGPoint, in startLocation: CGPoint) {
        guard isSelecting, deletingIDs.isEmpty, !isDownloading, !downloadSaved else { return }
        guard !dragSelectScrollOnly else { return }

        let dx = abs(location.x - startLocation.x)
        let dy = abs(location.y - startLocation.y)

        if dragSelectMode == nil {
            // Pure vertical pan → leave ScrollView alone for this stroke.
            if dy > dx * 1.2, dy > 14 {
                dragSelectScrollOnly = true
                return
            }

            let startID = hitTestCell(at: startLocation)
            let currentID = hitTestCell(at: location)
            if dragSelectAnchorID == nil {
                dragSelectAnchorID = startID ?? currentID
            }

            let horizontalPaint = dx >= dy && dx > 12
            let crossedCell = startID != nil && currentID != nil && startID != currentID
            guard horizontalPaint || crossedCell else { return }
            guard let anchor = dragSelectAnchorID ?? startID ?? currentID else { return }

            let mode = GallerySelectionLogic.paintMode(for: anchor, startingFrom: selectedIDs)
            dragSelectMode = mode
            isDragSelecting = true
            dragSelectVisited = [anchor]
            // Instant updates during paint — no per-hit animation/haptic noise.
            selectedIDs = GallerySelectionLogic.applyDragHit(
                id: anchor,
                mode: mode,
                to: selectedIDs
            )
            if let currentID, currentID != anchor {
                dragSelectVisited.insert(currentID)
                selectedIDs = GallerySelectionLogic.applyDragHit(
                    id: currentID,
                    mode: mode,
                    to: selectedIDs
                )
            }
            Haptics.lightTap()
            return
        }

        guard let mode = dragSelectMode else { return }
        guard let hit = hitTestCell(at: location), !dragSelectVisited.contains(hit) else { return }
        dragSelectVisited.insert(hit)
        selectedIDs = GallerySelectionLogic.applyDragHit(
            id: hit,
            mode: mode,
            to: selectedIDs
        )
    }

    private func hitTestCell(at point: CGPoint) -> String? {
        // Ignore points past the grid (trailing scroll rail overlay).
        if let maxX = cellFrames.values.map(\.maxX).max(), point.x > maxX + 4 {
            return nil
        }
        for (id, frame) in cellFrames where frame.contains(point) {
            return id
        }
        return nil
    }

    private func endDragSelect() {
        dragSelectMode = nil
        dragSelectVisited.removeAll()
        isDragSelecting = false
        dragSelectScrollOnly = false
        dragSelectAnchorID = nil
    }

    private func handleCellTap(_ item: PolaroidRecord) {
        if isSelecting {
            guard deletingIDs.isEmpty, !isDownloading, !downloadSaved else { return }
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
        // Same ease as toolbar select — chrome only; title stays large (no mode flip).
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
        downloadSaved = false
        deletingIDs.removeAll()
        endDragSelect()
    }

    @MainActor
    private func performDelete() async {
        let ids = Array(selectedIDs)
        guard !ids.isEmpty else { return }

        if reduceMotion {
            commitDelete(ids: ids)
            return
        }

        withAnimation(.easeOut(duration: 0.2)) {
            deletingIDs = Set(ids)
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
        commitDelete(ids: ids)
    }

    private func commitDelete(ids: [String]) {
        for id in ids {
            ThumbnailCache.invalidate(url: store.polaroidURL(for: id))
        }
        do {
            try store.delete(ids: ids)
            Haptics.success()
            exitSelection()
        } catch {
            deletingIDs.removeAll()
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    @MainActor
    private func performDownload() async {
        guard !isDownloading, !selectedIDs.isEmpty, !downloadSaved else { return }
        isDownloading = true

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
        isDownloading = false

        switch result {
        case .saved:
            Haptics.success()
            withAnimation(.easeOut(duration: 0.15)) {
                downloadSaved = true
            }
            if reduceMotion {
                exitSelection()
            } else {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                exitSelection()
            }
        case .denied:
            showPhotosDenied = true
        case .failed(let message):
            alertMessage = message
            showAlert = true
        }
    }
}

private extension View {
    /// Attach drag-paint only while selecting so normal browse scroll stays untouched.
    @ViewBuilder
    func galleryDragSelectGesture<G: Gesture>(enabled: Bool, _ gesture: G) -> some View {
        if enabled {
            simultaneousGesture(gesture)
        } else {
            self
        }
    }
}

private struct GallerySubtextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 28
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct GalleryCellFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
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
