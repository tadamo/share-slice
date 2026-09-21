import AppKit

@MainActor
final class RegionOutline {
    private let panel: NSPanel

    init(screen: NSScreen, region: CGRect) {
        let frame = RegionGeometry.appKitRect(region, screenFrame: screen.frame)
        panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = RegionOutlineView(frame: CGRect(origin: .zero, size: frame.size))
        panel.orderFrontRegardless()
    }

    func close() { panel.close() }
}

private final class RegionOutlineView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let outline = NSBezierPath(rect: bounds.insetBy(dx: 2, dy: 2))
        NSColor.black.setStroke()
        outline.lineWidth = 4
        outline.stroke()
        NSColor.systemCyan.setStroke()
        outline.lineWidth = 2
        outline.stroke()
    }
}

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
        panel.acceptsMouseMovedEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = SelectionView(frame: CGRect(origin: .zero, size: screen.frame.size),
                                 region: region, ratio: ratio, completion: completion)
        panel.contentView = view
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(view)
    }

    func close() {
        panel.close()
        NSCursor.arrow.set()
    }
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
    private var dragCursor: NSCursor?
    private var hoverTrackingArea: NSTrackingArea?

    private func cornerIndex(at point: CGPoint) -> Int? {
        corners.firstIndex { hypot($0.x - point.x, $0.y - point.y) <= 22 }
    }

    private func canMove(at point: CGPoint) -> Bool {
        region.insetBy(dx: -6, dy: -6).contains(point)
    }

    private func resizeCursor(for index: Int) -> NSCursor {
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

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseMoved, .mouseEnteredAndExited, .cursorUpdate,
                                            .activeInKeyWindow, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    private func updateCursor(with event: NSEvent) {
        if let dragCursor {
            dragCursor.set()
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        if let index = cornerIndex(at: point) {
            resizeCursor(for: index).set()
        } else {
            (canMove(at: point) ? NSCursor.openHand : NSCursor.crosshair).set()
        }
    }

    override func cursorUpdate(with event: NSEvent) { updateCursor(with: event) }
    override func mouseMoved(with event: NSEvent) { updateCursor(with: event) }
    override func mouseEntered(with event: NSEvent) { updateCursor(with: event) }
    override func mouseExited(with event: NSEvent) {
        if dragCursor == nil { NSCursor.arrow.set() }
    }

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
        if let index = cornerIndex(at: start) {
            anchor = corners[3 - index]
            moving = false
            dragCursor = resizeCursor(for: index)
        } else if canMove(at: start) {
            moving = true
            anchor = nil
            dragCursor = .closedHand
        } else {
            moving = false
            anchor = start
            dragCursor = .crosshair
        }
        dragCursor?.set()
    }

    override func mouseDragged(with event: NSEvent) {
        dragCursor?.set()
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
        dragCursor = nil
        updateCursor(with: event)
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
