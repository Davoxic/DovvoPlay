import Foundation
import SwiftUI

public enum LibraryViewMode: String, CaseIterable, Identifiable {
    public var id: String { rawValue }

    case modernCards       // 1. Card moderne (Default)
    case compactList       // 2. Lista ultra-compatta ad alta densità
    case gridCovers        // 3. Griglia copertine grandi 2x2
    case gridCompact       // 4. Griglia copertine densa 3x3
    case cdJewelCase       // 5. Custodie CD in plexiglass
    case vinylCrate        // 6. Scaffale Vinili da collezione
    case cassetteTape      // 7. Cassette Retrò Walkman
    case minimalTypography // 8. Tipografia Editoriale
}

public struct LibraryViewModeInfo: Identifiable, Equatable {
    public var id: String { mode.rawValue }
    public let mode: LibraryViewMode
    public let name: String
    public let description: String
    public let systemImage: String

    public init(mode: LibraryViewMode, name: String, description: String, systemImage: String) {
        self.mode = mode
        self.name = name
        self.description = description
        self.systemImage = systemImage
    }
}

public class ViewModeService: ObservableObject {
    public static let shared = ViewModeService()

    private let prefKey = "dovvoplay_library_view_mode_v3"

    public static let modes: [LibraryViewModeInfo] = [
        LibraryViewModeInfo(
            mode: .modernCards,
            name: "Card Moderne (Default)",
            description: "Card sagomate con bordo riflettente, durata e miniature ampie",
            systemImage: "rectangle.grid.1x2.fill"
        ),
        LibraryViewModeInfo(
            mode: .compactList,
            name: "Lista Compatta Streamlined",
            description: "Righe compatte ad alta densità ideali per navigare centinaia di brani",
            systemImage: "list.bullet"
        ),
        LibraryViewModeInfo(
            mode: .gridCovers,
            name: "Griglia Copertine 2x2",
            description: "Focus visivo su grandi artwork quadrati con titoli sotto",
            systemImage: "square.grid.2x2.fill"
        ),
        LibraryViewModeInfo(
            mode: .gridCompact,
            name: "Mosaico Denso 3x3",
            description: "Tante copertine contemporaneamente a colpo d'occhio",
            systemImage: "square.grid.3x3.fill"
        ),
        LibraryViewModeInfo(
            mode: .cdJewelCase,
            name: "Custodie CD in Plexiglass",
            description: "Stile teca jewel case con cerniera trasparente e riflesso specchiato",
            systemImage: "opticaldisc.fill"
        ),
        LibraryViewModeInfo(
            mode: .vinylCrate,
            name: "Scaffale Vinili da Collezione",
            description: "Copertina vintage con vinile scanalato nero che fuoriesce",
            systemImage: "record.circle"
        ),
        LibraryViewModeInfo(
            mode: .cassetteTape,
            name: "Cassette Retrò Walkman",
            description: "Design nastro magnetico con rotelle e finestrella vintage",
            systemImage: "film"
        ),
        LibraryViewModeInfo(
            mode: .minimalTypography,
            name: "Tipografia Editoriale",
            description: "Layout pulito da rivista musicale con font marcati e micro-badge",
            systemImage: "text.alignleft"
        )
    ]

    @Published public var currentMode: LibraryViewMode

    public var currentInfo: LibraryViewModeInfo {
        return ViewModeService.modes.first(where: { $0.mode == currentMode }) ?? ViewModeService.modes[0]
    }

    private init() {
        let savedName = UserDefaults.standard.string(forKey: prefKey) ?? LibraryViewMode.modernCards.rawValue
        self.currentMode = LibraryViewMode(rawValue: savedName) ?? .modernCards
    }

    public func setViewMode(_ mode: LibraryViewMode) {
        self.currentMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: prefKey)
    }

    public func cycleNextMode() {
        if let idx = ViewModeService.modes.firstIndex(where: { $0.mode == currentMode }) {
            let nextIdx = (idx + 1) % ViewModeService.modes.count
            setViewMode(ViewModeService.modes[nextIdx].mode)
        }
    }
}
