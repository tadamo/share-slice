import Foundation

enum AspectRatio: String, CaseIterable, Identifiable {
    case freeform = "Freeform"
    case widescreen = "16:9"
    case standard = "4:3"

    var id: String { rawValue }
    var value: CGFloat? {
        switch self {
        case .freeform: return nil
        case .widescreen: return 16.0 / 9.0
        case .standard: return 4.0 / 3.0
        }
    }
}

enum RegionGeometry {
    // Regions use display-local points, with the origin at the top left.
    static func constrained(_ rect: CGRect, to bounds: CGSize, ratio: CGFloat? = nil) -> CGRect {
        guard bounds.width > 0, bounds.height > 0,
              [rect.origin.x, rect.origin.y, rect.width, rect.height].allSatisfy({ $0.isFinite }) else {
            return .zero
        }
        var width = min(max(rect.width, min(32, bounds.width)), bounds.width)
        var height = min(max(rect.height, min(32, bounds.height)), bounds.height)
        if let ratio, ratio > 0 {
            height = width / ratio
            if height > bounds.height {
                height = bounds.height
                width = height * ratio
            }
        }
        return CGRect(x: min(max(rect.minX, 0), bounds.width - width),
                      y: min(max(rect.minY, 0), bounds.height - height),
                      width: width, height: height)
    }

    static func drawn(from anchor: CGPoint, to point: CGPoint, in bounds: CGSize,
                      ratio: CGFloat?) -> CGRect {
        let anchor = CGPoint(x: min(max(anchor.x, 0), bounds.width),
                             y: min(max(anchor.y, 0), bounds.height))
        let dx = point.x - anchor.x
        let dy = point.y - anchor.y
        let availableWidth = dx < 0 ? anchor.x : bounds.width - anchor.x
        let availableHeight = dy < 0 ? anchor.y : bounds.height - anchor.y
        var width = min(abs(dx), availableWidth)
        var height = min(abs(dy), availableHeight)
        if let ratio {
            width = min(max(width, height * ratio), availableWidth, availableHeight * ratio)
            height = width / ratio
        }
        return CGRect(x: dx < 0 ? anchor.x - width : anchor.x,
                      y: dy < 0 ? anchor.y - height : anchor.y,
                      width: width, height: height)
    }

    static func appKitRect(_ rect: CGRect, screenFrame: CGRect) -> CGRect {
        CGRect(x: screenFrame.minX + rect.minX, y: screenFrame.maxY - rect.maxY,
               width: rect.width, height: rect.height)
    }

    static func pixelSize(_ rect: CGRect, scale: CGFloat) -> CGSize {
        CGSize(width: max(2, (rect.width * scale).rounded()),
               height: max(2, (rect.height * scale).rounded()))
    }
}
