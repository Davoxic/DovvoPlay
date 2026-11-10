import 'package:flutter/material.dart';
import '../../services/audio_player_service.dart';
import '../../services/pc_sync_service.dart';
import '../../services/soundcloud_service.dart';
import '../../services/spotify_service.dart';
import '../../services/youtube_service.dart';
import '../theme.dart';
import '../widgets/track_artwork.dart';

class PcCompanionScreen extends StatefulWidget {
  const PcCompanionScreen({super.key});

  @override
  State<PcCompanionScreen> createState() => _PcCompanionScreenState();
}

class _PcCompanionScreenState extends State<PcCompanionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final TextEditingController _ipCtrl = TextEditingController();
  final TextEditingController _portCtrl = TextEditingController();
  final TextEditingController _playlistUrlCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _delegatePlaylistToPc = false;
  bool _isProcessingPlaylist = false;
  String _playlistStatusText = '';

  bool _isSearchingSources = false;
  List<dynamic> _searchResults = []; // YouTubeTrack | SpotifyItem | SoundCloudTrack

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _ipCtrl.text = PcSyncService.instance.pcHost;
    _portCtrl.text = PcSyncService.instance.pcPort.toString();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _playlistUrlCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearchingSources = true;
      _searchResults = [];
    });

    try {
      if (_tabCtrl.index == 0) {
        // YouTube
        final res = await YouTubeService.instance.search(query);
        setState(() => _searchResults = res);
      } else if (_tabCtrl.index == 1) {
        // Spotify
        final res = await SpotifyService.instance.search(query);
        setState(() => _searchResults = res);
      } else {
        // SoundCloud
        final res = await SoundCloudService.instance.search(query);
        setState(() => _searchResults = res);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante la ricerca: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingSources = false);
      }
    }
  }

  Future<void> _importPlaylist() async {
    final url = _playlistUrlCtrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci prima il link della playlist Spotify')),
      );
      return;
    }

    setState(() {
      _isProcessingPlaylist = true;
      _playlistStatusText = 'Avvio analisi...';
    });

    final count = await PcSyncService.instance.importSpotifyPlaylist(
      url,
      delegateToPc: _delegatePlaylistToPc,
      onStatus: (step) {
        if (mounted) {
          setState(() => _playlistStatusText = step);
        }
      },
    );

    if (mounted) {
      setState(() => _isProcessingPlaylist = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0 ? 'Operazione completata con successo!' : 'Analisi completata.',
          ),
          backgroundColor: AppTheme.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('PC Companion & Sorgenti Web'),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_find_rounded),
            tooltip: 'Cerca PC su rete locale',
            onPressed: () => PcSyncService.instance.discoverPcOnLan(),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: PcSyncService.instance,
        builder: (context, _) {
          final sync = PcSyncService.instance;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            children: [
              // 1. STATO CONNESSIONE PC
              _buildPcStatusCard(sync),

              const SizedBox(height: 18),

              // 2. CONVERTITORE PLAYLIST SPOTIFY
              _buildSpotifyConverterCard(),

              const SizedBox(height: 22),

              // 3. CENTRO RICERCA MULTI-PIATTAFORMA (YOUTUBE / SPOTIFY / SOUNDCLOUD)
              _buildSearchHubCard(),

              const SizedBox(height: 14),

              // RISULTATI RICERCA
              if (_isSearchingSources)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                )
              else if (_searchResults.isNotEmpty)
                ..._searchResults.map((item) => _buildResultTile(item)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPcStatusCard(PcSyncService sync) {
    if (sync.pcHost.isNotEmpty && (_ipCtrl.text.isEmpty || sync.isConnected)) {
      if (_ipCtrl.text != sync.pcHost) _ipCtrl.text = sync.pcHost;
      if (_portCtrl.text != sync.pcPort.toString()) _portCtrl.text = sync.pcPort.toString();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: sync.isConnected ? Colors.greenAccent : AppTheme.goldBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sync.isConnected
                      ? Colors.greenAccent.withOpacity(0.18)
                      : Colors.orangeAccent.withOpacity(0.18),
                ),
                child: Icon(
                  sync.isConnected ? Icons.laptop_windows_rounded : Icons.wifi_off_rounded,
                  color: sync.isConnected ? Colors.greenAccent : Colors.orangeAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sync.isConnected ? 'PC Companion Connesso' : 'Ricerca Server PC su Rete',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                    ),
                    Text(
                      sync.statusMessage,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _ipCtrl,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'IP Computer (LAN)',
                    labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    hintText: '192.168.1.50',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.goldBorder)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _portCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Porta',
                    labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    hintText: '8080',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppTheme.goldBorder)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final p = int.tryParse(_portCtrl.text.trim()) ?? 8080;
                  sync.setHostAndPort(_ipCtrl.text.trim(), p);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Connetti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Nota: il PC deve essere connesso allo stesso Wi-Fi dell\'iPhone e la porta 8080 sbloccata nel Firewall.',
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withOpacity(0.8)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: sync.isSearching
                  ? null
                  : () => sync.discoverPcOnLan(port: int.tryParse(_portCtrl.text) ?? 8080),
              icon: sync.isSearching
                  ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                  : const Icon(Icons.radar_rounded, size: 16),
              label: Text(
                sync.isSearching ? 'Scansione subnet in corso...' : 'Trova PC automaticamente (Ping su rete)',
                style: const TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(color: AppTheme.goldBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotifyConverterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.playlist_add_check_circle_rounded, color: Color(0xFF1DB954), size: 22),
              const SizedBox(width: 10),
              Text(
                'Importa Playlist Spotify',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Incolla il link di una playlist o album Spotify per importarla e salvarla nella tua libreria.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _playlistUrlCtrl,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'https://open.spotify.com/playlist/...',
              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              prefixIcon: const Icon(Icons.link_rounded, size: 20, color: Color(0xFF1DB954)),
              filled: true,
              fillColor: Colors.black,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.goldBorder)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _delegatePlaylistToPc
                      ? 'Delega elaborazione al server PC'
                      : 'Analisi locale & ricerca automatica',
                  style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                ),
              ),
              Switch(
                value: _delegatePlaylistToPc,
                activeColor: AppTheme.primary,
                onChanged: (val) => setState(() => _delegatePlaylistToPc = val),
              ),
            ],
          ),
          if (_playlistStatusText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text(
                _playlistStatusText,
                style: TextStyle(fontSize: 12, color: AppTheme.primary, fontStyle: FontStyle.italic),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isProcessingPlaylist ? null : _importPlaylist,
              icon: _isProcessingPlaylist
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Icon(Icons.sync_rounded, size: 18),
              label: Text(
                _isProcessingPlaylist ? 'Elaborazione in corso...' : 'Avvia Importazione Playlist',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHubCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RICERCA WEB & DOWNLOAD DA PC',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppTheme.secondary),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.goldBorder),
          ),
          child: TabBar(
            controller: _tabCtrl,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: const [
              Tab(text: 'YouTube'),
              Tab(text: 'Spotify'),
              Tab(text: 'SoundCloud'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchCtrl,
          onSubmitted: (_) => _performSearch(),
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Cerca brano o artista...',
            hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primary),
            suffixIcon: IconButton(
              icon: Icon(Icons.send_rounded, color: AppTheme.primary),
              onPressed: _performSearch,
            ),
            filled: true,
            fillColor: AppTheme.surfaceCard,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppTheme.goldBorder)),
          ),
        ),
      ],
    );
  }

  Widget _buildResultTile(dynamic item) {
    String title = '';
    String artist = '';
    String thumb = '';
    String service = 'youtube';

    if (item is SpotifyItem) {
      title = item.title;
      artist = item.artist;
      thumb = item.thumbnailUrl;
      service = 'spotify';
    } else if (item is SoundCloudTrack) {
      title = item.title;
      artist = item.author;
      thumb = item.thumbnailUrl;
      service = 'soundcloud';
    } else {
      // YouTubeTrack
      title = item.title;
      artist = item.author;
      thumb = item.thumbnailUrl;
      service = 'youtube';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.goldBorder),
      ),
      child: ListTile(
        leading: TrackArtwork(
          url: thumb,
          width: 46,
          height: 46,
          borderRadius: 8,
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          '$artist • ${service.toUpperCase()}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.send_to_mobile_rounded, color: AppTheme.primary, size: 22),
              tooltip: 'Richiedi download al PC',
              onPressed: () async {
                final sent = await PcSyncService.instance.sendDownloadRequest(
                  service: service,
                  queryOrUrl: '$artist - $title',
                  title: title,
                  artist: artist,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(sent ? 'Richiesta inviata al PC!' : 'PC non raggiungibile o offline.'),
                      backgroundColor: sent ? AppTheme.primary : Colors.redAccent,
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.play_circle_fill_rounded, color: AppTheme.secondary, size: 24),
              tooltip: 'Riproduci ora',
              onPressed: () async {
                // Cerca la versione audio stream su YouTube per riproduzione immediata
                final ytResults = await YouTubeService.instance.search('$artist - $title');
                if (ytResults.isNotEmpty) {
                  AudioPlayerService.instance.playTrack(ytResults.first.toTrack());
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
