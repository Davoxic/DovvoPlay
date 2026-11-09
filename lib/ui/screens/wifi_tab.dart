import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/wifi_server_service.dart';
import '../theme.dart';

class WifiTab extends StatelessWidget {
  const WifiTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WifiServerService.instance,
      builder: (context, _) {
        final wifi = WifiServerService.instance;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Server Wi-Fi PC'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
            children: [
              // Card di stato Server
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: wifi.isRunning
                        ? [const Color(0xFF2C194D), AppTheme.surface]
                        : [AppTheme.surface, const Color(0xFF141022)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: wifi.isRunning ? AppTheme.primary.withOpacity(0.5) : const Color(0x1AFFFFFF),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: wifi.isRunning ? AppTheme.primary.withOpacity(0.2) : const Color(0x0FFFFFFF),
                      ),
                      child: Icon(
                        wifi.isRunning ? Icons.wifi_tethering_rounded : Icons.wifi_off_rounded,
                        size: 38,
                        color: wifi.isRunning ? AppTheme.primary : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      wifi.isRunning ? 'Server Attivo' : 'Server Non Attivo',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: wifi.isRunning ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      wifi.isRunning
                          ? 'Raggiungibile dai computer sulla stessa rete'
                          : 'Attiva il server per ricevere musica dal PC',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    if (wifi.isRunning) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x28FFFFFF)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              wifi.serverUrl,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentCyan,
                                fontFamily: 'monospace',
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                              tooltip: 'Copia indirizzo',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: wifi.serverUrl));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Indirizzo copiato negli appunti!')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: wifi.isRunning ? Colors.redAccent.withOpacity(0.8) : AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: Icon(wifi.isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white),
                        label: Text(
                          wifi.isRunning ? 'Spegni Server' : 'Accendi Server Wi-Fi',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        onPressed: () => wifi.toggle(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Istruzioni d'uso
              const Text(
                'COME TRASFERIRE MUSICA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),

              _buildInstructionStep(
                icon: Icons.wifi_rounded,
                step: '1',
                title: 'Stessa rete Wi-Fi',
                desc: 'Assicurati che iPhone e PC siano connessi alla stessa rete Wi-Fi.',
              ),
              _buildInstructionStep(
                icon: Icons.language_rounded,
                step: '2',
                title: 'Apri il browser sul PC',
                desc: 'Digita nella barra degli indirizzi l\'URL mostrato sopra (es. ${wifi.serverUrl}).',
              ),
              _buildInstructionStep(
                icon: Icons.drag_and_drop_rounded,
                step: '3',
                title: 'Trascina i brani',
                desc: 'Trascina i file MP3, M4A o FLAC nella pagina del browser. Verranno salvati subito sull\'iPhone!',
              ),

              if (wifi.recentUploads.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'CARICAMENTI RECENTI (${wifi.recentUploads.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                ...wifi.recentUploads.map(
                  (name) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x14FFFFFF)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstructionStep({
    required IconData icon,
    required String step,
    required String title,
    required String desc,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 14)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
