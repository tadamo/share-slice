import AppKit
import AVFoundation

final class PreviewView: NSView {
    let displayLayer = AVSampleBufferDisplayLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        displayLayer.videoGravity = .resizeAspect
        layer?.addSublayer(displayLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.frame = bounds
        CATransaction.commit()
    }
}

@MainActor
final class PreviewWindow: NSObject, NSWindowDelegate {
    let view = PreviewView(frame: .zero)
    private let window: NSWindow
    var onClose: (() -> Void)?

    init(size: CGSize) {
        let available = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1000, height: 700)
        let scale = min(1, available.width * 0.75 / size.width, available.height * 0.75 / size.height)
        window = NSWindow(contentRect: CGRect(origin: .zero,
                                              size: CGSize(width: size.width * scale, height: size.height * scale)),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        super.init()
        window.title = "Share Slice Preview"
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.contentAspectRatio = size
        window.delegate = self
        window.center()
    }

    func updateAspectRatio(_ size: CGSize) {
        guard window.contentAspectRatio != size else { return }
        let current = window.contentLayoutRect.size
        let available = window.screen?.visibleFrame.size ?? current
        let width = min(current.width, available.width)
        let height = width * size.height / size.width
        let scale = min(1, max(1, available.height - 40) / height)
        window.contentAspectRatio = size
        window.setContentSize(CGSize(width: width * scale, height: height * scale))
    }

    func show() { window.makeKeyAndOrderFront(nil) }
    func close() {
        window.delegate = nil
        window.close()
        view.displayLayer.flushAndRemoveImage()
    }

    func windowWillClose(_ notification: Notification) { onClose?() }
}
