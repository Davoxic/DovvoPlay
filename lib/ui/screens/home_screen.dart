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
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    LibraryTab(),
    PlaylistTab(),
    SettingsTab(),
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
        decoration: const BoxDecoration(
          color: Color(0xFF000000),
          border: Border(
            top: BorderSide(
              color: AppTheme.goldBorder,
              width: 1.0,
            ),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF000000),
          currentIndex: _currentIndex,
          onTap: (idx) => setState(() => _currentIndex = idx),
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: const Color(0xFF756F62),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.library_music_rounded),
              activeIcon: Icon(Icons.library_music_rounded, color: AppTheme.primary),
              label: 'Libreria',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.queue_music_rounded),
              activeIcon: Icon(Icons.queue_music_rounded, color: AppTheme.primary),
              label: 'Playlist',
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
