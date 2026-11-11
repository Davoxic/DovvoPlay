import SwiftUI

public struct AnimatedTrackTransitionView<Content: View>: View {
    public let trackId: String
    @ViewBuilder public let content: () -> Content

    @ObservedObject private var animService = AnimationThemeService.shared

    public init(trackId: String, @ViewBuilder content: @escaping () -> Content) {
        self.trackId = trackId
        self.content = content
    }

    public var body: some View {
        ZStack {
            content()
                .id(trackId)
                .transition(transitionForType(animService.selectedType))
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: trackId)
    }

    private func transitionForType(_ type: TrackTransitionType) -> AnyTransition {
        switch type {
        case .slideHorizontal:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .slideVertical:
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )
        case .fadeDissolve:
            return .opacity
        case .explosionZoom:
            return .scale(scale: 0.2).combined(with: .opacity)
        case .implosionShrink:
            return .scale(scale: 1.8).combined(with: .opacity)
        case .vinylSpin:
            return .modifier(
                active: SpinModifier(angle: -180, scale: 0.6, opacity: 0),
                identity: SpinModifier(angle: 0, scale: 1.0, opacity: 1)
            )
        case .cube3d:
            return .modifier(
                active: Cube3DModifier(angle: 90, opacity: 0),
                identity: Cube3DModifier(angle: 0, opacity: 1)
            )
        case .fallingDrop:
            return .asymmetric(
                insertion: .offset(y: -250).combined(with: .opacity),
                removal: .offset(y: 250).combined(with: .opacity)
            )
        case .floatingBubble:
            return .asymmetric(
                insertion: .offset(y: 200).combined(with: .scale(scale: 0.8)).combined(with: .opacity),
                removal: .offset(y: -200).combined(with: .scale(scale: 1.2)).combined(with: .opacity)
            )
        case .glitchCyber:
            return .modifier(
                active: GlitchModifier(offset: 20, opacity: 0.2),
                identity: GlitchModifier(offset: 0, opacity: 1)
            )
        case .portalRipple:
            return .scale(scale: 0.05).combined(with: .opacity)
        case .cardStack:
            return .asymmetric(
                insertion: .offset(x: 120, y: -40).combined(with: .opacity),
                removal: .offset(x: -120, y: 40).combined(with: .opacity)
            )
        case .pageCurl:
            return .modifier(
                active: PageCurlModifier(angle: -45, opacity: 0),
                identity: PageCurlModifier(angle: 0, opacity: 1)
            )
        case .heartbeatPulse:
            return .scale(scale: 1.25).combined(with: .opacity)
        case .kaleidoscope:
            return .modifier(
                active: SpinModifier(angle: 360, scale: 0.1, opacity: 0),
                identity: SpinModifier(angle: 0, scale: 1.0, opacity: 1)
            )
        case .carousel3d:
            return .modifier(
                active: Cube3DModifier(angle: -60, opacity: 0),
                identity: Cube3DModifier(angle: 0, opacity: 1)
            )
        }
    }
}

private struct SpinModifier: ViewModifier {
    let angle: Double
    let scale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .scaleEffect(scale)
            .opacity(opacity)
    }
}

private struct Cube3DModifier: ViewModifier {
    let angle: Double
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0))
            .opacity(opacity)
    }
}

private struct GlitchModifier: ViewModifier {
    let offset: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .offset(x: offset, y: -offset / 2)
            .opacity(opacity)
    }
}

private struct PageCurlModifier: ViewModifier {
    let angle: Double
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 1, z: 0))
            .opacity(opacity)
    }
}
