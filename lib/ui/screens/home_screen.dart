import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/mini_player.dart';
import 'library_tab.dart';
import 'youtube_tab.dart';
import 'wifi_tab.dart';
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
    YouTubeTab(),
    WifiTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music_rounded),
            label: 'Libreria',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.youtube_searched_for_rounded),
            label: 'YouTube',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wifi_tethering_rounded),
            label: 'Wi-Fi PC',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'Impostazioni',
          ),
        ],
      ),
    );
  }
}
