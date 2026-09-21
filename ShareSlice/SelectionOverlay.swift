import AppKit

@MainActor
final class RegionOutline {
    private let screen: NSScreen
    private let panel: NSPanel
    private let outline = RegionOutlineView()
    private var handles: [NSPanel] = []
    private var region: CGRect = .zero
    private var ratio: AspectRatio = .freeform
    private var dragStart = CGPoint.zero
    private var original = CGRect.zero
    private let onChange: (CGRect, Bool) -> Void

    init(screen: NSScreen, onChange: @escaping (CGRect, Bool) -> Void) {
        self.screen = screen
        self.onChange = onChange
        panel = Self.makePanel()
        panel.ignoresMouseEvents = true
        panel.contentView = outline
        for index in 0..<5 {
            let handle = Self.makePanel()
            let view = RegionHandleView(index: index)
            view.onDown = { [weak self] in
                guard let self else { return }
                self.dragStart = NSEvent.mouseLocation
                self.original = self.region
            }
            view.onDrag = { [weak self] finished in self?.drag(index: index, finished: finished) }
            handle.contentView = view
            handles.append(handle)
        }
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        return panel
    }

    func update(region: CGRect, ratio: AspectRatio, capturing: Bool, enabled: Bool) {
        self.region = region
        self.ratio = ratio
        let frame = RegionGeometry.appKitRect(region, screenFrame: screen.frame)
        panel.setFrame(frame, display: true)
        outline.capturing = capturing
        panel.orderFrontRegardless()
        let moveY: CGFloat
        if frame.maxY + 38 <= screen.frame.maxY {
            moveY = frame.maxY + 26
        } else if frame.minY - 38 >= screen.frame.minY {
            moveY = frame.minY - 26
        } else {
            moveY = frame.maxY - 38
        }
        let centers = [CGPoint(x: frame.minX, y: frame.maxY), CGPoint(x: frame.maxX, y: frame.maxY),
                       CGPoint(x: frame.minX, y: frame.minY), CGPoint(x: frame.maxX, y: frame.minY),
                       CGPoint(x: frame.midX, y: moveY)]
        for (index, handle) in handles.enumerated() {
            let size = CGSize(width: index == 4 ? 92 : 24, height: 24)
            let center = centers[index]
            let bounds = screen.frame
            let origin = CGPoint(x: min(max(center.x - size.width / 2, bounds.minX), bounds.maxX - size.width),
                                 y: min(max(center.y - size.height / 2, bounds.minY), bounds.maxY - size.height))
            handle.setFrame(CGRect(origin: origin, size: size), display: true)
            handle.ignoresMouseEvents = !enabled
            (handle.contentView as? RegionHandleView)?.capturing = capturing
            handle.orderFrontRegardless()
        }
    }

    private func drag(index: Int, finished: Bool) {
        let mouse = NSEvent.mouseLocation
        let delta = CGPoint(x: mouse.x - dragStart.x, y: dragStart.y - mouse.y)
        let next: CGRect
        if index == 4 {
            next = RegionGeometry.constrained(original.offsetBy(dx: delta.x, dy: delta.y),
                                              to: screen.frame.size, ratio: ratio.value)
        } else {
            let corners = [CGPoint(x: original.minX, y: original.minY),
                           CGPoint(x: original.maxX, y: original.minY),
                           CGPoint(x: original.minX, y: original.maxY),
                           CGPoint(x: original.maxX, y: original.maxY)]
            let point = CGPoint(x: corners[index].x + delta.x, y: corners[index].y + delta.y)
            next = RegionGeometry.drawn(from: corners[3 - index], to: point,
                                        in: screen.frame.size, ratio: ratio.value)
            guard next.width >= 32, next.height >= 32 else {
                if finished { onChange(region, true) }
                return
            }
        }
        onChange(next, finished)
    }

    func close() {
        panel.close()
        handles.forEach { $0.close() }
    }
}

private final class RegionOutlineView: NSView {
    var capturing = false { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        let outline = NSBezierPath(rect: bounds.insetBy(dx: 2, dy: 2))
        NSColor.black.setStroke()
        outline.lineWidth = 4
        outline.stroke()
        (capturing ? NSColor.systemRed : NSColor.systemCyan).setStroke()
        outline.lineWidth = 2
        outline.stroke()
    }
}

private final class RegionHandleView: NSView {
    private let index: Int
    var capturing = false { didSet { needsDisplay = true } }
    var onDown: (() -> Void)?
    var onDrag: ((Bool) -> Void)?

    init(index: Int) {
        self.index = index
        super.init(frame: .zero)
        toolTip = index == 4 ? "Drag to move region" : "Drag to resize region"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var cursor: NSCursor {
        if index == 4 { return .openHand }
        if #available(macOS 15.0, *) {
            let positions: [NSCursor.FrameResizePosition] = [.topLeft, .topRight, .bottomLeft, .bottomRight]
            return .frameResize(position: positions[index], directions: [.inward, .outward])
        }
        return Self.diagonalCursors[index == 0 || index == 3 ? 0 : 1]
    }

    // macOS 13 and 14 don't provide public diagonal resize cursors.
    private static let diagonalCursors: [NSCursor] = [false, true].map { mirrored in
        let image = NSImage(size: NSSize(width: 24, height: 24), flipped: false) { _ in
            let path = NSBezierPath()
            func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
                NSPoint(x: mirrored ? 24 - x : x, y: y)
            }
            path.move(to: point(5, 19))
            path.line(to: point(19, 5))
            path.move(to: point(5, 12))
            path.line(to: point(5, 19))
            path.line(to: point(12, 19))
            path.move(to: point(12, 5))
            path.line(to: point(19, 5))
            path.line(to: point(19, 12))
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            NSColor.white.setStroke()
            path.lineWidth = 4
            path.stroke()
            NSColor.black.setStroke()
            path.lineWidth = 2
            path.stroke()
            return true
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: 12, y: 12))
    }

    override func resetCursorRects() { addCursorRect(bounds, cursor: cursor) }

    override func draw(_ dirtyRect: NSRect) {
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 5, yRadius: 5)
        (capturing ? NSColor.systemRed : NSColor.systemCyan).setFill()
        shape.fill()
        NSColor.black.setStroke()
        shape.lineWidth = 2
        shape.stroke()
        if index == 4 {
            let text = capturing ? "LIVE • Move" : "Move"
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            (text as NSString).draw(in: bounds.insetBy(dx: 4, dy: 5), withAttributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.black, .paragraphStyle: style
            ])
        }
    }

    override func mouseDown(with event: NSEvent) {
        onDown?()
        (index == 4 ? NSCursor.closedHand : cursor).set()
    }

    override func mouseDragged(with event: NSEvent) {
        (index == 4 ? NSCursor.closedHand : cursor).set()
        onDrag?(false)
    }

    override func mouseUp(with event: NSEvent) {
        onDrag?(true)
        cursor.set()
    }
}
