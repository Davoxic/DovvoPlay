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
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: const Text('Server Wi-Fi PC'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              // Card di stato Server
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.goldSurfaceGradient,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: wifi.isRunning ? AppTheme.primary : AppTheme.goldBorder,
                    width: 1.3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: wifi.isRunning ? const Color(0x33FFD700) : Colors.transparent,
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: wifi.isRunning ? const Color(0x33FFD700) : const Color(0x11FFFFFF),
                        border: Border.all(
                          color: wifi.isRunning ? AppTheme.primary : AppTheme.goldBorder,
                          width: 1.5,
                        ),
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
                        color: wifi.isRunning ? AppTheme.primary : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      wifi.isRunning
                          ? 'Raggiungibile dai computer sulla stessa rete Wi-Fi'
                          : 'Attiva il server per caricare musica dal tuo PC',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    if (wifi.isRunning) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.goldBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              wifi.serverUrl,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                                fontFamily: 'monospace',
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: AppTheme.primary, size: 20),
                              tooltip: 'Copia indirizzo',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: wifi.serverUrl));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Indirizzo copiato negli appunti!'),
                                    backgroundColor: AppTheme.secondary,
                                  ),
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
                          backgroundColor: wifi.isRunning ? Colors.redAccent.shade700 : AppTheme.primary,
                          foregroundColor: wifi.isRunning ? Colors.white : Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: Icon(wifi.isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded),
                        label: Text(
                          wifi.isRunning ? 'Spegni Server' : 'Accendi Server Wi-Fi',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => wifi.toggle(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Istruzioni d'uso
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'COME TRASFERIRE MUSICA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.3,
                    color: AppTheme.secondary,
                  ),
                ),
              ),

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
                icon: Icons.upload_file_rounded,
                step: '3',
                title: 'Trascina i brani',
                desc: 'Trascina i file MP3, M4A o FLAC nella pagina del browser. Verranno salvati subito sull\'iPhone!',
              ),

              if (wifi.recentUploads.isNotEmpty) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    'CARICAMENTI RECENTI (${wifi.recentUploads.length})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.3,
                      color: AppTheme.secondary,
                    ),
                  ),
                ),
                ...wifi.recentUploads.map(
                  (name) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.goldBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18),
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
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0x22FFD700),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary),
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
