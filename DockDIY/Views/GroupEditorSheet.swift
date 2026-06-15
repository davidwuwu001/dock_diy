import SwiftUI

private extension AppInfo {
    func matchesGroupEditorQuery(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let haystack = [
            name,
            bundleIdentifier ?? "",
            path.lastPathComponent,
            path.path(percentEncoded: false)
        ].joined(separator: " ")

        return trimmed
            .split(separator: " ")
            .allSatisfy { haystack.localizedCaseInsensitiveContains($0) }
    }
}

struct GroupEditorSheet: View {
    @Environment(DockViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let group: DockGroup?

    @State private var name = ""
    @State private var showAs: StackDisplayStyle = .auto
    @State private var arrangement: StackArrangement = .name
    @State private var selectedApps: Set<URL> = []
    @State private var availableApps: [AppInfo] = []
    @State private var searchText = ""

    var isEditing: Bool { group != nil }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text(isEditing ? "编辑分组" : "新建分组")
                    .font(.title2)
                    .bold()
                Spacer()
            }

            Form {
                TextField("分组名称", text: $name)

                Picker("显示方式", selection: $showAs) {
                    ForEach(StackDisplayStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Picker("排序方式", selection: $arrangement) {
                    ForEach(StackArrangement.allCases) { arr in
                        Text(arr.displayName).tag(arr)
                    }
                }
                .pickerStyle(.menu)
            }
            .formStyle(.grouped)
            .frame(maxHeight: 200)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("选择应用")
                        .font(.headline)
                    Spacer()
                    Text("已选 \(selectedApps.count) 个")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("搜索应用...", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                ScrollView {
                    if filteredApps.isEmpty {
                        ContentUnavailableView(
                            "没有匹配的应用",
                            systemImage: "magnifyingglass",
                            description: Text("换个关键词试试")
                        )
                        .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                            ForEach(filteredApps) { app in
                                appTile(app)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .frame(maxHeight: 240)
            }

            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isEditing ? "保存" : "创建") {
                    if isEditing, let group {
                        let apps = availableApps.filter { selectedApps.contains($0.path) }
                        viewModel.updateGroup(
                            group,
                            name: name,
                            apps: apps,
                            showAs: showAs,
                            arrangement: arrangement
                        )
                        dismiss()
                    } else {
                        let apps = availableApps.filter { selectedApps.contains($0.path) }
                        viewModel.createGroup(
                            name: name,
                            apps: apps,
                            showAs: showAs,
                            arrangement: arrangement
                        )
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty
                          || selectedApps.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 520)
        .onAppear {
            availableApps = AppDiscoveryService.shared.discoverApps()
            if let group {
                name = group.name
                showAs = group.showAs
                arrangement = group.arrangement
                selectedApps = Set(group.members.map(\.appPath))
                mergeExistingMembers(group.members)
            }
        }
    }

    private func mergeExistingMembers(_ members: [DockGroupMember]) {
        var appsByPath = Dictionary(uniqueKeysWithValues: availableApps.map { ($0.path, $0) })
        for member in members where appsByPath[member.appPath] == nil {
            appsByPath[member.appPath] = AppInfo(
                name: member.label,
                path: member.appPath,
                bundleIdentifier: member.bundleIdentifier,
                icon: member.icon
            )
        }
        availableApps = appsByPath.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var filteredApps: [AppInfo] {
        availableApps
            .filter { $0.matchesGroupEditorQuery(searchText) }
            .sorted { lhs, rhs in
                let lhsSelected = selectedApps.contains(lhs.path)
                let rhsSelected = selectedApps.contains(rhs.path)
                if lhsSelected != rhsSelected { return lhsSelected }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func appTile(_ app: AppInfo) -> some View {
        let isSelected = selectedApps.contains(app.path)
        return Button {
            if isSelected {
                selectedApps.remove(app.path)
            } else {
                selectedApps.insert(app.path)
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "app")
                            .font(.system(size: 28))
                            .frame(width: 44, height: 44)
                    }
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                            .offset(x: 4, y: -4)
                    }
                }
                Text(app.name)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .frame(maxWidth: 64)
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : .clear)
            )
        }
        .buttonStyle(.plain)
    }
}
