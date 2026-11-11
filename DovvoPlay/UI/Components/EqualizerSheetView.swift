import SwiftUI

public struct EqualizerSheetView: View {
    @ObservedObject private var eq = EqualizerService.shared
    @Environment(\.presentationMode) private var presentationMode

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Master Toggle Card
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Equalizzatore Hardware")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.textPrimary)
                                Text("Elaborazione audio nativa a 5 bande")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { eq.isEnabled },
                                set: { eq.setEnabled($0) }
                            ))
                            .labelsHidden()
                            .tint(AppTheme.primary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppTheme.surfaceCard)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder, lineWidth: 1))
                        )

                        // Presets Horizontal Scroll
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PRESET EQUALIZZAZIONE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppTheme.secondary)
                                .padding(.horizontal, 4)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(EqualizerService.presets) { preset in
                                        let isSelected = eq.selectedPresetId == preset.id
                                        Button(action: {
                                            eq.selectPreset(preset.id)
                                        }) {
                                            HStack(spacing: 6) {
                                                Text(preset.emoji)
                                                Text(preset.name)
                                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                            }
                                            .foregroundColor(isSelected ? .black : AppTheme.textPrimary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .fill(isSelected ? AppTheme.primary : AppTheme.surfaceCard)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 20)
                                                            .stroke(isSelected ? AppTheme.primary : AppTheme.goldBorder, lineWidth: 1)
                                                    )
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        // Preamp Slider
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("PREAMP GAIN")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(AppTheme.secondary)
                                Spacer()
                                Text(String(format: "%+.1f dB", eq.preampGain))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppTheme.primary)
                            }

                            Slider(
                                value: Binding(
                                    get: { eq.preampGain },
                                    set: { eq.setPreampGain($0) }
                                ),
                                in: -6.0...6.0,
                                step: 0.5
                            )
                            .tint(AppTheme.primary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppTheme.surfaceCard)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder, lineWidth: 1))
                        )

                        // 5 Bands Sliders
                        VStack(spacing: 12) {
                            HStack {
                                Text("BANDE DI FREQUENZA")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(AppTheme.secondary)
                                Spacer()
                                Button(action: {
                                    eq.resetToFlat()
                                }) {
                                    Text("Reset a Flat")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(AppTheme.primary)
                                }
                            }

                            HStack(spacing: 14) {
                                ForEach(0..<5) { index in
                                    VStack(spacing: 10) {
                                        Text(String(format: "%+.0f", eq.bandGains[index]))
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(AppTheme.primary)

                                        // Vertical slider representation
                                        CustomVerticalSlider(
                                            value: Binding(
                                                get: { eq.bandGains[index] },
                                                set: { eq.setBandGain(index: index, gainDb: $0) }
                                            ),
                                            range: -12.0...12.0
                                        )
                                        .frame(width: 32, height: 160)

                                        Text(EqualizerService.bandLabels[index])
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(AppTheme.textSecondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(AppTheme.surfaceCard)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.goldBorder, lineWidth: 1))
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Equalizzatore Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fine") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(AppTheme.primary)
                    .font(.system(size: 16, weight: .bold))
                }
            }
        }
    }
}

private struct CustomVerticalSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let width = geo.size.width
            let totalRange = range.upperBound - range.lowerBound
            let normalized = (value - range.lowerBound) / totalRange
            let thumbY = height * CGFloat(1.0 - normalized)

            ZStack(alignment: .top) {
                // Track line
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 4, height: height)
                    .position(x: width / 2, y: height / 2)

                // Zero line marker
                Rectangle()
                    .fill(AppTheme.primary.opacity(0.5))
                    .frame(width: 14, height: 1)
                    .position(x: width / 2, y: height / 2)

                // Thumb knob
                Circle()
                    .fill(AppTheme.primary)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.black, lineWidth: 2))
                    .shadow(color: AppTheme.primary.opacity(0.4), radius: 4)
                    .position(x: width / 2, y: min(max(thumbY, 11), height - 11))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let y = gesture.location.y
                        let clampedY = min(max(y, 0), height)
                        let newNorm = 1.0 - Double(clampedY / height)
                        let newValue = range.lowerBound + newNorm * totalRange
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                    }
            )
        }
    }
}
