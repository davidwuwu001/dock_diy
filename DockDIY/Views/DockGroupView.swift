import SwiftUI

struct DockGroupView: View {
    @Environment(DockViewModel.self) private var viewModel
    let group: DockGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder")
                    .foregroundStyle(.tint)
                Text(group.name)
                    .font(.headline)
                Spacer()
                Text("\(group.members.count) 个应用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
                    viewModel.appPickerTargetGroupId = group.id
                    viewModel.showAppPicker = true
                } label: {
                    Label("添加应用", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.editingGroup = group
                    viewModel.showGroupEditor = true
                } label: {
                    Label("编辑", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 4)
        }
        .padding()
    }

    private func memberView(_ member: DockGroupMember) -> some View {
        VStack(spacing: 4) {
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

            Text(member.label)
                .font(.system(size: 10))
                .lineLimit(1)
                .frame(maxWidth: 64)
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
