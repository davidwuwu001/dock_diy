import Foundation
import AppKit

// MARK: - Stack Display Style

enum StackDisplayStyle: Int, Codable, CaseIterable, Identifiable {
    case auto = 0
    case fan = 1
    case grid = 2
    case list = 3

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "自动"
        case .fan:  return "扇形"
        case .grid: return "网格"
        case .list: return "列表"
        }
    }
}

// MARK: - Stack Arrangement

enum StackArrangement: Int, Codable, CaseIterable, Identifiable {
    case name = 1
    case dateAdded = 2
    case dateModified = 3
    case dateCreated = 4
    case kind = 5

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .name:         return "名称"
        case .dateAdded:    return "添加日期"
        case .dateModified: return "修改日期"
        case .dateCreated:  return "创建日期"
        case .kind:         return "类型"
        }
    }
}

// MARK: - DockGroup

struct DockGroup: Identifiable {
    let id: UUID
    var name: String
    var folderPath: URL
    var members: [DockGroupMember]
    var showAs: StackDisplayStyle
    var arrangement: StackArrangement
    var iconSystemName: String

    init(id: UUID = UUID(), name: String, folderPath: URL,
         members: [DockGroupMember] = [],
         showAs: StackDisplayStyle = .auto,
         arrangement: StackArrangement = .name,
         iconSystemName: String = DockGroup.defaultIconSystemName) {
        self.id = id
        self.name = name
        self.folderPath = folderPath
        self.members = members
        self.showAs = showAs
        self.arrangement = arrangement
        self.iconSystemName = iconSystemName
    }
}

struct GroupIconOption: Identifiable, Hashable {
    let systemName: String
    let displayName: String

    var id: String { systemName }
}

extension DockGroup {
    static let defaultIconSystemName = "folder"

    static let iconOptions: [GroupIconOption] = [
        GroupIconOption(systemName: "folder", displayName: "通用"),
        GroupIconOption(systemName: "terminal", displayName: "终端"),
        GroupIconOption(systemName: "curlybraces", displayName: "代码"),
        GroupIconOption(systemName: "hammer", displayName: "开发"),
        GroupIconOption(systemName: "paintbrush", displayName: "设计"),
        GroupIconOption(systemName: "pencil", displayName: "写作"),
        GroupIconOption(systemName: "doc.text", displayName: "办公"),
        GroupIconOption(systemName: "globe", displayName: "网络"),
        GroupIconOption(systemName: "sparkles", displayName: "AI"),
        GroupIconOption(systemName: "wrench.and.screwdriver", displayName: "工具"),
        GroupIconOption(systemName: "music.note", displayName: "音乐"),
        GroupIconOption(systemName: "play.rectangle", displayName: "视频"),
        GroupIconOption(systemName: "camera", displayName: "图片"),
        GroupIconOption(systemName: "gamecontroller", displayName: "游戏")
    ]
}

// MARK: - DockGroupMember

struct DockGroupMember: Identifiable {
    var appPath: URL
    var symlinkPath: URL
    var label: String
    var bundleIdentifier: String?
    var icon: NSImage?

    var id: URL { appPath }

    mutating func loadIcon() {
        icon = NSWorkspace.shared.icon(forFile: appPath.path(percentEncoded: false))
    }
}
