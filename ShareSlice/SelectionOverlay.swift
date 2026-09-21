import AppKit

private final class SelectionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class SelectionOverlay {
    private let panel: NSPanel

    init(screen: NSScreen, region: CGRect, ratio: AspectRatio, completion: @escaping (CGRect?) -> Void) {
        panel = SelectionPanel(contentRect: screen.frame, styleMask: [.borderless],
                               backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size),
                                 region: region, ratio: ratio, completion: completion)
        panel.contentView = view
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(view)
    }

    func close() { panel.close() }
}

private final class SelectionView: NSView {
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    private var region: CGRect
    private let ratio: AspectRatio
    private let completion: (CGRect?) -> Void
    private var start = CGPoint.zero
    private var original = CGRect.zero
    private var anchor: CGPoint?
    private var moving = false

    init(frame: CGRect, region: CGRect, ratio: AspectRatio, completion: @escaping (CGRect?) -> Void) {
        self.region = region
        self.ratio = ratio
        self.completion = completion
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    private var corners: [CGPoint] {
        [CGPoint(x: region.minX, y: region.minY), CGPoint(x: region.maxX, y: region.minY),
         CGPoint(x: region.minX, y: region.maxY), CGPoint(x: region.maxX, y: region.maxY)]
    }

    override func draw(_ dirtyRect: NSRect) {
        let shade = NSBezierPath(rect: bounds)
        shade.append(NSBezierPath(rect: region))
        shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.45).setFill()
        shade.fill()
        let outline = NSBezierPath(rect: region)
        NSColor.black.setStroke()
        outline.lineWidth = 7
        outline.stroke()
        NSColor.systemCyan.setStroke()
        outline.lineWidth = 4
        outline.stroke()
        for point in corners {
            let handle = NSBezierPath(ovalIn: CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16))
            NSColor.systemCyan.setFill()
            handle.fill()
            NSColor.black.setStroke()
            handle.lineWidth = 2
            handle.stroke()
        }
        let text = "Drag outside to draw • Drag inside to move • Drag corners to resize\nReturn to use region • Escape to cancel • \(ratio.rawValue)"
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let box = CGRect(x: max(12, (bounds.width - 620) / 2), y: 30,
                         width: min(620, bounds.width - 24), height: 64)
        NSColor.black.withAlphaComponent(0.8).setFill()
        NSBezierPath(roundedRect: box, xRadius: 8, yRadius: 8).fill()
        (text as NSString).draw(in: box.insetBy(dx: 8, dy: 10), withAttributes: [
            .font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.white, .paragraphStyle: style
        ])
    }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        original = region
        if let index = corners.firstIndex(where: { hypot($0.x - start.x, $0.y - start.y) <= 22 }) {
            anchor = corners[3 - index]
            moving = false
        } else if region.insetBy(dx: -6, dy: -6).contains(start) {
            moving = true
            anchor = nil
        } else {
            moving = false
            anchor = start
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if moving {
            region = RegionGeometry.constrained(original.offsetBy(dx: point.x - start.x, dy: point.y - start.y),
                                                 to: bounds.size, ratio: ratio.value)
        } else if let anchor {
            region = RegionGeometry.drawn(from: anchor, to: point, in: bounds.size, ratio: ratio.value)
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if region.width < 32 || region.height < 32 { region = original }
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76: completion(region)
        case 53: completion(nil)
        default: super.keyDown(with: event)
        }
    }
}
