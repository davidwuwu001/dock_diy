import SwiftUI

struct DockGroupView: View {
    @Environment(DockViewModel.self) private var viewModel
    let group: DockGroup
    @State private var hoveredMember: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: group.iconSystemName)
                    .foregroundStyle(.tint)
                Text(group.name)
                    .font(.headline)
                Spacer()
                Text("\(group.members.count) 个应用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            iconPicker

            if group.members.isEmpty {
                Text("此分组为空，点击「添加应用」来添加")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 12) {
                    ForEach(group.members) { member in
                        memberView(member)
                    }
                }
            }

            HStack {
                Button {
                    viewModel.revealDockLauncher(for: group)
                } label: {
                    Label("在 Finder 中显示启动器", systemImage: "app")
                }
                .buttonStyle(.borderedProminent)
                .disabled(group.members.isEmpty)
                .help("显示可以拖到左侧 Dock 的启动器 App")

                Button {
                    viewModel.addDockLauncherToLeftDock(for: group)
                } label: {
                    Label("添加到左侧 Dock", systemImage: "plus.rectangle")
                }
                .buttonStyle(.bordered)
                .disabled(group.members.isEmpty)

                Button {
                    viewModel.appPickerTargetGroupId = group.id
                    viewModel.showAppPicker = true
                } label: {
                    Label("应用", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.editingGroup = group
                    viewModel.showGroupEditor = true
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
                .help("编辑分组")
            }
            .padding(.top, 4)
        }
        .padding()
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Dock 图标")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(DockGroup.iconOptions.first { $0.systemName == group.iconSystemName }?.displayName ?? "通用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 58))], spacing: 8) {
                ForEach(DockGroup.iconOptions) { option in
                    iconButton(option)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func iconButton(_ option: GroupIconOption) -> some View {
        let isSelected = group.iconSystemName == option.systemName
        return Button {
            viewModel.updateGroupIcon(group, iconSystemName: option.systemName)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: option.systemName)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 30, height: 24)
                Text(option.displayName)
                    .font(.system(size: 10))
                    .lineLimit(1)
            }
            .frame(width: 54, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSelected)
        .help(option.displayName)
    }

    private func memberView(_ member: DockGroupMember) -> some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                if let icon = member.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 44, height: 44)
                } else {
                    Image(systemName: "app")
                        .font(.system(size: 28))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.secondary)
                }

                Button {
                    viewModel.removeAppFromGroup(
                        groupId: group.id,
                        appName: member.symlinkPath.lastPathComponent
                    )
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .background(Circle().fill(.background))
                }
                .buttonStyle(.plain)
                .opacity(hoveredMember == member.appPath ? 1 : 0.78)
                .offset(x: 6, y: -6)
                .help("从分组移除")
            }

            Text(member.label)
                .font(.system(size: 10))
                .lineLimit(1)
                .frame(maxWidth: 64)
        }
        .padding(4)
        .contentShape(Rectangle())
        .onHover { isHovered in
            hoveredMember = isHovered ? member.appPath : nil
        }
        .contextMenu {
            Button("从分组移除") {
                viewModel.removeAppFromGroup(
                    groupId: group.id,
                    appName: member.symlinkPath.lastPathComponent
                )
            }
            Button("在 Finder 中显示") {
                NSWorkspace.shared.activateFileViewerSelecting([member.appPath])
            }
        }
    }
}
