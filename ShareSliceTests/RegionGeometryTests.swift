import XCTest
@testable import ShareSlice

final class RegionGeometryTests: XCTestCase {
    func testAppKitConversionOnDisplayLeftOfMainDisplay() {
        let screen = CGRect(x: -1920, y: 200, width: 1920, height: 1080)
        let region = CGRect(x: 100, y: 50, width: 640, height: 360)
        XCTAssertEqual(RegionGeometry.appKitRect(region, screenFrame: screen),
                       CGRect(x: -1820, y: 870, width: 640, height: 360))
    }

    func testAppKitConversionOnDisplayBelowMainDisplay() {
        XCTAssertEqual(RegionGeometry.appKitRect(CGRect(x: 0, y: 0, width: 800, height: 600),
                                                 screenFrame: CGRect(x: 0, y: -1080, width: 1920, height: 1080)),
                       CGRect(x: 0, y: -600, width: 800, height: 600))
    }

    func testRetinaScalingDoesNotChangeSourceCoordinates() {
        let source = CGRect(x: 100, y: 200, width: 640, height: 360)
        XCTAssertEqual(RegionGeometry.pixelSize(source, scale: 2), CGSize(width: 1280, height: 720))
        XCTAssertEqual(RegionGeometry.pixelSize(source, scale: 1), source.size)
    }

    func testOversizedAndOffscreenRegionIsClamped() {
        XCTAssertEqual(RegionGeometry.constrained(CGRect(x: -50, y: 900, width: 3000, height: 300),
                                                  to: CGSize(width: 1920, height: 1080)),
                       CGRect(x: 0, y: 780, width: 1920, height: 300))
    }

    func testFixedRatiosFitUltrawideDisplay() {
        for ratio in [AspectRatio.widescreen, .standard] {
            let region = RegionGeometry.constrained(CGRect(x: 3000, y: 800, width: 3000, height: 1000),
                                                    to: CGSize(width: 3440, height: 1440), ratio: ratio.value)
            XCTAssertEqual(region.width / region.height, ratio.value!, accuracy: 0.0001)
            XCTAssertTrue(CGRect(x: 0, y: 0, width: 3440, height: 1440).contains(region))
        }
    }

    func testDrawingInEveryDirectionPreservesAnchorAndRatio() {
        let anchor = CGPoint(x: 500, y: 400)
        for point in [CGPoint(x: -100, y: -100), CGPoint(x: 1200, y: -100),
                      CGPoint(x: -100, y: 900), CGPoint(x: 1200, y: 900)] {
            let region = RegionGeometry.drawn(from: anchor, to: point,
                                              in: CGSize(width: 1000, height: 800), ratio: 16.0 / 9.0)
            XCTAssertEqual(region.width / region.height, 16.0 / 9.0, accuracy: 0.0001)
            XCTAssertGreaterThanOrEqual(region.minX, 0)
            XCTAssertGreaterThanOrEqual(region.minY, 0)
            XCTAssertLessThanOrEqual(region.maxX, 1000)
            XCTAssertLessThanOrEqual(region.maxY, 800)
            XCTAssertEqual(point.x < anchor.x ? region.maxX : region.minX, anchor.x, accuracy: 0.0001)
            XCTAssertEqual(point.y < anchor.y ? region.maxY : region.minY, anchor.y, accuracy: 0.0001)
        }
    }

    func testFreeformDrawing() {
        XCTAssertEqual(RegionGeometry.drawn(from: CGPoint(x: 500, y: 400), to: CGPoint(x: 100, y: 200),
                                            in: CGSize(width: 1000, height: 800), ratio: nil),
                       CGRect(x: 100, y: 200, width: 400, height: 200))
    }

    func testInvalidSavedCoordinatesAreRejected() {
        XCTAssertEqual(RegionGeometry.constrained(CGRect(x: CGFloat.nan, y: 0, width: 100, height: 100),
                                                  to: CGSize(width: 1000, height: 800)), .zero)
    }
}
