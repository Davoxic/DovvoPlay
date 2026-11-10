import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/mini_player.dart';
import 'library_tab.dart';
import 'playlist_tab.dart';
import 'settings_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Schermata di default su cui si apre: Libreria al centro (indice 1)
  int _currentIndex = 1;

  final List<Widget> _tabs = const [
    PlaylistTab(),  // Sinistra
    LibraryTab(),   // Centro (Default)
    SettingsTab(),  // Destra
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _tabs,
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.background,
          border: Border(
            top: BorderSide(
              color: AppTheme.goldBorder,
              width: 1.0,
            ),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: AppTheme.background,
          currentIndex: _currentIndex,
          onTap: (idx) => setState(() => _currentIndex = idx),
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.textMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.queue_music_rounded),
              activeIcon: Icon(Icons.queue_music_rounded, color: AppTheme.primary),
              label: 'Playlist',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.library_music_rounded),
              activeIcon: Icon(Icons.library_music_rounded, color: AppTheme.primary),
              label: 'Libreria',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              activeIcon: Icon(Icons.settings_rounded, color: AppTheme.primary),
              label: 'Impostazioni',
            ),
          ],
        ),
      ),
    );
  }
}
