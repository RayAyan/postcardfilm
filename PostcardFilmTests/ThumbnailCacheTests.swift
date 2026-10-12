import UIKit
import XCTest
@testable import PostcardFilm

final class ThumbnailCacheTests: XCTestCase {
    func testDownsampledDecodeRespectsMaxPixel() throws {
        let url = try writeTempPNG(size: CGSize(width: 1200, height: 1600))
        defer { try? FileManager.default.removeItem(at: url) }

        ThumbnailCache.invalidate(url: url)
        let maxPixel = 64
        let image = try XCTUnwrap(
            ThumbnailCache.image(at: url, refreshToken: 0, maxPixel: maxPixel)
        )
        let longEdge = max(
            Int(image.size.width * image.scale),
            Int(image.size.height * image.scale)
        )
        XCTAssertLessThanOrEqual(longEdge, maxPixel)
        XCTAssertGreaterThan(longEdge, 0)
    }

    func testCachedImageDoesNotHitDiskAfterWarm() throws {
        let url = try writeTempPNG(size: CGSize(width: 200, height: 200))
        defer { try? FileManager.default.removeItem(at: url) }

        ThumbnailCache.invalidate(url: url)
        XCTAssertNil(ThumbnailCache.cachedImage(at: url, maxPixel: 80))
        _ = try XCTUnwrap(ThumbnailCache.image(at: url, maxPixel: 80))
        XCTAssertNotNil(ThumbnailCache.cachedImage(at: url, maxPixel: 80))
    }

    private func writeTempPNG(size: CGSize) throws -> URL {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        let data = try XCTUnwrap(image.pngData())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("thumb-cache-\(UUID().uuidString).png")
        try data.write(to: url)
        return url
    }
}
