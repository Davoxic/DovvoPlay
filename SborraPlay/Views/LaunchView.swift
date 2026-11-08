import SwiftUI

/// Goccia densa che cola dall'alto.
private struct Drop {
    var x: CGFloat        // 0…1 rispetto alla larghezza
    var delay: Double
    var speed: Double     // schermate al secondo
    var radius: CGFloat
    var tail: CGFloat
    var opacity: Double
}

/// Schermata di apertura: una colata bianca che scende, il logo che emerge,
/// poi dissolvenza sulla home. Si salta toccando lo schermo.
struct LaunchView: View {

    var onFinish: () -> Void

    @State var drops: [Drop] = LaunchView.makeDrops()
    @State var startDate = Date()
    @State var logoShown = false
    @State var fadingOut = false
    @State var finished = false

    private static func makeDrops() -> [Drop] {
        var out: [Drop] = []
        for i in 0..<34 {
            let col = CGFloat(i) / 34.0
            out.append(Drop(x: col + CGFloat.random(in: -0.015...0.015),
                            delay: Double.random(in: 0...1.5),
                            speed: Double.random(in: 0.42...0.85),
                            radius: CGFloat.random(in: 7...19),
                            tail: CGFloat.random(in: 26...90),
                            opacity: Double.random(in: 0.55...1.0)))
        }
        return out
    }

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.05, blue: 0.13)
                .ignoresSafeArea()

            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSince(startDate)
                    drawPool(in: &context, size: size, time: t)
                    for drop in drops {
                        drawDrop(drop, in: &context, size: size, time: t)
                    }
                }
                .ignoresSafeArea()
            }

            VStack(spacing: 18) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .shadow(color: .white.opacity(0.35), radius: 28)
                    .scaleEffect(logoShown ? 1 : 0.62)
                    .opacity(logoShown ? 1 : 0)

                Text("SborraPlay")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(logoShown ? 1 : 0)
                    .offset(y: logoShown ? 0 : 14)
            }
        }
        .opacity(fadingOut ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .onAppear {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.62).delay(0.55)) {
                logoShown = true
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            await MainActor.run { finish() }
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        withAnimation(.easeInOut(duration: 0.45)) { fadingOut = true }
        Task {
            try? await Task.sleep(nanoseconds: 460_000_000)
            await MainActor.run { onFinish() }
        }
    }

    // MARK: - disegno

    /// La massa che pende dal bordo superiore e scende piano.
    private func drawPool(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let progress = min(time / 1.5, 1.0)
        let base = size.height * (0.07 + 0.3 * progress)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: size.width, y: 0))
        path.addLine(to: CGPoint(x: size.width, y: base))

        let steps = 28
        for i in stride(from: steps, through: 0, by: -1) {
            let f = CGFloat(i) / CGFloat(steps)
            let x = size.width * f
            let wave = sin(Double(f) * 11 + time * 1.3) * 16
                     + sin(Double(f) * 23 - time * 0.8) * 7
            path.addLine(to: CGPoint(x: x, y: base + CGFloat(wave)))
        }
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()

        context.fill(path, with: .linearGradient(
            Gradient(colors: [Color.white.opacity(0.95), Color.white.opacity(0.62)]),
            startPoint: .zero,
            endPoint: CGPoint(x: 0, y: base + 40)))
    }

    private func drawDrop(_ drop: Drop, in context: inout GraphicsContext, size: CGSize, time: Double) {
        let local = time - drop.delay
        guard local > 0 else { return }

        let cycle = 1.0 / drop.speed
        let phase = local.truncatingRemainder(dividingBy: cycle) / cycle
        let y = CGFloat(phase) * (size.height + drop.tail + 60) - drop.tail
        let x = drop.x * size.width + sin(local * 1.6 + Double(drop.x) * 9) * 4

        var shape = Path()
        shape.move(to: CGPoint(x: x, y: y - drop.tail))
        shape.addQuadCurve(to: CGPoint(x: x - drop.radius, y: y),
                           control: CGPoint(x: x - drop.radius * 0.72, y: y - drop.tail * 0.42))
        shape.addArc(center: CGPoint(x: x, y: y),
                     radius: drop.radius,
                     startAngle: .degrees(180),
                     endAngle: .degrees(0),
                     clockwise: false)
        shape.addQuadCurve(to: CGPoint(x: x, y: y - drop.tail),
                           control: CGPoint(x: x + drop.radius * 0.72, y: y - drop.tail * 0.42))
        shape.closeSubpath()

        context.fill(shape, with: .color(.white.opacity(drop.opacity * 0.9)))

        // riflesso
        var gleam = Path()
        gleam.addEllipse(in: CGRect(x: x - drop.radius * 0.42,
                                    y: y - drop.radius * 0.5,
                                    width: drop.radius * 0.42,
                                    height: drop.radius * 0.62))
        context.fill(gleam, with: .color(.white.opacity(min(drop.opacity + 0.2, 1))))
    }
}
