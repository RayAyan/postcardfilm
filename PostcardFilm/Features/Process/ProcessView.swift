import SwiftUI

struct ProcessView: View {
    let openedFromCapture: Bool

    @EnvironmentObject private var store: PolaroidStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var currentID: String
    @State private var record: PolaroidRecord?
    @State private var missing = false
    @State private var saved = false
    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @State private var showPhotosDenied = false
    @State private var showCaptionSheet = false
    @State private var showBackNoteSheet = false
    @State private var draftMode: CaptionMode = .date
    @State private var draftCustom = ""
    @State private var draftFont: CaptionFont = .serif
    @State private var draftFontSize: CaptionFontSize = .medium
    @State private var draftCase: DateCaseStyle = .lowercase
    @State private var draftHighlight = true
    @State private var draftBackNote = ""
    @State private var draftBackFont: CaptionFont = .script
    @State private var draftBackFontSize: CaptionFontSize = .medium
    @State private var draftBackCase: DateCaseStyle = .lowercase
    @State private var bust = 0
    @State private var backBust = 0
    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var saveResetTask: Task<Void, Never>?
    @State private var isReburning = false
    @State private var isDeveloping: Bool
    @State private var overlayElapsed = false
    @State private var isFlipped = false
    @State private var flipAngle: Double = 0
    @State private var isFlipping = false
    @State private var hidePrintText = false
    @State private var flipGeneration = 0
    @State private var sharePayload: SharePayload?
    @State private var applyTask: Task<Void, Never>?
    @State private var lastApplyCompletedAt: Date?
    @State private var draftDateFormat: DateFormatOption = .long
    /// Which live editor last opened — used to flush the right drafts on dismiss.
    @State private var activeEditor: LiveEditorKind = .none

    private enum LiveEditorKind {
        case none, front, back
    }

    private var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    private var showingBackFace: Bool {
        flipAngle >= 90
    }

    private var galleryPagingEnabled: Bool {
        !openedFromCapture
            && !isDeveloping
            && !isFlipping
            && !showingBackFace
            && !showCaptionSheet
            && !showBackNoteSheet
            && !showDeleteConfirm
            && sharePayload == nil
    }

    private var stripHeightFraction: CGFloat {
        CGFloat(FrameGeometry.bottomRatio(of: FrameGeometry.computeFrameLayout()))
    }

    init(id: String, openedFromCapture: Bool) {
        self.openedFromCapture = openedFromCapture
        _currentID = State(initialValue: id)
        _isDeveloping = State(initialValue: openedFromCapture && !UIAccessibility.isReduceMotionEnabled)
    }

