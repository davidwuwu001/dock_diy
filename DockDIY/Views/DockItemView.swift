import SwiftUI

struct DockItemView: View {
    @Environment(DockViewModel.self) private var viewModel
    let item: DockItem
    let section: DockSection
    let index: Int
    let itemCount: Int
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                iconView(size: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isHovered ? Color.accentColor.opacity(0.1) : .clear)
                    )

                if isHovered {
                    Button {
                        viewModel.removeItem(item.guid, from: section)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 4, y: -4)
                }
            }

            Text(item.label)
                .font(.system(size: 10))
                .lineLimit(1)
                .frame(maxWidth: 64)

        }
        .padding(6)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .draggable(DockItemTransfer(
            itemId: item.guid,
            sourceSection: section,
            sourceIndex: index
        )) {
            // Drag preview
            VStack(spacing: 2) {
                iconView(size: 40)
                Text(item.label)
                    .font(.system(size: 9))
            }
            .padding(4)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .dropDestination(for: DockItemTransfer.self) { transfers, _ in
            guard let transfer = transfers.first else { return false }
            if transfer.sourceSection == section {
                viewModel.moveItem(in: section, from: transfer.sourceIndex, to: index)
            }
            return true
        }
        .contextMenu {
            if item.tileType == .file {
                Button("编辑应用...") {
                    viewModel.editingDockItem = item
                    viewModel.editingDockSection = section
                    viewModel.showDockItemEditor = true
                }
            }

            Button("向左移动") {
                viewModel.moveItemByOffset(item.guid, in: section, offset: -1)
            }
            .disabled(index == 0)

            Button("向右移动") {
                viewModel.moveItemByOffset(item.guid, in: section, offset: 1)
            }
            .disabled(index >= itemCount - 1)

            Button("从 Dock 移除") {
                viewModel.removeItem(item.guid, from: section)
            }

            Button("在 Finder 中显示") {
                NSWorkspace.shared.activateFileViewerSelecting([item.path])
            }
        }
    }

    @ViewBuilder
    private func iconView(size: CGFloat) -> some View {
        if let nsImage = item.icon {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: iconSystemName)
                .font(.system(size: size * 0.55))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        }
    }

    private var iconSystemName: String {
        switch item.tileType {
        case .file:      return "app"
        case .directory: return "folder"
        case .spacer:    return "rectangle.dashed"
        case .url:       return "link"
        }
    }
}
