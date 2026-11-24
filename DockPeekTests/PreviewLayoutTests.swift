import CoreGraphics
import Testing
@testable import DockPeek

struct PreviewLayoutTests {
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    @Test func detectsDockEdge() {
        #expect(PreviewLayout.edge(of: CGRect(x: 700, y: 4, width: 60, height: 60), on: screen) == .bottom)
        #expect(PreviewLayout.edge(of: CGRect(x: 4, y: 400, width: 60, height: 60), on: screen) == .left)
        #expect(PreviewLayout.edge(of: CGRect(x: 1376, y: 400, width: 60, height: 60), on: screen) == .right)
    }

    @Test func detectsEdgeOnSecondDisplay() {
        let second = CGRect(x: 1440, y: -200, width: 1920, height: 1080)
        let icon = CGRect(x: 2300, y: -196, width: 60, height: 60)
        #expect(PreviewLayout.edge(of: icon, on: second) == .bottom)
    }

    @Test func centersAboveBottomIcon() {
        let icon = CGRect(x: 700, y: 4, width: 60, height: 60)
        let origin = PreviewLayout.origin(for: CGSize(width: 400, height: 200), icon: icon, screen: screen, edge: .bottom)
        #expect(origin == CGPoint(x: 530, y: 64 + PreviewLayout.gap))
    }

    @Test func staysOnScreenNearCorner() {
        let icon = CGRect(x: 10, y: 4, width: 60, height: 60)
        let origin = PreviewLayout.origin(for: CGSize(width: 400, height: 200), icon: icon, screen: screen, edge: .bottom)
        #expect(origin.x == PreviewLayout.margin)

        let rightIcon = CGRect(x: 1400, y: 4, width: 40, height: 40)
        let rightOrigin = PreviewLayout.origin(for: CGSize(width: 400, height: 200), icon: rightIcon, screen: screen, edge: .bottom)
        #expect(rightOrigin.x == 1440 - PreviewLayout.margin - 400)
    }

    @Test func placesBesideSideDocks() {
        let left = CGRect(x: 4, y: 400, width: 60, height: 60)
        #expect(PreviewLayout.origin(for: CGSize(width: 300, height: 100), icon: left, screen: screen, edge: .left)
            == CGPoint(x: 64 + PreviewLayout.gap, y: 380))

        let right = CGRect(x: 1376, y: 400, width: 60, height: 60)
        #expect(PreviewLayout.origin(for: CGSize(width: 300, height: 100), icon: right, screen: screen, edge: .right)
            == CGPoint(x: 1376 - PreviewLayout.gap - 300, y: 380))
    }

    @Test func fitsThumbnailsWithoutUpscaling() {
        let box = CGSize(width: 220, height: 140)
        #expect(PreviewLayout.thumbnailSize(for: CGSize(width: 1440, height: 900), in: box) == CGSize(width: 220, height: 138))
        #expect(PreviewLayout.thumbnailSize(for: CGSize(width: 700, height: 1400), in: box) == CGSize(width: 70, height: 140))
        #expect(PreviewLayout.thumbnailSize(for: CGSize(width: 100, height: 60), in: box) == CGSize(width: 100, height: 60))
    }

    @Test func flipsAccessibilityCoordinates() {
        let rect = PreviewLayout.cocoaRect(fromAccessibility: CGRect(x: 700, y: 836, width: 60, height: 60), primaryScreenHeight: 900)
        #expect(rect == CGRect(x: 700, y: 4, width: 60, height: 60))
    }

    @MainActor @Test func wrapsWindowsIntoRows() {
        let window = { (id: CGWindowID) in
            AppWindow(id: id, title: "\(id)", size: CGSize(width: 1440, height: 900), isMinimized: false, element: nil)
        }
        let windows = (1...5).map(window)
        let box = ThumbnailSize.medium.box
        let cardWidth = PreviewView.cardWidth(for: windows[0], in: box)
        let maxWidth = PreviewView.spacing * 2 + cardWidth * 2 + PreviewView.spacing
        let rows = PreviewView.rows(for: windows, in: box, maxWidth: maxWidth)
        #expect(rows.map(\.count) == [2, 2, 1])
        #expect(PreviewView.rows(for: windows, in: box, maxWidth: 10_000).map(\.count) == [5])
        // Larger thumbnails wrap sooner.
        #expect(PreviewView.rows(for: windows, in: ThumbnailSize.large.box, maxWidth: maxWidth).map(\.count) == [1, 1, 1, 1, 1])
    }
}
