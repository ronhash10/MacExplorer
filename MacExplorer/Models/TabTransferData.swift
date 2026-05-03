import Foundation
import UniformTypeIdentifiers
import CoreTransferable

/// Data transferred when dragging a tab between windows.
struct TabTransferData: Codable, Transferable {
    let tabID: String
    let windowID: String
    let folderPath: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }

    init(tab: TabState, windowID: UUID) {
        self.tabID = tab.id.uuidString
        self.windowID = windowID.uuidString
        self.folderPath = tab.currentPath.path
    }

    var tabUUID: UUID? { UUID(uuidString: tabID) }
    var windowUUID: UUID? { UUID(uuidString: windowID) }
}
