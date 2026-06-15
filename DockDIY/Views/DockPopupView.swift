import SwiftUI
import AppKit

struct DockPopupItem: Identifiable {
    let appURL: URL
    let label: String
    let icon: NSImage

    var id: URL { appURL }
}

struct DockPopupView: View {
    let title: String
    let folderURL: URL
    let style: StackDisplayStyle
    let onStyleChange: (URL, StackDisplayStyle) -> Void
    let onClose: () -> Void

    @State private var items: [DockPopupItem] = []
    @State private var searchText = ""
    @State private var selectedStyle: StackDisplayStyle = .grid

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .onAppear(perform: loadItems)
        .onAppear {
            selectedStyle = normalized(style)
        }
        .onExitCommand(perform: onClose)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: displayModeIcon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(items.count) 个应用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: $selectedStyle) {
                Image(systemName: "square.grid.2x2")
                    .tag(StackDisplayStyle.grid)
                Image(systemName: "list.bullet")
                    .tag(StackDisplayStyle.list)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 88)
            .onChange(of: selectedStyle) { _, newValue in
                onStyleChange(folderURL, newValue)
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("关闭")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索应用", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        if filteredItems.isEmpty {
            ContentUnavailableView(
                searchText.isEmpty ? "这个分组还没有应用" : "没有匹配的应用",
                systemImage: searchText.isEmpty ? "app.dashed" : "magnifyingglass"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if selectedStyle == .list {
            listContent
        } else {
            gridContent
        }
    }

    private var gridContent: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 10)], spacing: 12) {
                ForEach(filteredItems) { item in
                    Button {
                        open(item)
                    } label: {
                        VStack(spacing: 7) {
                            Image(nsImage: item.icon)
                                .resizable()
                                .frame(width: 42, height: 42)
                            Text(item.label)
                                .font(.system(size: 11))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(width: 68, height: 28, alignment: .top)
                        }
                        .frame(width: 76, height: 84)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
        }
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(filteredItems) { item in
                    Button {
                        open(item)
                    } label: {
                        HStack(spacing: 10) {
                            Image(nsImage: item.icon)
                                .resizable()
                                .frame(width: 28, height: 28)
                            Text(item.label)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
        }
    }

    private var filteredItems: [DockPopupItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter { item in
            query
                .split(separator: " ")
                .allSatisfy { item.label.localizedCaseInsensitiveContains($0) }
        }
    }

    private func normalized(_ style: StackDisplayStyle) -> StackDisplayStyle {
        switch style {
        case .auto, .fan, .grid:
            return .grid
        case .list:
            return .list
        }
    }

    private var displayModeIcon: String {
        selectedStyle == .list ? "list.bullet" : "square.grid.2x2"
    }

    private func loadItems() {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        items = contents.compactMap { url in
            guard (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true,
                  let target = try? FileManager.default.destinationOfSymbolicLink(atPath: url.path(percentEncoded: false)) else {
                return nil
            }
            let appURL = URL(fileURLWithPath: target)
            let label = appURL.deletingPathExtension().lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: appURL.path(percentEncoded: false))
            return DockPopupItem(appURL: appURL, label: label, icon: icon)
        }
        .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private func open(_ item: DockPopupItem) {
        NSWorkspace.shared.open(item.appURL)
        onClose()
    }
}
