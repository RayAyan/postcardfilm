import SwiftUI

struct ProcessView: View {
    let id: String
    let openedFromCapture: Bool

    @EnvironmentObject private var store: PolaroidStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.dismiss) private var dismiss

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
    @State private var draftBackNote = ""
    @State private var draftBackFont: CaptionFont = .script
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
    @State private var sharePayload: SharePayload?

    private var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    init(id: String, openedFromCapture: Bool) {
        self.id = id
        self.openedFromCapture = openedFromCapture
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
            } else if let record {
                content(record)
            } else if openedFromCapture {
                content(nil)
            } else {
                ProgressView()
                    .tint(AppTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.surface.ignoresSafeArea())
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
        .confirmationDialog("delete this print?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("delete", role: .destructive) { performDelete() }
            Button("cancel", role: .cancel) {}
        }
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
        .sheet(isPresented: $showCaptionSheet) {
            CaptionEditSheet(
                draftMode: $draftMode,
                draftCustom: $draftCustom,
                draftFont: $draftFont,
                draftFontSize: $draftFontSize,
                draftCase: $draftCase,
                onCancel: { showCaptionSheet = false },
                onSave: { Task { await saveCaption() } }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showBackNoteSheet) {
            BackNoteSheet(
                draftNote: $draftBackNote,
                draftFont: $draftBackFont,
                onCancel: { showBackNoteSheet = false },
                onSave: { Task { await saveBackNote() } }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $sharePayload) { payload in
            ActivityShareSheet(items: payload.items)
        }
        .onAppear { reload() }
        .onChange(of: store.items) { _, _ in
            reload()
        }
        .onDisappear { saveResetTask?.cancel() }
    }

    private func content(_ record: PolaroidRecord?) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            Button {
                guard let record, !isDeveloping, !isFlipping else { return }
                if isFlipped {
                    draftBackNote = record.backNote ?? ""
                    draftBackFont = record.backFont
                    showBackNoteSheet = true
                } else {
                    draftMode = record.captionMode
                    draftCustom = record.captionMode == .custom ? record.caption : ""
                    draftFont = record.captionFont
                    draftFontSize = record.captionFontSize
                    draftCase = inferredCase(for: record)
                    showCaptionSheet = true
                }
            } label: {
                flipCard(record)
                    .padding(.horizontal, 20)
            }
            .disabled(isDeveloping || isFlipping || record == nil)
            .accessibilityLabel(cardAccessibility(record))

            Text(hintText)
                .font(AppType.caption(12))
                .appChromeText()
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.top, 10)

            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 16) {
                    highlightButton

                    Spacer(minLength: 0)

                    HStack(spacing: 16) {
                        actionButton(systemName: "square.and.arrow.up", label: "share print") {
                            Task { await prepareShare() }
                        }
                        .disabled(isDeveloping || isFlipping || isSaving || record == nil)
                        actionButton(systemName: "trash", label: "delete print") {
                            showDeleteConfirm = true
                        }
                        .disabled(isDeveloping || record == nil)
                        actionButton(
                            systemName: saved ? "checkmark" : "square.and.arrow.down",
                            label: saved
                                ? "saved to photos"
                                : (isFlipped ? "download back to photos" : "download front to photos"),
                            symbolOffsetY: saved ? 0 : -1.5
                        ) {
                            Task { await download() }
                        }
                        .disabled(isDeveloping || isSaving || record == nil)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private var highlightOn: Bool {
        record?.captionHighlight ?? true
    }

    private var highlightButton: some View {
        Button {
            Task { await toggleHighlight() }
        } label: {
            Image(systemName: "highlighter")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(highlightOn ? AppTheme.graphite : AppTheme.textPrimary)
                .frame(width: AppTheme.hitTarget, height: AppTheme.hitTarget)
                .background {
                    if highlightOn {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(red: 1, green: 235 / 255, blue: 120 / 255).opacity(0.85))
                            .frame(width: 34, height: 34)
                    }
                }
        }
        .accessibilityLabel(highlightOn ? "remove highlight" : "add highlight")
        .disabled(isDeveloping || isReburning || isFlipped || record == nil)
        .opacity(isFlipped ? 0.35 : 1)
    }

    private var hintText: String {
        if isDeveloping { return Brand.developing }
        return isFlipped ? Brand.backHint : Brand.processHint
    }

    private func cardAccessibility(_ record: PolaroidRecord?) -> String {
        guard let record, !isDeveloping else { return "Developing" }
        if isFlipped {
            if record.hasBackNote {
                return "Back of print, \(record.backNote ?? "")"
            }
            return "Back of print, blank"
        }
        if record.caption.isEmpty {
            return "Edit caption, blank"
        }
        return "Edit caption, currently \(record.caption)"
    }

    @ViewBuilder
    private func flipCard(_ record: PolaroidRecord?) -> some View {
        let showingBack = flipAngle >= 90
        ZStack {
            if showingBack, let record {
                backFace(record)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            } else {
                frontFace
            }
        }
        .rotation3DEffect(
            .degrees(flipAngle),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.6
        )
        .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
    }

    private var frontFace: some View {
        PolaroidThumb(url: store.polaroidURL(for: id), refreshToken: bust)
            .frame(maxWidth: .infinity)
            .overlay {
                if isDeveloping {
                    DevelopingOverlay(
                        reduceMotion: reduceMotion,
                        labelHold: 1.5,
                        fadeDuration: 3.0,
                        printReady: record != nil
                    ) {
                        overlayElapsed = true
                        maybeRevealPrint()
                    }
                }
            }
            .clipped()
    }

    @ViewBuilder
    private func backFace(_ record: PolaroidRecord) -> some View {
        let url = store.backURL(for: id)
        if record.hasBackNote, FileManager.default.fileExists(atPath: url.path) {
            PolaroidThumb(url: url, refreshToken: backBust)
                .frame(maxWidth: .infinity)
        } else {
            blankBackPlaceholder
        }
    }

    private var blankBackPlaceholder: some View {
        let layout = FrameGeometry.computeFrameLayout()
        let aspect = CGFloat(layout.canvasWidth) / CGFloat(layout.canvasHeight)
        let insetFraction = CGFloat(layout.side) * 0.55 / CGFloat(layout.canvasWidth)
        return Color.clear
            .aspectRatio(aspect, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.paper)
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
            )
    }

    private func actionButton(
        systemName: String,
        label: String,
        symbolOffsetY: CGFloat = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22))
                .foregroundStyle(AppTheme.textPrimary)
                .offset(y: symbolOffsetY)
                .frame(width: AppTheme.hitTarget, height: AppTheme.hitTarget)
        }
        .accessibilityLabel(label)
    }

    private func flip() {
        guard !isFlipping else { return }
        isFlipping = true
        Haptics.lightTap()

        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.15)) {
                isFlipped.toggle()
                flipAngle = isFlipped ? 180 : 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                isFlipping = false
            }
            return
        }

        let target = isFlipped ? 0.0 : 180.0
        withAnimation(.easeInOut(duration: 0.45)) {
            flipAngle = target
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isFlipped = target == 180
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
            isFlipping = false
        }
    }

    private func reload() {
        if let item = store.polaroid(id: id) {
            let wasNil = record == nil
            record = item
            missing = false
            if wasNil { bust += 1 }
            maybeRevealPrint()
        } else if openedFromCapture {
            missing = false
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
            try store.delete(id: id)
            dismiss()
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func inferredCase(for record: PolaroidRecord) -> DateCaseStyle {
        let captureDate = Caption.parseISODate(record.createdAt) ?? Date()
        switch record.captionMode {
        case .date:
            let sentence = Caption.formatDate(
                captureDate,
                format: settingsStore.settings.dateFormat,
                letterCase: .sentence
            )
            return record.caption == sentence ? .sentence : settingsStore.settings.dateCase
        case .custom:
            return record.caption == DateCaseStyle.sentence.apply(record.caption)
                ? .sentence
                : .lowercase
        case .blank:
            return settingsStore.settings.dateCase
        }
    }

    @MainActor
    private func download() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        let result: PhotoLibrarySaveResult
        if isFlipped {
            let back = store.backURL(for: id)
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
            result = await PhotoLibrarySaver.saveImage(at: store.polaroidURL(for: id))
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

    private func saveCaption() async {
        var custom = draftCustom
        if draftMode == .custom {
            custom = draftCase.apply(Caption.truncateCaption(draftCustom))
        }
        await reburnFront(
            mode: draftMode,
            custom: custom,
            font: draftFont,
            fontSize: draftFontSize,
            dateCase: draftCase
        )
        showCaptionSheet = false
    }

    private func toggleHighlight() async {
        guard let record, !isFlipped else { return }
        Haptics.lightTap()
        let custom = record.captionMode == .custom ? record.caption : ""
        await reburnFront(
            mode: record.captionMode,
            custom: custom,
            font: record.captionFont,
            fontSize: record.captionFontSize,
            highlight: !record.captionHighlight
        )
    }

    private func saveBackNote() async {
        guard !isReburning else { return }
        isReburning = true
        defer { isReburning = false }
        do {
            let trimmed = Caption.truncateBackNote(draftBackNote)
            if trimmed.isEmpty {
                try store.updateBackNote(
                    id: id,
                    backNote: nil,
                    backFont: draftBackFont,
                    backPNG: nil
                )
            } else {
                let image = try PolaroidPipeline.renderBack(note: trimmed, font: draftBackFont)
                guard let png = image.pngData() else {
                    throw PipelineError.encodeFailed
                }
                try store.updateBackNote(
                    id: id,
                    backNote: trimmed,
                    backFont: draftBackFont,
                    backPNG: png
                )
            }
            backBust += 1
            reload()
            showBackNoteSheet = false
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
        highlight: Bool? = nil
    ) async {
        guard let record, !isReburning else { return }
        isReburning = true
        defer { isReburning = false }
        let useHighlight = highlight ?? record.captionHighlight
        do {
            let data = try Data(contentsOf: store.originalURL(for: id))
            let burnDate = Caption.parseISODate(record.createdAt) ?? Date()
            let burnCase = dateCase ?? settingsStore.settings.dateCase
            let result = try PolaroidPipeline.reburnCaption(
                squareJPEG: data,
                captionMode: mode,
                dateFormat: settingsStore.settings.dateFormat,
                dateCase: burnCase,
                customText: custom,
                captionFont: font,
                captionFontSize: fontSize,
                captionHighlight: useHighlight,
                date: burnDate,
                filmStock: record.filmStock,
                filmStrength: record.filmStrength,
                serendipitySeed: id
            )
            try store.updateCaption(
                id: id,
                caption: result.caption,
                captionMode: mode,
                captionFont: font,
                captionFontSize: fontSize,
                captionHighlight: useHighlight,
                polaroidPNG: result.png
            )
            bust += 1
            ThumbnailCache.invalidate(url: store.polaroidURL(for: id))
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
            if isFlipped {
                let back = store.backURL(for: id)
                if FileManager.default.fileExists(atPath: back.path),
                   let loaded = UIImage(contentsOfFile: back.path)
                {
                    image = loaded
                } else if let record, record.hasBackNote, let note = record.backNote {
                    image = try PolaroidPipeline.renderBack(note: note, font: record.backFont)
                } else {
                    image = try PolaroidPipeline.renderBlankBack()
                }
            } else {
                guard let loaded = UIImage(contentsOfFile: store.polaroidURL(for: id).path) else {
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

private struct CaptionEditSheet: View {
    @Binding var draftMode: CaptionMode
    @Binding var draftCustom: String
    @Binding var draftFont: CaptionFont
    @Binding var draftFontSize: CaptionFontSize
    @Binding var draftCase: DateCaseStyle
    var onCancel: () -> Void
    var onSave: () -> Void

    @State private var showCustomPrompt = false

    var body: some View {
        NavigationStack {
            List {
                Section("strip text") {
                    ForEach(CaptionMode.allCases) { mode in
                        Button {
                            if mode == .custom {
                                showCustomPrompt = true
                            } else {
                                draftMode = mode
                            }
                        } label: {
                            HStack {
                                Text(mode.label)
                                    .font(AppType.body(17))
                                    .appChromeText()
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                if draftMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                            }
                            .frame(minHeight: AppTheme.hitTarget)
                        }
                    }
                    if draftMode == .custom, !draftCustom.isEmpty {
                        Text(draftCustom)
                            .font(AppType.body(15))
                            .foregroundStyle(AppTheme.textSecondary)
                            .onTapGesture { showCustomPrompt = true }
                    }
                }

                Section("font") {
                    ForEach(CaptionFont.allCases) { font in
                        Button {
                            draftFont = font
                        } label: {
                            HStack {
                                Text(font.label)
                                    .font(Font(font.previewFont()))
                                    .appChromeText()
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                if draftFont == font {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                            }
                            .frame(minHeight: AppTheme.hitTarget)
                        }
                    }
                }

                Section("size") {
                    ForEach(CaptionFontSize.allCases) { size in
                        Button {
                            draftFontSize = size
                        } label: {
                            HStack {
                                Text(size.label)
                                    .font(AppType.body(17))
                                    .appChromeText()
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                if draftFontSize == size {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                            }
                            .frame(minHeight: AppTheme.hitTarget)
                        }
                    }
                }

                Section("letter case") {
                    ForEach(DateCaseStyle.allCases) { style in
                        Button {
                            draftCase = style
                        } label: {
                            HStack {
                                Text(style.apply(style.label))
                                    .font(AppType.body(17))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                if draftCase == style {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                            }
                            .frame(minHeight: AppTheme.hitTarget)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.surface)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save", action: onSave)
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showCustomPrompt) {
                CustomCaptionPrompt(
                    text: $draftCustom,
                    onCancel: { showCustomPrompt = false },
                    onSave: {
                        draftMode = .custom
                        draftCustom = Caption.truncateCaption(draftCustom)
                        showCustomPrompt = false
                    }
                )
            }
        }
    }
}

private struct BackNoteSheet: View {
    @Binding var draftNote: String
    @Binding var draftFont: CaptionFont
    var onCancel: () -> Void
    var onSave: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("note") {
                    TextEditor(text: $draftNote)
                        .font(Font(draftFont.previewFont(size: 17)))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(minHeight: 140)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
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
                }

                Section("font") {
                    ForEach(CaptionFont.allCases) { font in
                        Button {
                            draftFont = font
                        } label: {
                            HStack {
                                Text(font.label)
                                    .font(Font(font.previewFont()))
                                    .appChromeText()
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                if draftFont == font {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                            }
                            .frame(minHeight: AppTheme.hitTarget)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.surface.ignoresSafeArea())
            .navigationTitle("back note")
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
    }
}
