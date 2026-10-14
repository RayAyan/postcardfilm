import ImageIO
import UIKit

/// Path-keyed downsampled image cache so gallery / Process do not keep full PNG bitmaps.
enum ThumbnailCache {
    /// Grid cells (~⅓ screen); keeps scroll light on older devices.
    static let gridMaxPixel = 480
    /// Process display near canvas long-edge; share/download still read full files.
    static let processMaxPixel = 1400

    private static let knownMaxPixels = [gridMaxPixel, processMaxPixel]

    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 160
        // ~64 MB of decoded RGBA before eviction.
        c.totalCostLimit = 64 * 1024 * 1024
        return c
    }()

    private static let decodeQueue = DispatchQueue(
        label: "com.postcardfilm.thumbnail-decode",
        qos: .userInitiated,
        attributes: .concurrent
    )

    /// Sync cache hit only — never touches disk.
    static func cachedImage(at url: URL, refreshToken: Int = 0, maxPixel: Int = gridMaxPixel) -> UIImage? {
        cache.object(forKey: cacheKey(url: url, refreshToken: refreshToken, maxPixel: maxPixel))
    }

    /// Sync decode (tests / rare callers). Prefer `loadImage` from UI.
    static func image(at url: URL, refreshToken: Int = 0, maxPixel: Int = gridMaxPixel) -> UIImage? {
        let key = cacheKey(url: url, refreshToken: refreshToken, maxPixel: maxPixel)
        if let hit = cache.object(forKey: key) {
            return hit
        }
        guard let image = decodeDownsampled(url: url, maxPixel: maxPixel) else { return nil }
        cache.setObject(image, forKey: key, cost: byteCost(of: image))
        return image
    }

    /// Off-main decode; returns cached hit immediately when warm.
    static func loadImage(at url: URL, refreshToken: Int = 0, maxPixel: Int = gridMaxPixel) async -> UIImage? {
        let key = cacheKey(url: url, refreshToken: refreshToken, maxPixel: maxPixel)
        if let hit = cache.object(forKey: key) {
            return hit
        }
        return await withCheckedContinuation { continuation in
            decodeQueue.async {
                if let hit = cache.object(forKey: key) {
                    continuation.resume(returning: hit)
                    return
                }
                let image = decodeDownsampled(url: url, maxPixel: maxPixel)
                if let image {
                    cache.setObject(image, forKey: key, cost: byteCost(of: image))
                }
                continuation.resume(returning: image)
            }
        }
    }

    /// Warm cache off the main thread (read-only; never touches print folders beyond reading PNGs).
    static func prefetch(urls: [URL], refreshToken: Int = 0, maxPixel: Int = gridMaxPixel) {
        let unique = urls.filter { url in
            cache.object(forKey: cacheKey(url: url, refreshToken: refreshToken, maxPixel: maxPixel)) == nil
        }
        guard !unique.isEmpty else { return }
        decodeQueue.async {
            for url in unique {
                let key = cacheKey(url: url, refreshToken: refreshToken, maxPixel: maxPixel)
                if cache.object(forKey: key) != nil { continue }
                guard let image = decodeDownsampled(url: url, maxPixel: maxPixel) else { continue }
                cache.setObject(image, forKey: key, cost: byteCost(of: image))
            }
        }
    }

    static func invalidate(url: URL? = nil) {
        if let url {
            for token in 0 ... 32 {
                for maxPixel in knownMaxPixels {
                    cache.removeObject(
                        forKey: cacheKey(url: url, refreshToken: token, maxPixel: maxPixel)
                    )
                }
            }
        } else {
            cache.removeAllObjects()
        }
    }

    private static func decodeDownsampled(url: URL, maxPixel: Int) -> UIImage? {
        let capped = max(maxPixel, 1)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: capped,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private static func byteCost(of image: UIImage) -> Int {
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)
        return max(width * height * 4, 1)
    }

    private static func cacheKey(url: URL, refreshToken: Int, maxPixel: Int) -> NSString {
        "\(url.path)#\(refreshToken)#\(maxPixel)" as NSString
    }
}
