import SwiftUI

struct PreviewView: View {
    let model: PreviewModel
    let onSelect: @MainActor (WindowInfo) -> Void
    let onClose: @MainActor (WindowInfo) -> Void

    var body: some View {
        let layout = model.axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: PreviewMetrics.itemSpacing))
            : AnyLayout(VStackLayout(spacing: PreviewMetrics.itemSpacing))

        layout {
            ForEach(model.windows) { window in
                WindowThumbnailView(
                    window: window,
                    appIcon: model.appIcon,
                    image: model.thumbnails[window.id],
                    isHovered: model.hoveredWindowID == window.id,
                    onHover: { hovering in
                        if hovering {
                            model.hoveredWindowID = window.id
                        } else if model.hoveredWindowID == window.id {
                            model.hoveredWindowID = nil
                        }
                    },
                    onSelect: { onSelect(window) },
                    onClose: { onClose(window) }
                )
            }
        }
        .padding(PreviewMetrics.panelPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: PreviewMetrics.cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PreviewMetrics.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1))
        )
    }
}

struct WindowThumbnailView: View {
    let window: WindowInfo
    let appIcon: NSImage?
    let image: CGImage?
    let isHovered: Bool
    let onHover: @MainActor (Bool) -> Void
    let onSelect: @MainActor () -> Void
    let onClose: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PreviewMetrics.headerSpacing) {
            header
            thumbnail
        }
        .padding(PreviewMetrics.itemPadding)
        .frame(width: PreviewMetrics.itemSize.width, height: PreviewMetrics.itemSize.height)
        .background(
            RoundedRectangle(cornerRadius: PreviewMetrics.itemCornerRadius, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.12) : .clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: PreviewMetrics.itemCornerRadius, style: .continuous))
        .onHover { hovering in onHover(hovering) }
        .onTapGesture { onSelect() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: window.title))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text("Fenster schließen")) { onClose() }
    }

    private var header: some View {
        HStack(spacing: 6) {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 16, height: 16)
            }
            Text(verbatim: window.title)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isHovered ? Color.white : Color.clear)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(isHovered ? Color.red.opacity(0.85) : Color.clear))
            }
            .buttonStyle(.plain)
            .help("Fenster schließen")
        }
        .frame(height: PreviewMetrics.headerHeight)
    }

    private var thumbnail: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: 2)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                placeholder
            }
        }
        .frame(width: PreviewMetrics.thumbnailSize.width, height: PreviewMetrics.thumbnailSize.height)
        .opacity(window.isMinimized ? 0.55 : 1)
        .overlay(alignment: .bottomTrailing) {
            if window.isMinimized {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(4)
                    .background(.thinMaterial, in: Circle())
                    .help("Minimiert")
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 6) {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 48, height: 48)
            }
            if window.isMinimized {
                Text("Minimiert")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
