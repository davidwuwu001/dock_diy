import SwiftUI

struct SidebarView: View {
    @Environment(DockViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel

        List(selection: $vm.selectedGroupId) {
            Section("分组") {
                ForEach(viewModel.groups) { group in
                    HStack {
                        Image(systemName: group.iconSystemName)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading) {
                            Text(group.name)
                                .font(.body)
                            Text("\(group.members.count) 个应用")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(group.id)
                    .contextMenu {
                        Button("编辑分组...") {
                            vm.editingGroup = group
                            vm.showGroupEditor = true
                        }
                        Button("添加应用...") {
                            vm.appPickerTargetGroupId = group.id
                            vm.showAppPicker = true
                        }
                        Divider()
                        Button("删除分组", role: .destructive) {
                            vm.deleteGroup(group)
                        }
                    }
                }

                if viewModel.groups.isEmpty {
                    Text("暂无分组")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }

            Section {
                Button {
                    vm.editingGroup = nil
                    vm.showGroupEditor = true
                } label: {
                    Label("新建分组", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.plain)
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        .listStyle(.sidebar)
    }
}
