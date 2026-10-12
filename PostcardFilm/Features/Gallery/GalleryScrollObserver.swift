import SwiftUI
import UIKit

/// Holds the gallery `UIScrollView` so the rail can scrub by content offset.
final class GalleryScrollScrubber {
    weak var scrollView: UIScrollView?

    func scrub(to fraction: CGFloat) {
        guard let scroll = scrollView else { return }
        let inset = scroll.adjustedContentInset
        let contentH = scroll.contentSize.height
        let viewportH = scroll.bounds.height - inset.top - inset.bottom
        let overflow = contentH - viewportH
        guard overflow > 1 else { return }
        let clamped = min(max(fraction, 0), 1)
        let y = clamped * overflow - inset.top
        scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: y), animated: false)
    }
}

/// Reads the enclosing `UIScrollView` so the gallery rail thumb tracks finger scroll reliably
/// (SwiftUI LazyVGrid geometry prefs often under-report content height).
struct GalleryScrollObserver: UIViewRepresentable {
    var scrubber: GalleryScrollScrubber
    var onScroll: (_ offsetY: CGFloat, _ contentHeight: CGFloat, _ viewportHeight: CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(scrubber: scrubber, onScroll: onScroll)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.scrubber = scrubber
        context.coordinator.onScroll = onScroll
        DispatchQueue.main.async {
            context.coordinator.attach(from: uiView)
        }
    }

    final class Coordinator {
        var scrubber: GalleryScrollScrubber
        var onScroll: (CGFloat, CGFloat, CGFloat) -> Void
        private weak var scrollView: UIScrollView?
        private var observation: NSKeyValueObservation?

        init(scrubber: GalleryScrollScrubber, onScroll: @escaping (CGFloat, CGFloat, CGFloat) -> Void) {
            self.scrubber = scrubber
            self.onScroll = onScroll
        }

        func attach(from view: UIView) {
            guard let scroll = view.enclosingScrollView() else { return }
            scrubber.scrollView = scroll
            if scrollView === scroll { return }
            observation = nil
            scrollView = scroll
            observation = scroll.observe(\.contentOffset, options: [.initial, .new]) { [weak self] scroll, _ in
                guard let self else { return }
                let inset = scroll.adjustedContentInset
                let offsetY = scroll.contentOffset.y + inset.top
                let contentH = scroll.contentSize.height
                let viewportH = scroll.bounds.height - inset.top - inset.bottom
                let deliver = {
                    self.onScroll(offsetY, contentH, viewportH)
                }
                if Thread.isMainThread {
                    deliver()
                } else {
                    DispatchQueue.main.async(execute: deliver)
                }
            }
        }

        deinit {
            observation?.invalidate()
        }
    }
}

private extension UIView {
    func enclosingScrollView() -> UIScrollView? {
        var current: UIView? = self
        while let view = current {
            if let scroll = view as? UIScrollView {
                return scroll
            }
            current = view.superview
        }
        return nil
    }
}
