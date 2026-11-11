import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'services/backup_service.dart';
import 'services/library_service.dart';
import 'services/pc_sync_service.dart';
import 'services/theme_service.dart';
import 'services/wifi_server_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializza il background audio per consentire ascolto a schermo spento e controlli lock screen
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.dchietti.sborraplay.audio',
      androidNotificationChannelName: 'SborraPlay Audio',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    );
  } catch (e) {
    print('Avviso JustAudioBackground: $e');
  }

  // Configura la sessione audio per categoria playback (musica) e attivala
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await session.setActive(true);
  } catch (e) {
    print('Avviso AudioSession: $e');
  }

  // Inizializza e carica la libreria locale
  await LibraryService.instance.init();

  // Verifica e ripristina automaticamente backup dopo aggiornamenti se presente
  try {
    await BackupService.instance.autoRestoreIfEmpty();
  } catch (_) {}

  // Avvia il server di ricezione Wi-Fi: senza questo il PC Companion non puo'
  // inviare i brani con il push diretto (PUT /api/file/...).
  try {
    await WifiServerService.instance.start();
  } catch (e) {
    print('Avviso WifiServer: $e');
  }

  // Ritira dal PC i brani rimasti in coda (canale di pull): funziona anche se
  // il push era fallito perche' l'app era chiusa o in background.
  try {
    PcSyncService.instance.startAutoSync();
    PcSyncService.instance.syncPendingFromPc();
  } catch (e) {
    print('Avviso PcSync: $e');
  }

  runApp(const SborraPlayApp());
}

class SborraPlayApp extends StatelessWidget {
  const SborraPlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'SborraPlay',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: const HomeScreen(),
        );
      },
    );
  }
}
