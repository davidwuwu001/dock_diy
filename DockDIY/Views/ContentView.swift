import SwiftUI

struct ContentView: View {
    @Environment(DockViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel

        NavigationSplitView {
            SidebarView()
        } detail: {
            VStack(spacing: 0) {
                if !viewModel.plistWritable && viewModel.layout != nil {
                    permissionWarningBanner
                }
                DockLayoutView()
            }
        }
        .onAppear {
            viewModel.loadDockLayout()
        }
        .alert("错误", isPresented: $vm.showError) {
            Button("确定") { vm.showError = false }
        } message: {
            VStack(alignment: .leading, spacing: 8) {
                Text(vm.errorMessage ?? "未知错误")
                if let recovery = vm.errorRecovery {
                    Text(recovery)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .confirmationDialog(
            "确定要应用更改到 Dock 吗？Dock 会短暂消失并重新出现。",
            isPresented: $vm.showApplyConfirmation,
            titleVisibility: .visible
        ) {
            Button("应用更改") {
                viewModel.applyChanges()
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $vm.showGroupEditor) {
            GroupEditorSheet(group: vm.editingGroup)
        }
        .sheet(isPresented: $vm.showAppPicker) {
            if let groupId = vm.appPickerTargetGroupId {
                AppPickerSheet(groupId: groupId)
            }
        }
        .sheet(isPresented: $vm.showDockAppPicker) {
            if let section = vm.dockAppPickerTargetSection {
                DockAppPickerSheet(section: section)
            }
        }
        .sheet(isPresented: $vm.showDockItemEditor) {
            if let item = vm.editingDockItem, let section = vm.editingDockSection {
                DockItemEditorSheet(item: item, section: section)
            }
        }
    }

    private var permissionWarningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("Dock 配置文件只读 — 无法保存更改")
                .font(.callout)
            Spacer()
            Button("了解详情") {
                viewModel.presentError(
                    DockPlistError.writeFailed(
                        NSError(domain: NSCocoaErrorDomain, code: 513)
                    ),
                    recovery: "请在「系统设置 > 隐私与安全性 > 完全磁盘访问权限」中授权 DockDIY，然后重启应用。"
                )
            }
            .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.1))
    }
}
