import SwiftUI

private extension AppInfo {
    func matches(_ query: String) -> Bool {
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

private func selectedFirst(_ apps: [AppInfo], selected: Set<URL>) -> [AppInfo] {
    apps.sorted { lhs, rhs in
        let lhsSelected = selected.contains(lhs.path)
        let rhsSelected = selected.contains(rhs.path)
        if lhsSelected != rhsSelected { return lhsSelected }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

struct AppPickerSheet: View {
    @Environment(DockViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let groupId: UUID
    @State private var availableApps: [AppInfo] = []
    @State private var searchText = ""
    @State private var selectedApps: Set<URL> = []

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("添加应用到分组")
                    .font(.title2)
                    .bold()
                Spacer()
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

            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("添加 (\(selectedApps.count))") {
                    let apps = availableApps.filter { selectedApps.contains($0.path) }
                    for app in apps {
                        viewModel.addAppToGroup(groupId: groupId, app: app)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedApps.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 400)
        .onAppear {
            loadApps()
        }
    }

    private func loadApps() {
        let allApps = AppDiscoveryService.shared.discoverApps()
        // Filter out apps already in the group
        if let group = viewModel.groups.first(where: { $0.id == groupId }) {
            let existingPaths = Set(group.members.map { $0.appPath })
            availableApps = allApps.filter { !existingPaths.contains($0.path) }
        } else {
            availableApps = allApps
        }
    }

    private var filteredApps: [AppInfo] {
        selectedFirst(availableApps.filter { $0.matches(searchText) }, selected: selectedApps)
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

// MARK: - DockAppPickerSheet

struct DockAppPickerSheet: View {
    @Environment(DockViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let section: DockSection
    @State private var availableApps: [AppInfo] = []
    @State private var searchText = ""
    @State private var selectedApps: Set<URL> = []

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("添加应用到 Dock 左侧")
                    .font(.title2)
                    .bold()
                Spacer()
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

            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("添加 (\(selectedApps.count))") {
                    let apps = availableApps.filter { selectedApps.contains($0.path) }
                    for app in apps {
                        viewModel.addAppToDock(appPath: app.path, to: section)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedApps.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 400)
        .onAppear {
            loadApps()
        }
    }

    private func loadApps() {
        let allApps = AppDiscoveryService.shared.discoverApps()
        let existingPaths: Set<URL>
        if let layout = viewModel.layout {
            existingPaths = Set(layout.persistentApps.map(\.path))
        } else {
            existingPaths = []
        }
        availableApps = allApps.filter { !existingPaths.contains($0.path) }
    }

    private var filteredApps: [AppInfo] {
        selectedFirst(availableApps.filter { $0.matches(searchText) }, selected: selectedApps)
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

// MARK: - DockItemEditorSheet

struct DockItemEditorSheet: View {
    @Environment(DockViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let item: DockItem
    let section: DockSection

    @State private var label = ""
    @State private var selectedPath: URL?
    @State private var availableApps: [AppInfo] = []
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("编辑应用")
                    .font(.title2)
                    .bold()
                Spacer()
            }

            Form {
                TextField("显示名称", text: $label)
            }
            .formStyle(.grouped)
            .frame(maxHeight: 90)

            TextField("搜索替换应用...", text: $searchText)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                if filteredApps.isEmpty {
                    ContentUnavailableView(
                        "没有匹配的应用",
                        systemImage: "magnifyingglass",
                        description: Text("换个关键词试试")
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                        ForEach(filteredApps) { app in
                            appTile(app)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("保存") {
                    let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
                    let app = selectedPath.flatMap { path in
                        availableApps.first { $0.path == path }
                    }
                    let path = app?.path ?? item.path
                    let bundleId = app?.bundleIdentifier ?? Bundle(url: path)?.bundleIdentifier
                    viewModel.updateItem(
                        item.guid,
                        in: section,
                        label: trimmedLabel,
                        path: path,
                        bundleIdentifier: bundleId
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 520)
        .onAppear {
            label = item.label
            selectedPath = item.path
            availableApps = AppDiscoveryService.shared.discoverApps()
        }
    }

    private var filteredApps: [AppInfo] {
        availableApps.filter { $0.matches(searchText) }
    }

    private func appTile(_ app: AppInfo) -> some View {
        let isSelected = selectedPath == app.path
        return Button {
            selectedPath = app.path
            if label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || label == item.label {
                label = app.name
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
