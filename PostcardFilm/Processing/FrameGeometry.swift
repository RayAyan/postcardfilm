import Foundation

enum FrameConstants {
    /// Side/top border as fraction of image (square) side — thicker cream stock.
    static let sideRatio: Double = 0.09
    /// Bottom strip as fraction of total canvas height — closer to Polaroid 600.
    static let bottomRatio: Double = 0.24
    static let imageSide: Int = 1080
}

struct FrameLayout: Equatable {
    var imageSide: Int
    var side: Int
    var top: Int
    var bottom: Int
    var canvasWidth: Int
    var canvasHeight: Int
    var imageX: Int
    var imageY: Int
    var stripX: Int
    var stripY: Int
    var stripWidth: Int
    var stripHeight: Int
}

enum FrameGeometry {
    /// Width / height of the default Polaroid canvas — one source for Process, Gallery, thumbs.
    static var canvasAspect: CGFloat {
        let layout = computeFrameLayout()
        return CGFloat(layout.canvasWidth) / CGFloat(layout.canvasHeight)
    }

    /// Compute Polaroid canvas layout for a square photo.
    static func computeFrameLayout(imageSide: Int = FrameConstants.imageSide) -> FrameLayout {
        let side = Int(round(Double(imageSide) * FrameConstants.sideRatio))
        let top = side
        let canvasWidth = imageSide + side * 2
        let bottom = Int(
            round(
                (FrameConstants.bottomRatio / (1 - FrameConstants.bottomRatio))
                    * Double(imageSide + top)
            )
        )
        let canvasHeight = imageSide + top + bottom

        return FrameLayout(
            imageSide: imageSide,
            side: side,
            top: top,
            bottom: bottom,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            imageX: side,
            imageY: top,
            stripX: side,
            stripY: top + imageSide,
            stripWidth: imageSide,
            stripHeight: bottom
        )
    }

    static func bottomRatio(of layout: FrameLayout) -> Double {
        Double(layout.bottom) / Double(layout.canvasHeight)
    }

    static func sideRatio(of layout: FrameLayout) -> Double {
        Double(layout.side) / Double(layout.imageSide)
    }
}
