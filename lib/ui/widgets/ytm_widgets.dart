import 'package:flutter/material.dart';
import '../../models/track.dart';
import '../../services/audio_player_service.dart';
import '../../services/party_service.dart';
import '../../services/ytmusic_service.dart';
import '../screens/ytm_browse_screen.dart';
import '../theme.dart';
import 'song_actions_sheet.dart';
import 'track_artwork.dart';

/// Avvia un brano del catalogo online, con [coda] come seguito.
///
/// Da ospite di un party non si cambia brano per conto proprio: il tocco
/// diventa una richiesta di aggiunta alla coda dell'host.
void playOnlineTrack(Track track, List<Track> coda) {
  final player = AudioPlayerService.instance;
  if (PartyService.instance.isGuest) {
    player.addToQueue(track);
    return;
  }
  player.playTrack(track, newQueue: coda.isEmpty ? [track] : coda);
}

/// Apre un elemento del catalogo: un brano parte, il resto apre la sua pagina.
void openYtmItem(
  BuildContext context,
  YtmItem item, {
  List<YtmItem> fratelli = const [],
}) {
  if (item.isSong) {
    final coda = fratelli.where((i) => i.isSong).map((i) => i.toTrack()).toList();
    playOnlineTrack(item.toTrack(), coda);
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => YtmBrowseScreen(
        browseId: item.id,
        params: item.params,
        title: item.title,
        kind: item.kind,
      ),
    ),
  );
}

String formatTrackDuration(Duration d) {
  if (d.inSeconds <= 0) return '';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// Riga di un brano del catalogo online.
class YtmSongTile extends StatelessWidget {
  final YtmItem item;

  /// I brani dell'elenco in cui compare: toccandolo diventano la coda.
  final List<Track> coda;

  /// Numero di traccia, per gli album: sostituisce la copertina.
  final int? numero;

  const YtmSongTile({
    super.key,
    required this.item,
    this.coda = const [],
    this.numero,
  });

  @override
  Widget build(BuildContext context) {
    final track = item.toTrack();
    final sotto = <String>[];
    if (item.artist.isNotEmpty) sotto.add(item.artist);
    if (item.album.isNotEmpty && numero == null) sotto.add(item.album);
    final durata = formatTrackDuration(item.duration);

    return ValueListenableBuilder<String?>(
      valueListenable: AudioPlayerService.instance.currentTrackId,
      builder: (context, idCorrente, _) {
        final corrente = idCorrente == track.id;
        return InkWell(
          onTap: () => playOnlineTrack(track, coda),
          onLongPress: () => SongActionsSheet.show(context, track),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 7, 2, 7),
            child: Row(
              children: [
                if (numero != null)
                  SizedBox(
                    width: 30,
                    child: corrente
                        ? Icon(Icons.graphic_eq_rounded, color: AppTheme.primary, size: 18)
                        : Text(
                            '$numero',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                  )
                else
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      TrackArtwork(
                        url: track.thumbnailUrl,
                        width: 48,
                        height: 48,
                        borderRadius: 8,
                      ),
                      if (corrente)
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.graphic_eq_rounded,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                        ),
                    ],
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: corrente ? AppTheme.primary : AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                      ),
                      if (sotto.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          sotto.join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                        ),
                      ],
                    ],
                  ),
                ),
                if (durata.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      durata,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                    ),
                  ),
                IconButton(
                  icon: Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 20),
                  tooltip: 'Azioni sul brano',
                  onPressed: () => SongActionsSheet.show(context, track),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Riga di un album, artista o playlist nei risultati di ricerca.
class YtmCollectionTile extends StatelessWidget {
  final YtmItem item;
  const YtmCollectionTile({super.key, required this.item});

  String get _tipo {
    switch (item.kind) {
      case YtmKind.album:
        return 'Album';
      case YtmKind.artist:
        return 'Artista';
      case YtmKind.playlist:
        return 'Playlist';
      case YtmKind.song:
        return 'Brano';
      case YtmKind.mood:
        return 'Categoria';
    }
  }

  @override
  Widget build(BuildContext context) {
    final artista = item.kind == YtmKind.artist;
    final sotto = item.subtitle.isNotEmpty ? item.subtitle : _tipo;
    return InkWell(
      onTap: () => openYtmItem(context, item),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 7, 10, 7),
        child: Row(
          children: [
            TrackArtwork(
              url: item.thumbnailUrl,
              width: 52,
              height: 52,
              borderRadius: artista ? 26 : 8,
              placeholderIcon: artista
                  ? Icons.person_rounded
                  : (item.kind == YtmKind.playlist
                      ? Icons.queue_music_rounded
                      : Icons.album_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sotto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Scheda di un carosello.
class YtmCard extends StatelessWidget {
  final YtmItem item;
  final VoidCallback onTap;
  final double larghezza;

  const YtmCard({
    super.key,
    required this.item,
    required this.onTap,
    this.larghezza = 140,
  });

  @override
  Widget build(BuildContext context) {
    final artista = item.kind == YtmKind.artist;
    final track = item.isSong ? item.toTrack() : null;
    return GestureDetector(
      onTap: onTap,
      onLongPress: track == null ? null : () => SongActionsSheet.show(context, track),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: larghezza,
        child: Column(
          crossAxisAlignment:
              artista ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                TrackArtwork(
                  url: item.thumbnailUrl,
                  width: larghezza,
                  height: larghezza,
                  borderRadius: artista ? larghezza / 2 : 12,
                  placeholderIcon: artista
                      ? Icons.person_rounded
                      : (item.kind == YtmKind.playlist
                          ? Icons.queue_music_rounded
                          : Icons.album_rounded),
                ),
                if (item.isSong)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.play_arrow_rounded, color: AppTheme.primary, size: 20),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: artista ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.2,
              ),
            ),
            if (item.subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: artista ? TextAlign.center : TextAlign.start,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Titolo di una fila.
class YtmShelfTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const YtmShelfTitle({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Fila orizzontale di schede.
class YtmShelfCarousel extends StatelessWidget {
  final YtmShelf shelf;
  const YtmShelfCarousel({super.key, required this.shelf});

  @override
  Widget build(BuildContext context) {
    const larghezza = 140.0;
    return SizedBox(
      // Copertina, due righe di titolo e una di sottotitolo.
      height: larghezza + 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: shelf.items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final it = shelf.items[i];
          return YtmCard(
            item: it,
            larghezza: larghezza,
            onTap: () => openYtmItem(context, it, fratelli: shelf.items),
          );
        },
      ),
    );
  }
}

/// Fila di categorie "mood e generi", a pastiglie colorate.
class YtmMoodRow extends StatelessWidget {
  final List<YtmItem> items;

  /// true: tutte le categorie a capo, per la pagina dedicata.
  final bool aCapo;

  const YtmMoodRow({super.key, required this.items, this.aCapo = false});

  static Color coloreDi(YtmItem item) {
    if (item.color == 0) return AppTheme.primary;
    return Color(0xFF000000 | (item.color & 0x00FFFFFF));
  }

  Widget _pastiglia(BuildContext context, YtmItem it) {
    final colore = coloreDi(it);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => openYtmItem(context, it),
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 0, 14, 0),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.goldBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 42,
              decoration: BoxDecoration(
                color: colore,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              it.title,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (aCapo) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((it) => _pastiglia(context, it)).toList(),
        ),
      );
    }
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _pastiglia(context, items[i]),
      ),
    );
  }
}

/// Messaggio a tutto schermo per caricamento fallito o elenco vuoto.
class YtmMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  const YtmMessage({super.key, required this.icon, required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: AppTheme.primary.withOpacity(0.5)),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Riprova'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
