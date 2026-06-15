import SwiftUI

struct DockLayoutView: View {
    @Environment(DockViewModel.self) private var viewModel
    @State private var showGuide = false

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if viewModel.isLoading {
                    ProgressView("正在加载 Dock 配置...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let layout = viewModel.layout {
                    // Persistent Apps Section
                    sectionHeader(
                        "应用区",
                        subtitle: "Dock 左侧的应用程序",
                        count: layout.persistentApps.count,
                        actionTitle: "添加应用",
                        actionSystemImage: "plus"
                    ) {
                        viewModel.dockAppPickerTargetSection = .apps
                        viewModel.showDockAppPicker = true
                    }

                    DockSectionView(
                        items: layout.persistentApps,
                        section: .apps
                    )

                    Divider()
                        .padding(.vertical, 4)

                    // Persistent Others Section
                    sectionHeader("文件区", subtitle: "Dock 右侧的文件夹和文件（分组显示在这里）", count: layout.persistentOthers.count)

                    DockSectionView(
                        items: layout.persistentOthers,
                        section: .others
                    )

                    if let selectedGroup {
                        DockGroupView(group: selectedGroup)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.secondary.opacity(0.18))
                            )
                    }

                    if layout.persistentOthers.isEmpty {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                            Text("还没有分组。点击左侧「新建分组」创建文件夹堆栈，分组会显示在这里。")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }

                    if !layout.recentApps.isEmpty {
                        Divider()
                            .padding(.vertical, 4)

                        sectionHeader(
                            "最近应用区",
                            subtitle: "系统维护的最近应用，Dock 实际位置由 macOS 控制",
                            count: layout.recentApps.count
                        )

                        DockReadOnlySectionView(items: layout.recentApps)
                    }

                    Spacer(minLength: 40)
                } else {
                    ContentUnavailableView(
                        "未加载",
                        systemImage: "dock.triangle.bottom",
                        description: Text("点击刷新按钮加载 Dock 配置")
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                }
            }
            .padding(20)
        }
        .navigationTitle("DockDIY")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showGuide = true
                } label: {
                    Label("使用指南", systemImage: "questionmark.circle")
                }
                .help("查看使用指南")

                Button {
                    viewModel.loadDockLayout()
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .help("重新加载 Dock 配置")

                Button {
                    viewModel.showApplyConfirmation = true
                } label: {
                    Label("应用", systemImage: "checkmark.circle")
                }
                .disabled(!viewModel.hasUnsavedChanges)
                .help("将更改写入 Dock（Dock 会短暂消失后恢复）")
            }
        }
        .sheet(isPresented: $showGuide) {
            GuideSheet()
        }
    }

    private var selectedGroup: DockGroup? {
        guard let selectedGroupId = viewModel.selectedGroupId else { return nil }
        return viewModel.groups.first { $0.id == selectedGroupId }
    }

    private func sectionHeader(_ title: String, subtitle: String, count: Int,
                               actionTitle: String? = nil,
                               actionSystemImage: String? = nil,
                               action: (() -> Void)? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("(\(count))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            if let action, let actionTitle, let actionSystemImage {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionSystemImage)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(actionTitle)
            }
        }
    }
}

// MARK: - DockReadOnlySectionView

struct DockReadOnlySectionView: View {
    let items: [DockItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    DockReadOnlyItemView(item: item)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(minHeight: 80)
    }
}

struct DockReadOnlyItemView: View {
    let item: DockItem

    var body: some View {
        VStack(spacing: 4) {
            iconView(size: 52)
            Text(item.label)
                .font(.system(size: 10))
                .lineLimit(1)
                .frame(maxWidth: 64)
        }
        .padding(6)
        .contentShape(Rectangle())
        .contextMenu {
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
            Image(systemName: "app")
                .font(.system(size: size * 0.55))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - GuideSheet

struct GuideSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("使用指南")
                    .font(.title)
                    .bold()
                Spacer()
                Button("关闭") { dismiss() }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    guideStep(
                        number: 1,
                        title: "创建分组",
                        description: "点击左侧边栏底部的「新建分组」按钮，输入分组名称（如「开发工具」），然后从应用列表中勾选要归入该组的应用，点击「创建」。"
                    )

                    guideStep(
                        number: 2,
                        title: "查看分组效果",
                        description: "创建后，分组会出现在左侧边栏和右侧「文件区」中。点击侧边栏的分组可以查看和管理其中的应用。"
                    )

                    guideStep(
                        number: 3,
                        title: "应用到 Dock",
                        description: "点击工具栏的「应用」按钮。Dock 会短暂消失 1-2 秒后恢复，此时你的分组会以文件夹堆栈（Stack）的形式出现在 Dock 右侧。"
                    )

                    guideStep(
                        number: 4,
                        title: "管理分组",
                        description: "• 右键点击 Dock 中的分组图标 → 编辑分组\n• 右键侧边栏分组 → 添加应用 / 删除分组\n• 拖拽应用图标来调整顺序\n• 从 Finder 拖入 .app 到应用区或文件区"
                    )

                    Divider()

                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading) {
                            Text("提示")
                                .font(.caption.bold())
                            Text("所有更改在点击「应用」之前不会生效，你可以随时点击「刷新」撤销未应用的更改。每次应用前会自动备份 Dock 配置。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(24)
        .frame(width: 520, height: 520)
    }

    private func guideStep(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(number)")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.accentColor))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - DockSectionView

struct DockSectionView: View {
    @Environment(DockViewModel.self) private var viewModel
    let items: [DockItem]
    let section: DockSection
    @State private var draggingItem: DockItemTransfer?
    @State private var isTargeted = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    DockItemView(
                        item: item,
                        section: section,
                        index: index,
                        itemCount: items.count
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(minHeight: 80)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundStyle(isTargeted ? Color.accentColor : .clear)
        )
        .dropDestination(for: DockItemTransfer.self) { transfers, _ in
            guard let transfer = transfers.first else { return false }
            let targetIndex = items.count
            if transfer.sourceSection == section {
                viewModel.moveItem(in: section, from: transfer.sourceIndex, to: targetIndex)
            } else {
                viewModel.moveItemAcrossSections(
                    itemId: transfer.itemId,
                    from: transfer.sourceSection,
                    to: section
                )
            }
            return true
        }
        .dropDestination(for: URL.self) { urls, _ in
            var added = false
            for url in urls {
                let resolved = url.resolvingSymlinksInPath()
                if resolved.pathExtension == "app"
                    || FileManager.default.fileExists(atPath: resolved.path(percentEncoded: false)) {
                    viewModel.addAppToDock(appPath: resolved, to: section)
                    added = true
                }
            }
            return added
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
}
