import Foundation
import AVFoundation
import SwiftUI

public struct EqPreset: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let emoji: String
    public let gains: [Double] // 5 bands in dB (-12.0 to +12.0)

    public init(id: String, name: String, emoji: String, gains: [Double]) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.gains = gains
    }
}

public class EqualizerService: ObservableObject {
    public static let shared = EqualizerService()

    private let prefKey = "dovvoplay_eq_settings_v3"

    public static let bandLabels: [String] = [
        "60 Hz\nSub",
        "230 Hz\nBass",
        "910 Hz\nMid",
        "3.6 kHz\nHigh",
        "14 kHz\nAir"
    ]

    public static let bandFrequencies: [Float] = [60.0, 230.0, 910.0, 3600.0, 14000.0]

    public static let presets: [EqPreset] = [
        EqPreset(id: "flat", name: "Flat (Neutro)", emoji: "🎵", gains: [0, 0, 0, 0, 0]),
        EqPreset(id: "bass", name: "Bass Boost", emoji: "🔊", gains: [7.0, 5.0, 0.0, 0.0, 0.0]),
        EqPreset(id: "rock", name: "Rock", emoji: "🎸", gains: [5.0, 3.0, -1.0, 3.0, 6.0]),
        EqPreset(id: "pop", name: "Pop", emoji: "🎤", gains: [-1.0, 2.0, 5.0, 3.0, -1.0]),
        EqPreset(id: "hiphop", name: "Hip-Hop", emoji: "🎧", gains: [6.0, 4.0, 0.0, 2.0, 3.0]),
        EqPreset(id: "electronic", name: "Electronic", emoji: "⚡", gains: [6.0, 4.0, 0.0, 3.0, 5.0]),
        EqPreset(id: "jazz", name: "Jazz & Warm", emoji: "🎷", gains: [3.0, 2.0, 1.0, 2.0, 4.0]),
        EqPreset(id: "vocal", name: "Vocal Boost", emoji: "🗣️", gains: [-3.0, 0.0, 6.0, 4.0, -1.0]),
        EqPreset(id: "acoustic", name: "Acoustic", emoji: "🎻", gains: [3.0, 2.0, 2.0, 4.0, 3.0]),
        EqPreset(id: "custom", name: "Personalizzato", emoji: "🛠️", gains: [0, 0, 0, 0, 0])
    ]

    @Published public var isEnabled: Bool = true
    @Published public var selectedPresetId: String = "flat"
    @Published public var bandGains: [Double] = [0.0, 0.0, 0.0, 0.0, 0.0]
    @Published public var preampGain: Double = 0.0 // dB (-6 to +6)

    // Hardware AudioUnit Equalizer
    public let audioUnitEQ: AVAudioUnitEQ

    public var currentPreset: EqPreset {
        return EqualizerService.presets.first(where: { $0.id == selectedPresetId }) ?? EqualizerService.presets[0]
    }

    private init() {
        self.audioUnitEQ = AVAudioUnitEQ(numberOfBands: 5)
        setupAudioUnitEQ()
        loadFromPrefs()
        applyToAudioUnit()
    }

    private func setupAudioUnitEQ() {
        for (i, freq) in EqualizerService.bandFrequencies.enumerated() {
            guard i < audioUnitEQ.bands.count else { break }
            let band = audioUnitEQ.bands[i]
            band.frequency = freq
            band.filterType = .parametric
            band.bandwidth = 1.0
            band.gain = 0.0
            band.bypass = false
        }
    }

    public func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
        applyToAudioUnit()
        saveToPrefs()
    }

    public func selectPreset(_ presetId: String) {
        guard let preset = EqualizerService.presets.first(where: { $0.id == presetId }) else { return }
        self.selectedPresetId = preset.id
        if preset.id != "custom" {
            self.bandGains = preset.gains
        }
        applyToAudioUnit()
        saveToPrefs()
    }

    public func setBandGain(index: Int, gainDb: Double) {
        guard index >= 0 && index < bandGains.count else { return }
        bandGains[index] = min(max(gainDb, -12.0), 12.0)
        selectedPresetId = "custom"
        applyToAudioUnit()
        saveToPrefs()
    }

    public func setPreampGain(_ gainDb: Double) {
        preampGain = min(max(gainDb, -6.0), 6.0)
        applyToAudioUnit()
        saveToPrefs()
    }

    public func resetToFlat() {
        selectPreset("flat")
        preampGain = 0.0
        applyToAudioUnit()
        saveToPrefs()
    }

    public func applyToAudioUnit() {
        audioUnitEQ.bypass = !isEnabled
        audioUnitEQ.globalGain = Float(preampGain)

        for (i, gain) in bandGains.enumerated() {
            guard i < audioUnitEQ.bands.count else { break }
            let band = audioUnitEQ.bands[i]
            band.gain = Float(gain)
            band.bypass = !isEnabled
        }
    }

    private func loadFromPrefs() {
        if let data = UserDefaults.standard.data(forKey: prefKey),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            self.isEnabled = json["isEnabled"] as? Bool ?? true
            self.selectedPresetId = json["selectedPresetId"] as? String ?? "flat"
            self.preampGain = json["preampGain"] as? Double ?? 0.0
            if let gains = json["bandGains"] as? [Double], gains.count == 5 {
                self.bandGains = gains
            }
        }
    }

    private func saveToPrefs() {
        let dict: [String: Any] = [
            "isEnabled": isEnabled,
            "selectedPresetId": selectedPresetId,
            "preampGain": preampGain,
            "bandGains": bandGains
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict) {
            UserDefaults.standard.set(data, forKey: prefKey)
        }
    }
}
