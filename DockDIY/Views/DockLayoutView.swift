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
                        subtitle: "Dock 左侧的固定应用和分组弹出器",
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

                    if viewModel.groups.isEmpty {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                            Text("还没有分组。点击左侧「新建分组」创建一个可以生成左侧 Dock 图标的应用分组。")
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
                        systemImage: "dock.rectangle",
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
                        title: "管理分组内容",
                        description: "创建后，分组会出现在左侧边栏。点击分组可以查看已经添加的应用，也可以继续添加、删除或编辑。"
                    )

                    guideStep(
                        number: 3,
                        title: "生成左侧 Dock 图标",
                        description: "在分组详情里点击「生成 Dock 图标」，DockDIY 会生成一个真正的 .app。你可以把它拖到 Dock 左侧，点击后弹出该分组里的应用。"
                    )

                    guideStep(
                        number: 4,
                        title: "管理分组",
                        description: "• 右键侧边栏分组 → 添加应用 / 删除分组\n• 分组详情里直接点击应用右上角的删除按钮\n• 修改分组后重新生成 Dock 图标即可更新弹出器"
                    )

                    Divider()

                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading) {
                            Text("提示")
                                .font(.caption.bold())
                            Text("只有把生成的分组图标自动加入左侧 Dock 时，才需要点击「应用」刷新 Dock。手动拖拽生成的 .app 到 Dock 左侧则不需要修改 Dock 配置。")
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
