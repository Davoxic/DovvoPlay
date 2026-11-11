import Foundation
import SwiftUI

public enum TrackTransitionType: String, CaseIterable, Identifiable {
    public var id: String { rawValue }

    case slideHorizontal
    case slideVertical
    case fadeDissolve
    case explosionZoom
    case implosionShrink
    case vinylSpin
    case cube3d
    case fallingDrop
    case floatingBubble
    case glitchCyber
    case portalRipple
    case cardStack
    case pageCurl
    case heartbeatPulse
    case kaleidoscope
    case carousel3d
}

public struct TrackAnimationTheme: Identifiable, Equatable {
    public var id: String { type.rawValue }
    public let type: TrackTransitionType
    public let name: String
    public let description: String
    public let systemImage: String

    public init(type: TrackTransitionType, name: String, description: String, systemImage: String) {
        self.type = type
        self.name = name
        self.description = description
        self.systemImage = systemImage
    }
}

public class AnimationThemeService: ObservableObject {
    public static let shared = AnimationThemeService()

    private let prefKey = "dovvoplay_track_transition_type_v3"

    public static let animations: [TrackAnimationTheme] = [
        TrackAnimationTheme(
            type: .slideHorizontal,
            name: "Scorrimento Orizzontale",
            description: "Scivolamento fluido a destra o sinistra come uno swipe naturale",
            systemImage: "arrow.left.and.right"
        ),
        TrackAnimationTheme(
            type: .fadeDissolve,
            name: "Dissolvenza Incrociata Cinematica",
            description: "Transizione vellutata e progressiva a scomparsa",
            systemImage: "circle.lefthalf.filled"
        ),
        TrackAnimationTheme(
            type: .explosionZoom,
            name: "Esplosione & Zoom Shockwave",
            description: "La copertina esplode verso l'osservatore con bagliore energetico",
            systemImage: "sparkles"
        ),
        TrackAnimationTheme(
            type: .implosionShrink,
            name: "Implosione & Risucchio al Centro",
            description: "Il brano precedente viene risucchiato e il nuovo sboccia dal centro",
            systemImage: "arrow.down.right.and.arrow.up.left"
        ),
        TrackAnimationTheme(
            type: .vinylSpin,
            name: "Rotazione Disco in Vinile 360°",
            description: "Gira a tutta velocità come un vinile appoggiato sul piatto",
            systemImage: "opticaldisc"
        ),
        TrackAnimationTheme(
            type: .cube3d,
            name: "Rotazione Cubo 3D",
            description: "Effetto rotazione prospettica su faccia cubica tridimensionale",
            systemImage: "cube.fill"
        ),
        TrackAnimationTheme(
            type: .fallingDrop,
            name: "Caduta Gravitazionale & Rimbalzo",
            description: "Il nuovo brano cade dall'alto con fisica elastica d'impatto",
            systemImage: "arrow.down.circle"
        ),
        TrackAnimationTheme(
            type: .floatingBubble,
            name: "Fluttuazione Ascendente Spaziale",
            description: "Sale dal basso ondeggiando morbidamente a zero gravità",
            systemImage: "bubble.left.and.bubble.right"
        ),
        TrackAnimationTheme(
            type: .slideVertical,
            name: "Ascensore Verticale",
            description: "Scorrimento pulito dall'alto verso il basso",
            systemImage: "arrow.up.and.down"
        ),
        TrackAnimationTheme(
            type: .glitchCyber,
            name: "Glitch Cibernetico",
            description: "Distorsione digitale cyberpunk con micro-spostamenti rapidi",
            systemImage: "bolt.fill"
        ),
        TrackAnimationTheme(
            type: .portalRipple,
            name: "Onda Concentrica Portale",
            description: "Onda d'urto ad anello concentrico che deforma lo spazio",
            systemImage: "waveform.circle"
        ),
        TrackAnimationTheme(
            type: .cardStack,
            name: "Mazzo di Carte Sfogliate",
            description: "La copertina scivola in diagonale svelando la carta sottostante",
            systemImage: "square.stack.3d.up"
        ),
        TrackAnimationTheme(
            type: .pageCurl,
            name: "Sfoglia Pagina Libro",
            description: "Effetto voltapagina angolare 3D d'archivio",
            systemImage: "book.pages"
        ),
        TrackAnimationTheme(
            type: .heartbeatPulse,
            name: "Battito Cardiaco a Ritmo",
            description: "Doppia pulsazione cardiaca sincrona con la musica",
            systemImage: "heart.fill"
        ),
        TrackAnimationTheme(
            type: .kaleidoscope,
            name: "Caleidoscopio Stellare",
            description: "Rotazione geometrica ad apertura angolare prismatica",
            systemImage: "star.circle.fill"
        ),
        TrackAnimationTheme(
            type: .carousel3d,
            name: "Coverflow Tridimensionale",
            description: "Scivolamento in profondità sull'asse Z con prospettiva angolata",
            systemImage: "rectangle.stack.fill"
        )
    ]

    @Published public var selectedType: TrackTransitionType

    public var currentTheme: TrackAnimationTheme {
        return AnimationThemeService.animations.first(where: { $0.type == selectedType }) ?? AnimationThemeService.animations[2]
    }

    private init() {
        let savedName = UserDefaults.standard.string(forKey: prefKey) ?? TrackTransitionType.explosionZoom.rawValue
        self.selectedType = TrackTransitionType(rawValue: savedName) ?? .explosionZoom
    }

    public func setAnimationType(_ type: TrackTransitionType) {
        self.selectedType = type
        UserDefaults.standard.set(type.rawValue, forKey: prefKey)
    }

    public func cycleNext() {
        if let idx = AnimationThemeService.animations.firstIndex(where: { $0.type == selectedType }) {
            let nextIdx = (idx + 1) % AnimationThemeService.animations.count
            setAnimationType(AnimationThemeService.animations[nextIdx].type)
        }
    }

    public func cyclePrevious() {
        if let idx = AnimationThemeService.animations.firstIndex(where: { $0.type == selectedType }) {
            let prevIdx = (idx - 1 + AnimationThemeService.animations.count) % AnimationThemeService.animations.count
            setAnimationType(AnimationThemeService.animations[prevIdx].type)
        }
    }
}
