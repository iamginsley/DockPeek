import SwiftUI

/// Single source of truth for preview dimensions, shared by the SwiftUI views and the
/// panel layout so the window size never depends on asynchronous SwiftUI measurement.
enum PreviewMetrics {
    static let thumbnailSize = CGSize(width: 200, height: 125)
    static let headerHeight: CGFloat = 18
    static let headerSpacing: CGFloat = 6
    static let itemPadding: CGFloat = 8
    static let itemSpacing: CGFloat = 8
    static let panelPadding: CGFloat = 10
    static let cornerRadius: CGFloat = 14
    static let itemCornerRadius: CGFloat = 10
    /// Distance between the Dock icon and the panel.
    static let dockGap: CGFloat = 8
    /// Minimum distance from the screen edges.
    static let screenMargin: CGFloat = 8

    static var itemSize: CGSize {
        CGSize(
            width: thumbnailSize.width + 2 * itemPadding,
            height: headerHeight + headerSpacing + thumbnailSize.height + 2 * itemPadding
        )
    }

    static func panelSize(itemCount: Int, axis: Axis) -> CGSize {
        let count = CGFloat(max(itemCount, 1))
        let item = itemSize
        switch axis {
        case .horizontal:
            return CGSize(
                width: count * item.width + (count - 1) * itemSpacing + 2 * panelPadding,
                height: item.height + 2 * panelPadding
            )
        case .vertical:
            return CGSize(
                width: item.width + 2 * panelPadding,
                height: count * item.height + (count - 1) * itemSpacing + 2 * panelPadding
            )
        }
    }

    /// How many items fit into `length` points along `axis`.
    static func maxItemCount(fitting length: CGFloat, axis: Axis) -> Int {
        let item = axis == .horizontal ? itemSize.width : itemSize.height
        return max(1, Int((length - 2 * panelPadding + itemSpacing) / (item + itemSpacing)))
    }
}
