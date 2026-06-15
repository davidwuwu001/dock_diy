import Foundation
import UniformTypeIdentifiers
import CoreTransferable

// MARK: - Custom UTType

extension UTType {
    static let dockItem = UTType(exportedAs: "com.dockdiy.dockitem")
}

// MARK: - DockItemTransfer

struct DockItemTransfer: Codable, Transferable {
    var itemId: UInt32
    var sourceSection: DockSection
    var sourceIndex: Int

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .dockItem)
    }
}
