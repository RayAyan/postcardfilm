import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum PolaroidPipeline {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    struct Result {
        let originalJPEG: Data
        let polaroidPNG: Data
        let caption: String
        let captionMode: CaptionMode
        let filmStock: FilmStock
        /// Per-print expression strength (1.0 = full stock / legacy).
        let filmStrength: Double
    }

    static func processCapture(
        image: UIImage,
        captionMode: CaptionMode,
        dateFormat: DateFormatOption,
        dateCase: DateCaseStyle = .lowercase,
        customText: String,
        captionFont: CaptionFont = .serif,
        captionFontSize: CaptionFontSize = .medium,
        captionHighlight: Bool = true,
        date: Date = Date(),
        filmStock: FilmStock? = nil,
        filmStrength: Double? = nil,
        serendipitySeed: String = ""
    ) throws -> Result {
        let caption = Caption.resolveCaptionText(
            mode: captionMode,
            dateFormat: dateFormat,
            dateCase: dateCase,
            customText: customText,
            date: date
        )
        let square = try squareCrop(image: image, side: FrameConstants.imageSide)
        guard let jpeg = square.jpegData(compressionQuality: 0.92) else {
            throw PipelineError.encodeFailed
        }
        let stock = filmStock ?? FilmStock.draw()
        let strength = filmStrength ?? FilmExpression.resolve(seed: serendipitySeed, stock: stock)
        let polaroid = try renderPolaroid(
            square: square,
            caption: caption,
            captionFont: captionFont,
            captionFontSize: captionFontSize,
            captionHighlight: captionHighlight,
            filmStock: stock,
            filmStrength: strength,
            serendipitySeed: serendipitySeed
        )
        guard let png = polaroid.pngData() else {
            throw PipelineError.encodeFailed
        }
        return Result(
            originalJPEG: jpeg,
            polaroidPNG: png,
            caption: caption,
            captionMode: captionMode,
            filmStock: stock,
            filmStrength: strength
        )
    }

    static func reburnCaption(
        squareJPEG: Data,
        captionMode: CaptionMode,
        dateFormat: DateFormatOption,
        dateCase: DateCaseStyle = .lowercase,
        customText: String,
        captionFont: CaptionFont = .serif,
        captionFontSize: CaptionFontSize = .medium,
        captionHighlight: Bool = true,
        date: Date,
        filmStock: FilmStock = .onestep,
        filmStrength: Double = FilmExpression.legacyDefault,
        serendipitySeed: String = ""
    ) throws -> (png: Data, caption: String) {
        guard let square = UIImage(data: squareJPEG) else {
            throw PipelineError.decodeFailed
        }
        let caption = Caption.resolveCaptionText(
            mode: captionMode,
            dateFormat: dateFormat,
            dateCase: dateCase,
            customText: customText,
            date: date
        )
        let polaroid = try renderPolaroid(
            square: square,
            caption: caption,
            captionFont: captionFont,
            captionFontSize: captionFontSize,
            captionHighlight: captionHighlight,
            filmStock: filmStock,
            filmStrength: filmStrength,
            serendipitySeed: serendipitySeed
        )
        guard let png = polaroid.pngData() else {
            throw PipelineError.encodeFailed
        }
        return (png, caption)
    }

    // MARK: - Steps

    static func squareCrop(image: UIImage, side: Int) throws -> UIImage {
        guard let cg = image.cgImage else { throw PipelineError.decodeFailed }
        let width = cg.width
        let height = cg.height
        let minSide = min(width, height)
        let originX = (width - minSide) / 2
        let originY = (height - minSide) / 2
        guard let cropped = cg.cropping(to: CGRect(x: originX, y: originY, width: minSide, height: minSide))
        else {
            throw PipelineError.cropFailed
        }
        let square = UIImage(cgImage: cropped, scale: 1, orientation: image.imageOrientation)
        return resize(square, to: CGSize(width: side, height: side))
    }

    private static func resize(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    static func applyGrade(to image: UIImage, recipe: FilmRecipe) throws -> UIImage {
        guard let ciInput = CIImage(image: image) else { throw PipelineError.decodeFailed }

        let expose = CIFilter.exposureAdjust()
        expose.inputImage = ciInput
        expose.ev = Float(recipe.exposureEV + recipe.flashCenterLift * 0.55)
        let exposed = expose.outputImage ?? ciInput

        let matrix = recipe.colorMatrix
        let colorMatrix = CIFilter.colorMatrix()
        colorMatrix.inputImage = exposed
        colorMatrix.rVector = CIVector(x: matrix.r.0, y: matrix.r.1, z: matrix.r.2, w: matrix.r.3)
        colorMatrix.gVector = CIVector(x: matrix.g.0, y: matrix.g.1, z: matrix.g.2, w: matrix.g.3)
        colorMatrix.bVector = CIVector(x: matrix.b.0, y: matrix.b.1, z: matrix.b.2, w: matrix.b.3)
        colorMatrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        colorMatrix.biasVector = CIVector(x: matrix.bias.0, y: matrix.bias.1, z: matrix.bias.2, w: 0)
        let matrixed = colorMatrix.outputImage ?? exposed

        var toned = matrixed
        // CIHighlightShadowAdjust: highlightAmount default 1.0, shadowAmount default 0.0.
        if abs(recipe.highlightAmount - 1.0) > 0.001 || abs(recipe.shadowAmount) > 0.001 {
            let hs = CIFilter.highlightShadowAdjust()
            hs.inputImage = toned
            hs.highlightAmount = Float(recipe.highlightAmount)
            hs.shadowAmount = Float(recipe.shadowAmount)
            toned = hs.outputImage ?? toned
        }

        if abs(recipe.contrast - 1.0) > 0.001 || abs(recipe.saturation - 1.0) > 0.001 {
            let controls = CIFilter.colorControls()
            controls.inputImage = toned
            controls.contrast = Float(recipe.contrast)
            controls.saturation = Float(recipe.saturation)
            controls.brightness = 0
            toned = controls.outputImage ?? toned
        }

        let graded = saturateShadows(toned, knobs: recipe.shadowSaturation)

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = graded
        blur.radius = Float(recipe.blurRadius)

        guard let blurred = blur.outputImage?.cropped(to: ciInput.extent),
              let cg = context.createCGImage(blurred, from: blurred.extent)
        else {
            throw PipelineError.gradeFailed
        }
        return UIImage(cgImage: cg)
    }

    /// House-stock convenience for tests / scripts that still call the old API.
    static func applyGrade(to image: UIImage) throws -> UIImage {
        try applyGrade(to: image, recipe: .onestep)
    }

    /// Boosts saturation only where the frame is dark, leaving sky and cream highlights alone.
    private static func saturateShadows(
        _ image: CIImage,
        knobs: (amount: Double, maskGamma: Double)
    ) -> CIImage {
        let saturated = CIFilter.colorControls()
        saturated.inputImage = image
        saturated.saturation = Float(knobs.amount)

        let gray = CIFilter.colorControls()
        gray.inputImage = image
        gray.saturation = 0

        let invert = CIFilter.colorInvert()
        invert.inputImage = gray.outputImage

        let bias = CIFilter.gammaAdjust()
        bias.inputImage = invert.outputImage
        bias.power = Float(knobs.maskGamma)

        let mask = CIFilter.maskToAlpha()
        mask.inputImage = bias.outputImage

        let blend = CIFilter.blendWithMask()
        blend.inputImage = saturated.outputImage
        blend.backgroundImage = image
        blend.maskImage = mask.outputImage

        return blend.outputImage ?? image
    }

    static func renderPolaroid(
        square: UIImage,
        caption: String,
        captionFont: CaptionFont = .serif,
        captionFontSize: CaptionFontSize = .medium,
        captionHighlight: Bool = true,
        filmStock: FilmStock = .onestep,
        filmStrength: Double = FilmExpression.legacyDefault,
        serendipitySeed: String = ""
    ) throws -> UIImage {
        let scene = FilmScene.measure(square)
        let base = filmStock.recipe(meanLuma: scene.meanLuma, centerBias: scene.centerBias)
        let expressed = FilmExpression.apply(base, strength: filmStrength, stock: filmStock)
        let recipe = FilmSerendipity.vary(
            expressed,
            seed: serendipitySeed,
            stock: filmStock,
            strength: filmStrength
        )
        let graded = try applyGrade(to: square, recipe: recipe)
        let layout = FrameGeometry.computeFrameLayout(imageSide: FrameConstants.imageSide)
        let canvasSize = CGSize(width: layout.canvasWidth, height: layout.canvasHeight)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return renderer.image { ctx in
            let cg = ctx.cgContext
            AppTheme.cardUIColor.setFill()
            cg.fill(CGRect(origin: .zero, size: canvasSize))

            let imageRect = CGRect(
                x: layout.imageX,
                y: layout.imageY,
                width: layout.imageSide,
                height: layout.imageSide
            )
            graded.draw(in: imageRect)

            if recipe.vignetteStrength > 0.01,
               let vignette = makeVignette(in: imageRect, strength: recipe.vignetteStrength)
            {
                vignette.draw(in: imageRect, blendMode: .multiply, alpha: 1)
            }
            if recipe.flashAlpha > 0.01,
               let flash = makeFlashFill(in: imageRect)
            {
                flash.draw(in: imageRect, blendMode: .screen, alpha: recipe.flashAlpha)
            }
            if recipe.leakAlpha > 0.01,
               let leak = makeLightLeak(in: imageRect)
            {
                leak.draw(in: imageRect, blendMode: .screen, alpha: recipe.leakAlpha)
            }
            if recipe.bloomAlpha > 0.01,
               let bloom = makeHighlightBloom(in: imageRect)
            {
                bloom.draw(in: imageRect, blendMode: .screen, alpha: recipe.bloomAlpha)
            }
            if recipe.edgeBurnAmount > 0.01,
               let burn = makeEdgeBurn(in: imageRect, amount: recipe.edgeBurnAmount, seed: serendipitySeed)
            {
                burn.draw(in: imageRect, blendMode: .multiply, alpha: 1)
            }
            if recipe.grainAmount > 0.01,
               let grain = makeSoftGrain(in: imageRect, amount: recipe.grainAmount, seed: serendipitySeed)
            {
                grain.draw(in: imageRect, blendMode: .overlay, alpha: recipe.grainAmount)
            }

            cg.setStrokeColor(UIColor(red: 180 / 255, green: 170 / 255, blue: 155 / 255, alpha: 0.55).cgColor)
            cg.setLineWidth(1.5)
            cg.stroke(imageRect.insetBy(dx: 0.75, dy: 0.75))

            guard !caption.isEmpty else { return }

            let fontSize = CGFloat(layout.stripHeight) * captionFontSize.stripScale
            let font = captionFont.uiFont(size: fontSize)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: AppTheme.graphiteUIColor,
                .kern: captionFont == .typewriter ? 0.5 : -0.3,
            ]
            let textSize = (caption as NSString).size(withAttributes: attrs)
            let textX = CGFloat(layout.stripX)
                + max(8, (CGFloat(layout.stripWidth) - textSize.width) / 2)
            let stripMidY = CGFloat(layout.stripY) + CGFloat(layout.stripHeight) * 0.5
            let textY = stripMidY - font.capHeight * 0.5 - (font.ascender - font.capHeight) * 0.35
            let textOrigin = CGPoint(x: textX, y: textY)

            if captionHighlight {
                let padX: CGFloat = 10
                let padY: CGFloat = 6
                let highlightRect = CGRect(
                    x: textOrigin.x - padX,
                    y: textOrigin.y + font.ascender - font.capHeight - padY * 0.35,
                    width: textSize.width + padX * 2,
                    height: font.capHeight + padY * 2
                )
                let highlighter = UIColor(red: 1, green: 235 / 255, blue: 120 / 255, alpha: 0.45)
                highlighter.setFill()
                let path = UIBezierPath(roundedRect: highlightRect, cornerRadius: highlightRect.height * 0.35)
                path.fill()
            }

            (caption as NSString).draw(at: textOrigin, withAttributes: attrs)
        }
    }

    /// Cream reverse of the print — blank stock with a handwritten note area.
    static func renderBack(
        note: String,
        font: CaptionFont = .script,
        fontSize: CaptionFontSize = .medium,
        letterCase: DateCaseStyle = .lowercase
    ) throws -> UIImage {
        let trimmed = Caption.truncateBackNote(note)
        guard !trimmed.isEmpty else { throw PipelineError.encodeFailed }
        let display = letterCase.apply(trimmed)

        let layout = FrameGeometry.computeFrameLayout(imageSide: FrameConstants.imageSide)
        let canvasSize = CGSize(width: layout.canvasWidth, height: layout.canvasHeight)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return renderer.image { ctx in
            let cg = ctx.cgContext
            Self.drawBackStock(in: cg, canvasSize: canvasSize, layout: layout)

            let margin = CGFloat(layout.side)
            let brandReserve: CGFloat = 56
            let textRect = CGRect(
                x: margin,
                y: margin,
                width: canvasSize.width - margin * 2,
                height: canvasSize.height - margin * 2 - brandReserve
            )

            let bodySize = max(36, CGFloat(layout.stripHeight) * fontSize.backBodyScale)
            let bodyFont = font.uiFont(size: bodySize)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .left
            paragraph.lineBreakMode = .byWordWrapping
            paragraph.lineSpacing = 6

            let attrs: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: AppTheme.graphiteUIColor,
                .paragraphStyle: paragraph,
                .kern: font == .typewriter ? 0.4 : -0.2,
            ]
            let attributed = NSAttributedString(string: display, attributes: attrs)
            attributed.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)

            Self.drawBackWordmark(canvasSize: canvasSize, margin: margin)
        }
    }

    /// Cream reverse with border + wordmark and no note (for download / blank face).
    static func renderBlankBack() throws -> UIImage {
        let layout = FrameGeometry.computeFrameLayout(imageSide: FrameConstants.imageSide)
        let canvasSize = CGSize(width: layout.canvasWidth, height: layout.canvasHeight)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return renderer.image { ctx in
            let cg = ctx.cgContext
            Self.drawBackStock(in: cg, canvasSize: canvasSize, layout: layout)
            Self.drawBackWordmark(canvasSize: canvasSize, margin: CGFloat(layout.side))
        }
    }

    private static func drawBackStock(
        in cg: CGContext,
        canvasSize: CGSize,
        layout: FrameLayout
    ) {
        AppTheme.cardUIColor.setFill()
        cg.fill(CGRect(origin: .zero, size: canvasSize))

        let margin = CGFloat(layout.side)
        let borderInset = margin * 0.55
        let borderRect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: borderInset, dy: borderInset)
        cg.setStrokeColor(AppTheme.graphiteUIColor.withAlphaComponent(0.72).cgColor)
        cg.setLineWidth(2.5)
        cg.stroke(borderRect)
    }

    private static func drawBackWordmark(canvasSize: CGSize, margin: CGFloat) {
        let mark = Brand.wordmark as NSString
        let markFont = CaptionFont.serif.uiFont(size: 22)
        let markAttrs: [NSAttributedString.Key: Any] = [
            .font: markFont,
            .foregroundColor: AppTheme.graphiteUIColor.withAlphaComponent(0.28),
            .kern: 0.8,
        ]
        let markSize = mark.size(withAttributes: markAttrs)
        let markOrigin = CGPoint(
            x: (canvasSize.width - markSize.width) / 2,
            y: canvasSize.height - margin - markSize.height
        )
        mark.draw(at: markOrigin, withAttributes: markAttrs)
    }

    private static func makeVignette(in rect: CGRect, strength: CGFloat = 1) -> UIImage? {
        let edgeAlpha = min(0.72, 0.38 * strength)
        let softStart = max(0.28, 0.5 - 0.12 * (strength - 1))
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [
                UIColor.clear.cgColor,
                UIColor(red: 40 / 255, green: 30 / 255, blue: 20 / 255, alpha: edgeAlpha).cgColor,
            ] as CFArray
            let locations: [CGFloat] = [softStart, 1]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: locations
            ) else { return }
            let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
            cg.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: max(rect.width, rect.height) * 0.72,
                options: [.drawsAfterEndLocation]
            )
        }
    }

    /// Soft cream flash fill from center — subtle, not a white stamp.
    private static func makeFlashFill(in rect: CGRect) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [
                UIColor(red: 1.0, green: 0.97, blue: 0.92, alpha: 0.42).cgColor,
                UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 0.14).cgColor,
                UIColor.clear.cgColor,
            ] as CFArray
            let locations: [CGFloat] = [0, 0.4, 1]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: locations
            ) else { return }
            let center = CGPoint(x: rect.width / 2, y: rect.height * 0.42)
            cg.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: max(rect.width, rect.height) * 0.52,
                options: [.drawsAfterEndLocation]
            )
        }
    }

    /// Warm cream/orange wash from the top-right corner.
    private static func makeLightLeak(in rect: CGRect) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [
                UIColor(red: 1, green: 0.72, blue: 0.35, alpha: 0.55).cgColor,
                UIColor(red: 1, green: 0.85, blue: 0.55, alpha: 0.18).cgColor,
                UIColor.clear.cgColor,
            ] as CFArray
            let locations: [CGFloat] = [0, 0.35, 1]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: locations
            ) else { return }
            let origin = CGPoint(x: rect.width * 0.92, y: rect.height * 0.08)
            cg.drawRadialGradient(
                gradient,
                startCenter: origin,
                startRadius: 0,
                endCenter: origin,
                endRadius: max(rect.width, rect.height) * 0.42,
                options: [.drawsAfterEndLocation]
            )
        }
    }

    /// Tiny highlight bloom near the light-leak corner.
    private static func makeHighlightBloom(in rect: CGRect) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [
                UIColor(red: 1, green: 0.96, blue: 0.88, alpha: 0.65).cgColor,
                UIColor.clear.cgColor,
            ] as CFArray
            let locations: [CGFloat] = [0, 1]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: locations
            ) else { return }
            let origin = CGPoint(x: rect.width * 0.84, y: rect.height * 0.16)
            cg.drawRadialGradient(
                gradient,
                startCenter: origin,
                startRadius: 0,
                endCenter: origin,
                endRadius: max(rect.width, rect.height) * 0.12,
                options: [.drawsAfterEndLocation]
            )
        }
    }

    /// Very soft monochrome grain — seeded so reburn matches.
    private static func makeSoftGrain(in rect: CGRect, amount: CGFloat, seed: String) -> UIImage? {
        let side = max(64, min(256, Int(max(rect.width, rect.height) / 8)))
        var rng = SeededRNG(seed: grainSeed(seed, tag: "grain"))
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let n = UInt8(20 + Int(rng.nextUnit() * 215))
            pixels[i] = n
            pixels[i + 1] = n
            pixels[i + 2] = n
            pixels[i + 3] = 255
        }
        let data = Data(pixels)
        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                  width: side,
                  height: side,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: side * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent
              )
        else { return nil }

        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { _ in
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: rect.size))
            _ = amount
        }
    }

    /// Soft irregular edge burn (roller / undeveloped-edge feel) — not a hard vignette ring.
    private static func makeEdgeBurn(in rect: CGRect, amount: CGFloat, seed: String) -> UIImage? {
        var rng = SeededRNG(seed: grainSeed(seed, tag: "burn"))
        let edges = [0, 1, 2, 3].shuffled(using: &rng).prefix(rng.nextUnit() < 0.55 ? 1 : 2)
        let strength = min(0.35, 0.12 + amount * 0.7)
        let band = max(rect.width, rect.height) * (0.08 + amount * 0.12)

        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            for edge in edges {
                let warm = UIColor(red: 48 / 255, green: 32 / 255, blue: 22 / 255, alpha: strength)
                let colors = [warm.cgColor, UIColor.clear.cgColor] as CFArray
                let locations: [CGFloat] = [0, 1]
                guard let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors,
                    locations: locations
                ) else { continue }

                let start: CGPoint
                let end: CGPoint
                switch edge {
                case 0: // top
                    start = CGPoint(x: rect.width / 2, y: 0)
                    end = CGPoint(x: rect.width / 2, y: band)
                case 1: // bottom
                    start = CGPoint(x: rect.width / 2, y: rect.height)
                    end = CGPoint(x: rect.width / 2, y: rect.height - band)
                case 2: // leading
                    start = CGPoint(x: 0, y: rect.height / 2)
                    end = CGPoint(x: band, y: rect.height / 2)
                default: // trailing
                    start = CGPoint(x: rect.width, y: rect.height / 2)
                    end = CGPoint(x: rect.width - band, y: rect.height / 2)
                }
                cg.drawLinearGradient(gradient, start: start, end: end, options: [])
            }
        }
    }

    private static func grainSeed(_ seed: String, tag: String) -> UInt64 {
        var hash: UInt64 = 0xC0FF_EEF1_1A00
        for byte in (seed + "|" + tag).utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return hash == 0 ? 1 : hash
    }
}

enum PipelineError: LocalizedError {
    case decodeFailed
    case encodeFailed
    case cropFailed
    case gradeFailed

    var errorDescription: String? {
        switch self {
        case .decodeFailed: return "Could not read the photo."
        case .encodeFailed: return "Could not save the Polaroid."
        case .cropFailed: return "Could not crop the photo."
        case .gradeFailed: return "Could not apply the Polaroid look."
        }
    }
}
