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
    }

    static func processCapture(
        image: UIImage,
        captionMode: CaptionMode,
        dateFormat: DateFormatOption,
        dateCase: DateCaseStyle = .lowercase,
        customText: String,
        captionFont: CaptionFont = .serif,
        captionHighlight: Bool = true,
        date: Date = Date()
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
        let polaroid = try renderPolaroid(
            square: square,
            caption: caption,
            captionFont: captionFont,
            captionHighlight: captionHighlight
        )
        guard let png = polaroid.pngData() else {
            throw PipelineError.encodeFailed
        }
        return Result(
            originalJPEG: jpeg,
            polaroidPNG: png,
            caption: caption,
            captionMode: captionMode
        )
    }

    static func reburnCaption(
        squareJPEG: Data,
        captionMode: CaptionMode,
        dateFormat: DateFormatOption,
        dateCase: DateCaseStyle = .lowercase,
        customText: String,
        captionFont: CaptionFont = .serif,
        captionHighlight: Bool = true,
        date: Date
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
            captionHighlight: captionHighlight
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

    static func applyGrade(to image: UIImage) throws -> UIImage {
        guard let ciInput = CIImage(image: image) else { throw PipelineError.decodeFailed }

        let expose = CIFilter.exposureAdjust()
        expose.inputImage = ciInput
        expose.ev = Float(Grade.exposureEV())
        let exposed = expose.outputImage ?? ciInput

        let matrix = Grade.colorMatrix()
        let filter = CIFilter.colorMatrix()
        filter.inputImage = exposed
        filter.rVector = CIVector(x: matrix.r.0, y: matrix.r.1, z: matrix.r.2, w: matrix.r.3)
        filter.gVector = CIVector(x: matrix.g.0, y: matrix.g.1, z: matrix.g.2, w: matrix.g.3)
        filter.bVector = CIVector(x: matrix.b.0, y: matrix.b.1, z: matrix.b.2, w: matrix.b.3)
        filter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        filter.biasVector = CIVector(x: matrix.bias.0, y: matrix.bias.1, z: matrix.bias.2, w: 0)

        let graded = filter.outputImage.map(saturateShadows) ?? filter.outputImage

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = graded
        blur.radius = 0.55

        guard let blurred = blur.outputImage?.cropped(to: ciInput.extent),
              let cg = context.createCGImage(blurred, from: blurred.extent)
        else {
            throw PipelineError.gradeFailed
        }
        return UIImage(cgImage: cg)
    }

    /// Boosts saturation only where the frame is dark, leaving sky and cream highlights alone.
    private static func saturateShadows(_ image: CIImage) -> CIImage {
        let knobs = Grade.shadowSaturation()

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
        captionHighlight: Bool = true
    ) throws -> UIImage {
        let graded = try applyGrade(to: square)
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

            if let vignette = makeVignette(in: imageRect) {
                vignette.draw(in: imageRect, blendMode: .multiply, alpha: 1)
            }
            if let leak = makeLightLeak(in: imageRect) {
                leak.draw(in: imageRect, blendMode: .screen, alpha: 0.55)
            }
            if let bloom = makeHighlightBloom(in: imageRect) {
                bloom.draw(in: imageRect, blendMode: .screen, alpha: 0.7)
            }

            cg.setStrokeColor(UIColor(red: 180 / 255, green: 170 / 255, blue: 155 / 255, alpha: 0.55).cgColor)
            cg.setLineWidth(1.5)
            cg.stroke(imageRect.insetBy(dx: 0.75, dy: 0.75))

            guard !caption.isEmpty else { return }

            let fontSize = CGFloat(layout.stripHeight) * 0.30
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
        font: CaptionFont = .script
    ) throws -> UIImage {
        let trimmed = Caption.truncateBackNote(note)
        guard !trimmed.isEmpty else { throw PipelineError.encodeFailed }

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

            let bodySize = max(36, CGFloat(layout.stripHeight) * 0.22)
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
            let attributed = NSAttributedString(string: trimmed, attributes: attrs)
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

    private static func makeVignette(in rect: CGRect) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [
                UIColor.clear.cgColor,
                UIColor(red: 40 / 255, green: 30 / 255, blue: 20 / 255, alpha: 0.38).cgColor,
            ] as CFArray
            let locations: [CGFloat] = [0.5, 1]
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
