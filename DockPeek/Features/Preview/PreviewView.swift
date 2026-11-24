import SwiftUI

/// What the preview panel shows: one app's windows, arranged in rows.
struct PreviewContent {
    var appIcon: NSImage?
    var rows: [[AppWindow]]
    var thumbnails: [CGWindowID: NSImage]

    @MainActor static let empty = PreviewContent(appIcon: nil, rows: [], thumbnails: [:])
}

/// Window thumbnails above a Dock icon, like the taskbar previews in Windows.
/// Click a thumbnail to bring the window forward, × closes it.
struct PreviewView: View {
    let content: PreviewContent
    let onFocus: (AppWindow) -> Void
    let onClose: (AppWindow) -> Void

    /// Largest thumbnail, in points.
    static let thumbnailBox = CGSize(width: 220, height: 140)
    static let cardPadding: CGFloat = 8
    static let spacing: CGFloat = 4
    static let minimumCardWidth: CGFloat = 150

    static func thumbnailSize(for window: AppWindow) -> CGSize {
        PreviewLayout.thumbnailSize(for: window.size, in: thumbnailBox)
    }

    static func cardWidth(for window: AppWindow) -> CGFloat {
        max(thumbnailSize(for: window).width, minimumCardWidth) + cardPadding * 2
    }

    /// Splits windows into rows that fit `maxWidth`, so many windows wrap instead of
    /// running off the screen.
    static func rows(for windows: [AppWindow], maxWidth: CGFloat) -> [[AppWindow]] {
        var rows: [[AppWindow]] = []
        var row: [AppWindow] = []
        var width = spacing * 2
        for window in windows {
            let cardWidth = cardWidth(for: window)
            if !row.isEmpty, width + spacing + cardWidth > maxWidth {
                rows.append(row)
                row = []
                width = spacing * 2
            }
            width += (row.isEmpty ? 0 : spacing) + cardWidth
            row.append(window)
        }
        if !row.isEmpty { rows.append(row) }
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            ForEach(content.rows.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: Self.spacing) {
                    ForEach(content.rows[index]) { window in
                        WindowCard(
                            window: window,
                            thumbnail: content.thumbnails[window.id],
                            appIcon: content.appIcon,
                            onFocus: { onFocus(window) },
                            onClose: { onClose(window) }
                        )
                    }
                }
            }
        }
        .padding(Self.spacing)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .fixedSize()
    }
}

private struct WindowCard: View {
    let window: AppWindow
    let thumbnail: NSImage?
    let appIcon: NSImage?
    let onFocus: () -> Void
    let onClose: () -> Void

    @State private var isHovered = false
    @State private var isCloseHovered = false

    var body: some View {
        let size = PreviewView.thumbnailSize(for: window)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                }
                Text(window.title)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                closeButton
            }
            thumbnailView
                .frame(width: size.width, height: size.height)
                .frame(maxWidth: .infinity)
        }
        .padding(PreviewView.cardPadding)
        .frame(width: PreviewView.cardWidth(for: window))
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? AnyShapeStyle(.fill.secondary) : AnyShapeStyle(.clear))
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onFocus)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(window.isMinimized ? "\(window.title), minimiert" : window.title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, onFocus)
        .accessibilityAction(named: "Fenster schließen", onClose)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isCloseHovered ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .frame(width: 22, height: 22)
                .background(Circle().fill(isCloseHovered ? AnyShapeStyle(.red) : AnyShapeStyle(.clear)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isCloseHovered = $0 }
        .opacity(isHovered ? 1 : 0)
        .help("Fenster schließen")
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .opacity(window.isMinimized ? 0.6 : 1)
                .overlay(alignment: .bottomTrailing) {
                    if window.isMinimized { minimizedBadge.padding(6) }
                }
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.fill.tertiary)
                .overlay {
                    VStack(spacing: 6) {
                        if let appIcon {
                            Image(nsImage: appIcon)
                                .resizable()
                                .frame(width: 48, height: 48)
                        }
                        if window.isMinimized { minimizedBadge }
                    }
                }
        }
    }

    private var minimizedBadge: some View {
        Text("Minimiert")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.regularMaterial, in: Capsule())
    }
}
