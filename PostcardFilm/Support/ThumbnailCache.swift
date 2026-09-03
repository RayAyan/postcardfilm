import UIKit

/// Small path-keyed image cache so gallery cells do not re-decode PNG on every scroll frame.
enum ThumbnailCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 120
        return c
    }()

    static func image(at url: URL, refreshToken: Int = 0) -> UIImage? {
        let key = "\(url.path)#\(refreshToken)" as NSString
        if let hit = cache.object(forKey: key) {
            return hit
        }
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    static func invalidate(url: URL? = nil) {
        if let url {
            // Drop common tokens; full wipe is fine for small galleries after delete/reburn.
            cache.removeObject(forKey: url.path as NSString)
            for token in 0 ... 32 {
                cache.removeObject(forKey: "\(url.path)#\(token)" as NSString)
            }
        } else {
            cache.removeAllObjects()
        }
    }
}