    var body: some View {
        Group {
            if missing {
                VStack(spacing: 16) {
                    Text(Brand.printGone)
                        .font(AppType.body(17))
                        .appChromeText()
                        .foregroundStyle(AppTheme.textSecondary)
                    Button {
                        dismiss()
                    } label: {
                        Text(Brand.backToGallery)
                            .font(AppType.body(17, weight: .semibold))
                            .appChromeText()
                            .foregroundStyle(AppTheme.accentText)
                            .frame(minHeight: AppTheme.hitTarget)
                            .padding(.horizontal, 20)
                            .background(AppTheme.accentFill)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            } else if record != nil || openedFromCapture {
                content
            } else {
                ProgressView()
                    .tint(AppTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.surface.ignoresSafeArea())
        .background(InteractivePopGestureDisabler(disabled: !openedFromCapture && !missing))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Wordmark()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    flip()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .semibold))
                            .rotationEffect(.degrees(isFlipped ? 180 : 0))
                            .animation(
                                reduceMotion ? .none : .easeInOut(duration: 0.45),
                                value: isFlipped
                            )
                        Text("flip")
                            .font(AppType.caption(13, weight: .semibold))
                            .appChromeText()
                    }
                    .foregroundStyle(isFlipped ? AppTheme.accentText : AppTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background {
                        Capsule(style: .continuous)
                            .fill(isFlipped ? AppTheme.accentFill : AppTheme.surfaceRaised)
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(
                                        isFlipped
                                            ? AppTheme.accentFill
                                            : AppTheme.hairline.opacity(0.9),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .scaleEffect(isFlipping ? 0.94 : 1)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.28, dampingFraction: 0.72),
                        value: isFlipping
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFlipped ? "flip to front" : "flip")
                .disabled(isDeveloping || isFlipping || showCaptionSheet || showBackNoteSheet || missing)
            }
        }
        .deleteConfirmModal(
            isPresented: $showDeleteConfirm,
            message: Brand.deleteConfirmOne,
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
        .sheet(isPresented: $showCaptionSheet, onDismiss: { flushPendingApply() }) {
            FrontCaptionEditSheet(
                draftMode: $draftMode,
                draftCustom: $draftCustom,
                draftFont: $draftFont,
                draftFontSize: $draftFontSize,
                draftCase: $draftCase,
                draftHighlight: $draftHighlight,
                draftDateFormat: $draftDateFormat,
                onDone: { showCaptionSheet = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .onChange(of: draftMode) { _, _ in scheduleFrontApply(delayMs: 300) }
            .onChange(of: draftCustom) { _, _ in scheduleFrontApply(delayMs: 600) }
            .onChange(of: draftFont) { _, _ in scheduleFrontApply(delayMs: 300) }
            .onChange(of: draftFontSize) { _, _ in scheduleFrontApply(delayMs: 300) }
            .onChange(of: draftCase) { _, _ in scheduleFrontApply(delayMs: 300) }
            .onChange(of: draftHighlight) { _, _ in scheduleFrontApply(delayMs: 300) }
            .onChange(of: draftDateFormat) { _, _ in scheduleFrontApply(delayMs: 300) }
        }
        .sheet(isPresented: $showBackNoteSheet, onDismiss: { flushPendingApply() }) {
            BackNoteEditSheet(
                draftNote: $draftBackNote,
                draftFont: $draftBackFont,
                draftFontSize: $draftBackFontSize,
                draftCase: $draftBackCase,
                onDone: { showBackNoteSheet = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .onChange(of: draftBackNote) { _, _ in scheduleBackApply(delayMs: 600) }
            .onChange(of: draftBackFont) { _, _ in scheduleBackApply(delayMs: 300) }
            .onChange(of: draftBackFontSize) { _, _ in scheduleBackApply(delayMs: 300) }
            .onChange(of: draftBackCase) { _, _ in scheduleBackApply(delayMs: 300) }
        }
        .sheet(item: $sharePayload) { payload in
            ActivityShareSheet(items: payload.items)
        }
        .onAppear { reload() }
        .onChange(of: store.items) { _, _ in
            reload()
        }
        .onChange(of: currentID) { _, _ in
            resetTransientStateForNeighbor()
            reload()
        }
        .onDisappear {
            saveResetTask?.cancel()
            applyTask?.cancel()
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            Group {
                if openedFromCapture {
                    editableCard(id: currentID, record: record, showDevelop: isDeveloping)
                        .padding(.horizontal, AppTheme.processCardGutter)
                } else {
                    TabView(selection: $currentID) {
                        ForEach(store.items) { item in
                            editableCard(
                                id: item.id,
                                record: item.id == currentID ? record : item,
                                showDevelop: false
                            )
                            .padding(.horizontal, AppTheme.processCardGutter)
                            .tag(item.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .scrollDisabled(!galleryPagingEnabled)
                }
            }
            .frame(maxWidth: .infinity)

            Text(hintText)
                .font(AppType.caption(13))
                .appChromeText()
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, AppTheme.taglineGap)
                .padding(.horizontal, 24)

            Spacer(minLength: 16)

            HStack(alignment: .center, spacing: 16) {
                actionButton(systemName: "square.and.arrow.up", label: "share print") {
                    Task { await prepareShare() }
                }
                .disabled(isDeveloping || isFlipping || isSaving || record == nil)

                Spacer(minLength: 0)

                HStack(spacing: 16) {
                    actionButton(systemName: "trash", label: "delete print") {
                        showDeleteConfirm = true
                    }
                    .disabled(isDeveloping || record == nil)
                    actionButton(
                        systemName: saved ? "checkmark" : "photo.badge.arrow.down",
                        label: saved
                            ? "saved to photos"
                            : (showingBackFace ? "download back to photos" : "download front to photos")
                    ) {
                        Task { await download() }
                    }
                    .disabled(isDeveloping || isSaving || record == nil)
                }
            }
            .padding(.horizontal, AppTheme.pageGutter)
            .padding(.bottom, 28)
        }
    }

    @ViewBuilder
    private func editableCard(id: String, record: PolaroidRecord?, showDevelop: Bool) -> some View {
        let active = id == currentID
        flipCard(id: id, record: record, showDevelop: showDevelop && active)
            .overlay {
                if active, !isDeveloping, !isFlipping, record != nil {
                    GeometryReader { geo in
                        if showingBackFace {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture { openBackNoteEditor() }
                                .accessibilityLabel(cardAccessibility(record))
                                .accessibilityAddTraits(.isButton)
                        } else {
                            VStack(spacing: 0) {
                                Color.clear
                                    .frame(height: max(0, geo.size.height * (1 - stripHeightFraction)))
                                    .allowsHitTesting(false)
                                Color.clear
                                    .frame(height: geo.size.height * stripHeightFraction)
                                    .contentShape(Rectangle())
                                    .onTapGesture { openCaptionEditor() }
                                    .accessibilityLabel(cardAccessibility(record))
                                    .accessibilityAddTraits(.isButton)
                            }
                        }
                    }
                }
            }
    }

    private var hintText: String {
        if isDeveloping { return Brand.developing }
        return showingBackFace ? Brand.backHint : Brand.processHint
    }

    private func cardAccessibility(_ record: PolaroidRecord?) -> String {
        guard let record, !isDeveloping else { return "Developing" }
        if showingBackFace {
            if record.hasBackNote {
                return "Back of print, \(record.backNote ?? "")"
            }
            return "Back of print, blank"
        }
        if record.caption.isEmpty {
            return "Edit strip caption, blank"
        }
        return "Edit strip caption, currently \(record.caption)"
    }

    private func openCaptionEditor() {
        guard let record, !isDeveloping, !isFlipping, !showingBackFace else { return }
        draftMode = record.captionMode
        draftCustom = record.captionMode == .custom ? record.caption : ""
        draftFont = record.captionFont
        draftFontSize = record.captionFontSize
        draftCase = record.captionLetterCase
        draftHighlight = record.captionHighlight
        draftDateFormat = record.dateFormat
        activeEditor = .front
        showCaptionSheet = true
    }

    private func openBackNoteEditor() {
        guard let record, !isDeveloping, !isFlipping, showingBackFace else { return }
        draftBackNote = record.backNote ?? ""
        if record.hasBackNote {
            draftBackFont = record.backFont
            draftBackFontSize = record.backFontSize
            draftBackCase = record.backLetterCase
        } else {
            let defaults = settingsStore.settings
            draftBackFont = defaults.backFont
            draftBackFontSize = defaults.backFontSize
            draftBackCase = defaults.backLetterCase
        }
        activeEditor = .back
        showBackNoteSheet = true
    }

    @ViewBuilder
    private func flipCard(id: String, record: PolaroidRecord?, showDevelop: Bool) -> some View {
        let showingBack = flipAngle >= 90 && id == currentID
        ZStack {
            if showingBack, let record {
                backFace(id: id, record: record)
                    .overlay {
                        if hidePrintText, id == currentID {
                            printTextCover(isBack: true)
                        }
                    }
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            } else {
                frontFace(id: id, showDevelop: showDevelop)
                    .overlay {
                        if hidePrintText, id == currentID {
                            printTextCover(isBack: false)
                        }
                    }
            }
        }
        .aspectRatio(FrameGeometry.canvasAspect, contentMode: .fit)
        .clipped()
        .rotation3DEffect(
            .degrees(id == currentID ? flipAngle : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.6
        )
        .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
    }

    /// Paper cover over burned caption / note so text doesn't warp mid-flip.
    private func printTextCover(isBack: Bool) -> some View {
        GeometryReader { geo in
            if isBack {
                AppTheme.paper
            } else {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: max(0, geo.size.height * (1 - stripHeightFraction)))
                    AppTheme.paper
                        .frame(height: geo.size.height * stripHeightFraction)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func frontFace(id: String, showDevelop: Bool) -> some View {
        PolaroidThumb(url: store.polaroidURL(for: id), refreshToken: id == currentID ? bust : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if showDevelop {
                    DevelopingOverlay(
                        reduceMotion: reduceMotion,
                        labelHold: 0.8,
                        fadeDuration: 2.0,
                        printReady: record != nil
                    ) {
                        overlayElapsed = true
                        maybeRevealPrint()
                    }
                }
            }
    }

    @ViewBuilder
    private func backFace(id: String, record: PolaroidRecord) -> some View {
        let url = store.backURL(for: id)
        if record.hasBackNote, FileManager.default.fileExists(atPath: url.path) {
            PolaroidThumb(url: url, refreshToken: id == currentID ? backBust : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            blankBackPlaceholder
        }
    }

    private var blankBackPlaceholder: some View {
        let layout = FrameGeometry.computeFrameLayout()
        let insetFraction = CGFloat(layout.side) * 0.55 / CGFloat(layout.canvasWidth)
        return AppTheme.paper
            .overlay {
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 1)
                        .stroke(AppTheme.graphite.opacity(0.72), lineWidth: 2.5)
                        .padding(geo.size.width * insetFraction)
                }
            }
            .overlay(
                Text(Brand.wordmark)
                    .font(AppType.micro(11))
                    .appChromeText()
                    .foregroundStyle(AppTheme.graphite.opacity(0.28))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 28)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func actionButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: AppTheme.hitTarget, height: AppTheme.hitTarget)
        }
        .accessibilityLabel(label)
    }

    private func flip() {
        guard !isFlipping else { return }
        isFlipping = true
        Haptics.lightTap()
        flipGeneration += 1
        let generation = flipGeneration

        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.15)) {
                isFlipped.toggle()
                flipAngle = isFlipped ? 180 : 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                guard generation == flipGeneration else { return }
                isFlipping = false
            }
            return
        }

        let target = isFlipped ? 0.0 : 180.0
        // Cover burned text first; wait one short beat so the cover commits before rotation.
        hidePrintText = true
        let coverDelay: TimeInterval = 0.06
        let rotateDuration: TimeInterval = 0.45
        DispatchQueue.main.asyncAfter(deadline: .now() + coverDelay) {
            guard generation == flipGeneration else { return }
            withAnimation(.easeInOut(duration: rotateDuration)) {
                flipAngle = target
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + rotateDuration * 0.5) {
                guard generation == flipGeneration else { return }
                isFlipped = target == 180
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + rotateDuration) {
                guard generation == flipGeneration else { return }
                hidePrintText = false
                isFlipping = false
            }
        }
    }

    private func resetTransientStateForNeighbor() {
        flipGeneration += 1
        showCaptionSheet = false
        showBackNoteSheet = false
        applyTask?.cancel()
        applyTask = nil
        activeEditor = .none
        sharePayload = nil
        saved = false
        isFlipped = false
        flipAngle = 0
        isFlipping = false
        hidePrintText = false
        bust = 0
        backBust = 0
    }

    private func reload() {
        if let item = store.polaroid(id: currentID) {
            let wasNil = record == nil || record?.id != item.id
            record = item
            missing = false
            if wasNil { bust += 1 }
            maybeRevealPrint()
        } else if openedFromCapture {
            missing = false
        } else if store.items.contains(where: { $0.id == currentID }) == false {
            // Swiped away from a deleted neighbor — snap to nearest remaining print.
            if let first = store.items.first {
                currentID = first.id
                missing = false
            } else {
                missing = true
            }
        } else {
            missing = true
        }
    }

    private func maybeRevealPrint() {
        guard overlayElapsed || !isDeveloping else { return }
        guard record != nil else { return }
        guard isDeveloping else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            isDeveloping = false
        }
    }

    private func performDelete() {
        do {
            try store.delete(id: currentID)
            if openedFromCapture || store.items.isEmpty {
                dismiss()
            } else if let next = store.items.first {
                currentID = next.id
            } else {
                dismiss()
            }
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    @MainActor
    private func download() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        let result: PhotoLibrarySaveResult
        if showingBackFace {
            let back = store.backURL(for: currentID)
            if FileManager.default.fileExists(atPath: back.path) {
                result = await PhotoLibrarySaver.saveImage(at: back)
            } else {
                do {
                    let image = try PolaroidPipeline.renderBlankBack()
                    guard let png = image.pngData() else { throw PipelineError.encodeFailed }
                    result = await PhotoLibrarySaver.saveImage(data: png)
                } catch {
                    alertMessage = error.localizedDescription
                    showAlert = true
                    return
                }
            }
        } else {
            result = await PhotoLibrarySaver.saveImage(at: store.polaroidURL(for: currentID))
        }

        switch result {
        case .saved:
            Haptics.success()
            saved = true
            saveResetTask?.cancel()
            saveResetTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                guard !Task.isCancelled else { return }
                saved = false
            }
        case .denied:
            showPhotosDenied = true
        case .failed(let message):
            alertMessage = message
            showAlert = true
        }
    }

    private func scheduleFrontApply(delayMs: UInt64) {
        applyTask?.cancel()
        applyTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
            guard !Task.isCancelled else { return }
            await applyFrontDraft()
        }
    }

    private func scheduleBackApply(delayMs: UInt64) {
        applyTask?.cancel()
        applyTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
            guard !Task.isCancelled else { return }
            await applyBackDraft()
        }
    }

    private func flushPendingApply() {
        applyTask?.cancel()
        applyTask = nil
        let kind = activeEditor
        activeEditor = .none
        if let lastApplyCompletedAt,
           Date().timeIntervalSince(lastApplyCompletedAt) < 0.15
        {
            return
        }
        Task { @MainActor in
            switch kind {
            case .front:
                await applyFrontDraft()
            case .back:
                await applyBackDraft()
            case .none:
                break
            }
        }
    }

    private func applyFrontDraft() async {
        guard let record else { return }
        guard Caption.frontBurnNeeded(
            record: record,
            mode: draftMode,
            customText: draftCustom,
            font: draftFont,
            fontSize: draftFontSize,
            letterCase: draftCase,
            dateFormat: draftDateFormat,
            highlight: draftHighlight
        ) else { return }
        var custom = draftCustom
        if draftMode == .custom {
            custom = draftCase.apply(Caption.truncateCaption(draftCustom))
        }
        await reburnFront(
            mode: draftMode,
            custom: custom,
            font: draftFont,
            fontSize: draftFontSize,
            dateCase: draftCase,
            dateFormat: draftDateFormat,
            highlight: draftHighlight
        )
    }

    private func applyBackDraft() async {
        guard let record else { return }
        guard Caption.backBurnNeeded(
            record: record,
            note: draftBackNote,
            font: draftBackFont,
            fontSize: draftBackFontSize,
            letterCase: draftBackCase
        ) else { return }
        guard !isReburning else { return }
        isReburning = true
        defer { isReburning = false }
        do {
            let trimmed = Caption.truncateBackNote(draftBackNote)
            let cased = draftBackCase.apply(trimmed)
            if cased.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try store.updateBackNote(
                    id: currentID,
                    backNote: nil,
                    backFont: draftBackFont,
                    backFontSize: draftBackFontSize,
                    backLetterCase: draftBackCase,
                    backPNG: nil
                )
            } else {
                let image = try PolaroidPipeline.renderBack(
                    note: trimmed,
                    font: draftBackFont,
                    fontSize: draftBackFontSize,
                    letterCase: draftBackCase
                )
                guard let png = image.pngData() else {
                    throw PipelineError.encodeFailed
                }
                try store.updateBackNote(
                    id: currentID,
                    backNote: cased,
                    backFont: draftBackFont,
                    backFontSize: draftBackFontSize,
                    backLetterCase: draftBackCase,
                    backPNG: png
                )
            }
            backBust += 1
            lastApplyCompletedAt = Date()
            reload()
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func reburnFront(
        mode: CaptionMode,
        custom: String,
        font: CaptionFont,
        fontSize: CaptionFontSize,
        dateCase: DateCaseStyle? = nil,
        dateFormat: DateFormatOption? = nil,
        highlight: Bool? = nil
    ) async {
        guard let record, !isReburning else { return }
        isReburning = true
        defer { isReburning = false }
        let useHighlight = highlight ?? record.captionHighlight
        let burnFormat = dateFormat ?? record.dateFormat
        let burnCase = dateCase ?? record.captionLetterCase
        do {
            let data = try Data(contentsOf: store.originalURL(for: currentID))
            let burnDate = Caption.parseISODate(record.createdAt) ?? Date()
            let result = try PolaroidPipeline.reburnCaption(
                squareJPEG: data,
                captionMode: mode,
                dateFormat: burnFormat,
                dateCase: burnCase,
                customText: custom,
                captionFont: font,
                captionFontSize: fontSize,
                captionHighlight: useHighlight,
                date: burnDate,
                filmStock: record.filmStock,
                filmStrength: record.filmStrength,
                serendipitySeed: currentID
            )
            try store.updateCaption(
                id: currentID,
                caption: result.caption,
                captionMode: mode,
                captionFont: font,
                captionFontSize: fontSize,
                captionHighlight: useHighlight,
                captionLetterCase: burnCase,
                dateFormat: burnFormat,
                polaroidPNG: result.png
            )
            bust += 1
            ThumbnailCache.invalidate(url: store.polaroidURL(for: currentID))
            lastApplyCompletedAt = Date()
            reload()
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    @MainActor
    private func prepareShare() async {
        do {
            let image: UIImage
            if showingBackFace {
                let back = store.backURL(for: currentID)
                if FileManager.default.fileExists(atPath: back.path),
                   let loaded = UIImage(contentsOfFile: back.path)
                {
                    image = loaded
                } else if let record, record.hasBackNote, let note = record.backNote {
                    image = try PolaroidPipeline.renderBack(
                        note: note,
                        font: record.backFont,
                        fontSize: record.backFontSize,
                        letterCase: record.backLetterCase
                    )
                } else {
                    image = try PolaroidPipeline.renderBlankBack()
                }
            } else {
                guard let loaded = UIImage(contentsOfFile: store.polaroidURL(for: currentID).path) else {
                    throw PipelineError.decodeFailed
                }
                image = loaded
            }
            sharePayload = SharePayload(items: [image])
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}
