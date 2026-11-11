import 'package:flutter/material.dart';
import '../../services/equalizer_service.dart';
import '../theme.dart';

class EqualizerSheet extends StatelessWidget {
  const EqualizerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EqualizerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eq = EqualizerService.instance;

    return ListenableBuilder(
      listenable: eq,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppTheme.goldBorder),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppTheme.goldGlow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.tune_rounded, color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Equalizzatore Audio',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          eq.isEnabled ? 'ATTIVO' : 'DISATTIVATO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: eq.isEnabled ? AppTheme.primary : AppTheme.textMuted,
                          ),
                        ),
                        Switch(
                          value: eq.isEnabled,
                          activeColor: AppTheme.primary,
                          onChanged: (val) => eq.setEnabled(val),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Presets chips scrollabili
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: EqualizerService.presets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final p = EqualizerService.presets[i];
                      final isSelected = eq.selectedPresetId == p.id;
                      return GestureDetector(
                        onTap: () => eq.selectPreset(p.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : AppTheme.goldBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(p.emoji, style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 6),
                              Text(
                                p.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.black : AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // 5 Bande di Frequenza Verticali
                Opacity(
                  opacity: eq.isEnabled ? 1.0 : 0.4,
                  child: IgnorePointer(
                    ignoring: !eq.isEnabled,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: List.generate(5, (index) {
                              final gain = eq.bandGains[index];
                              final label = EqualizerService.bandLabels[index];
                              final gainStr = gain > 0 ? '+${gain.toStringAsFixed(1)}' : gain.toStringAsFixed(1);

                              return Column(
                                children: [
                                  Text(
                                    gainStr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: gain != 0 ? AppTheme.primary : AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 150,
                                    child: RotatedBox(
                                      quarterTurns: -1,
                                      child: SliderTheme(
                                        data: SliderThemeData(
                                          trackHeight: 3.5,
                                          activeTrackColor: AppTheme.primary,
                                          inactiveTrackColor: Colors.white12,
                                          thumbColor: AppTheme.primary,
                                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                          overlayColor: AppTheme.primary.withOpacity(0.2),
                                        ),
                                        child: Slider(
                                          value: gain,
                                          min: -12.0,
                                          max: 12.0,
                                          onChanged: (val) {
                                            eq.setBandGain(index, val);
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.textSecondary,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                          const Divider(height: 20, color: Colors.white12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Preset attivo: ${eq.currentPreset.emoji} ${eq.currentPreset.name}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.textSecondary,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                ),
                                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                                label: const Text('Reset Flat', style: TextStyle(fontSize: 12)),
                                onPressed: () => eq.resetToFlat(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
