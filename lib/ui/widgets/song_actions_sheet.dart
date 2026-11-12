import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/track.dart';
import '../../services/app_notice.dart';
import '../../services/audio_player_service.dart';
import '../../services/library_service.dart';
import '../../services/likes_service.dart';
import '../../services/party_service.dart';
import '../../services/yt_download_service.dart';
import '../theme.dart';
import 'track_artwork.dart';

/// Il menu di un brano: coda, cuore, playlist, radio, download, condivisione.
///
/// E' lo stesso ovunque compaia un brano, locale o in streaming, cosi' le
/// azioni si trovano sempre nello stesso posto. Si apre con la pressione
/// lunga oppure dai tre puntini.
class SongActionsSheet {
  SongActionsSheet._();

  static Future<void> show(
    BuildContext context,
    Track track, {
    bool allowDelete = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _Contenuto(
        track: track,
        allowDelete: allowDelete,
        // Il contesto della schermata sotto: serve per aprire altri fogli
        // dopo che questo si e' chiuso.
        contestoPagina: context,
      ),
    );
  }
}

class _Contenuto extends StatelessWidget {
  final Track track;
  final bool allowDelete;
  final BuildContext contestoPagina;

  const _Contenuto({
    required this.track,
    required this.allowDelete,
    required this.contestoPagina,
  });

  Widget _voce({
    required IconData icona,
    required String titolo,
    String? sottotitolo,
    Color? colore,
    required VoidCallback onTap,
  }) {
    final c = colore ?? AppTheme.textPrimary;
    return ListTile(
      dense: true,
      leading: Icon(icona, color: c, size: 22),
      title: Text(titolo, style: TextStyle(color: c, fontSize: 14.5)),
      subtitle: sottotitolo == null
          ? null
          : Text(
              sottotitolo,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
            ),
      onTap: onTap,
    );
  }

  Future<void> _condividi() async {
    try {
      if (track.id.startsWith('yt_')) {
        final id = track.id.substring(3);
        await Share.share(
          '${track.displayTitle} - ${track.displayArtist}\n'
          'https://music.youtube.com/watch?v=$id',
        );
      } else if (track.filePath != null) {
        await Share.shareXFiles(
          [XFile(track.filePath!)],
          text: '${track.displayTitle} - ${track.displayArtist}',
        );
      } else {
        await Share.share('${track.displayTitle} - ${track.displayArtist}');
      }
    } catch (_) {
      AppNotice.show('Impossibile condividere questo brano.');
    }
  }

  void _confermaElimina() {
    showDialog<void>(
      context: contestoPagina,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppTheme.goldBorder),
        ),
        title: Text(
          'Eliminare il file?',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 17),
        ),
        content: Text(
          '"${track.displayTitle}" verrà cancellato dal telefono e tolto da tutte le playlist.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: Text('Annulla', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              LibraryService.instance.deleteTrack(track);
              Navigator.pop(dctx);
            },
            child: const Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = AudioPlayerService.instance;
    final ospite = PartyService.instance.isGuest;
    final online = track.isOnline;
    final piace = LikesService.instance.isLiked(track);
    final scaricato = YtDownloadService.instance.isDownloaded(track);
    final statoDownload = YtDownloadService.instance.stateOf(track);
    final inScaricamento = statoDownload == YtDownloadState.queued ||
        statoDownload == YtDownloadState.downloading;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                child: Row(
                  children: [
                    TrackArtwork(
                      url: track.thumbnailUrl,
                      width: 52,
                      height: 52,
                      borderRadius: 10,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            online
                                ? '${track.displayArtist} • streaming'
                                : track.displayArtist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: AppTheme.goldBorder.withOpacity(0.5), height: 1),
              _voce(
                icona: Icons.playlist_play_rounded,
                titolo: 'Riproduci dopo',
                sottotitolo: 'Subito dopo il brano in riproduzione',
                onTap: () {
                  player.playNext(track);
                  Navigator.pop(context);
                  if (!ospite) AppNotice.show('Verrà riprodotto dopo');
                },
              ),
              _voce(
                icona: Icons.queue_rounded,
                titolo: 'Aggiungi alla coda',
                sottotitolo: 'Dopo gli altri brani accodati a mano',
                onTap: () {
                  player.addToQueue(track);
                  Navigator.pop(context);
                  if (!ospite) AppNotice.show('Aggiunto alla coda');
                },
              ),
              _voce(
                icona: piace ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                titolo: piace ? 'Rimuovi da Mi piace' : 'Mi piace',
                colore: piace ? AppTheme.primary : null,
                onTap: () async {
                  Navigator.pop(context);
                  final ora = await LikesService.instance.toggle(track);
                  AppNotice.show(
                    ora ? 'Aggiunto ai brani che ti piacciono' : 'Rimosso dai brani che ti piacciono',
                  );
                },
              ),
              _voce(
                icona: Icons.playlist_add_rounded,
                titolo: 'Aggiungi a playlist',
                onTap: () {
                  Navigator.pop(context);
                  PlaylistPickerSheet.show(contestoPagina, [track]);
                },
              ),
              _voce(
                icona: Icons.sensors_rounded,
                titolo: 'Avvia radio',
                sottotitolo: 'Una coda di musica simile a questo brano',
                onTap: () {
                  Navigator.pop(context);
                  player.startRadio(track);
                },
              ),
              if (online && !scaricato)
                _voce(
                  icona: inScaricamento
                      ? Icons.downloading_rounded
                      : Icons.download_rounded,
                  titolo: inScaricamento ? 'Download in corso' : 'Scarica sul telefono',
                  sottotitolo: inScaricamento
                      ? 'Lo trovi in Download'
                      : 'Per ascoltarlo anche senza rete',
                  onTap: () {
                    Navigator.pop(context);
                    if (inScaricamento) return;
                    YtDownloadService.instance.enqueue(track);
                    AppNotice.show('Download avviato: ${track.displayTitle}');
                  },
                ),
              if (online && scaricato)
                _voce(
                  icona: Icons.download_done_rounded,
                  titolo: 'Già scaricato',
                  colore: AppTheme.textMuted,
                  onTap: () => Navigator.pop(context),
                ),
              _voce(
                icona: Icons.ios_share_rounded,
                titolo: 'Condividi',
                onTap: () {
                  Navigator.pop(context);
                  _condividi();
                },
              ),
              if (!online && allowDelete && track.filePath != null)
                _voce(
                  icona: Icons.delete_outline_rounded,
                  titolo: 'Elimina file',
                  colore: Colors.redAccent,
                  onTap: () {
                    Navigator.pop(context);
                    _confermaElimina();
                  },
                ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scelta della playlist a cui aggiungere uno o piu' brani.
class PlaylistPickerSheet {
  PlaylistPickerSheet._();

  static Future<void> show(BuildContext context, List<Track> tracks) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _SceltaPlaylist(tracks: tracks),
    );
  }

  /// Aggiunge i brani a una playlist, ricordando prima quelli in streaming:
  /// altrimenti la playlist conterrebbe solo un id che l'app non sa mostrare.
  static Future<int> addTo(String playlistId, List<Track> tracks) async {
    final lib = LibraryService.instance;
    var aggiunti = 0;
    for (final t in tracks) {
      if (t.isOnline) await lib.rememberOnlineTrack(t);
      final pl = lib.playlists.where((p) => p.id == playlistId);
      if (pl.isEmpty) break;
      if (pl.first.trackIds.contains(t.id)) continue;
      await lib.addTrackToPlaylist(playlistId, t.id);
      aggiunti++;
    }
    return aggiunti;
  }
}

class _SceltaPlaylist extends StatefulWidget {
  final List<Track> tracks;
  const _SceltaPlaylist({required this.tracks});

  @override
  State<_SceltaPlaylist> createState() => _SceltaPlaylistState();
}

class _SceltaPlaylistState extends State<_SceltaPlaylist> {
  final TextEditingController _nome = TextEditingController();
  bool _creazione = false;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _crea() async {
    final nome = _nome.text.trim();
    if (nome.isEmpty) return;
    final pl = await LibraryService.instance.createPlaylist(nome);
    final n = await PlaylistPickerSheet.addTo(pl.id, widget.tracks);
    if (!mounted) return;
    Navigator.pop(context);
    AppNotice.show(
      n == 1 ? 'Aggiunto a "$nome"' : '$n brani aggiunti a "$nome"',
    );
  }

  @override
  Widget build(BuildContext context) {
    final uno = widget.tracks.length == 1 ? widget.tracks.first : null;

    return Padding(
      // Sale sopra la tastiera quando si scrive il nome di una playlist.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: ListenableBuilder(
            listenable: LibraryService.instance,
            builder: (context, _) {
              final playlists = LibraryService.instance.playlists;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                    child: Text(
                      uno != null
                          ? 'Aggiungi a playlist'
                          : 'Aggiungi ${widget.tracks.length} brani a playlist',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (_creazione)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nome,
                              autofocus: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _crea(),
                              style: TextStyle(color: AppTheme.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Nome playlist',
                                hintStyle: TextStyle(color: AppTheme.textMuted),
                                isDense: true,
                                filled: true,
                                fillColor: AppTheme.surfaceCard,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppTheme.goldBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppTheme.primary),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 30),
                            tooltip: 'Crea',
                            onPressed: _crea,
                          ),
                        ],
                      ),
                    )
                  else
                    ListTile(
                      leading: Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary),
                      title: Text(
                        'Nuova playlist',
                        style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600),
                      ),
                      onTap: () => setState(() => _creazione = true),
                    ),
                  if (playlists.isEmpty && !_creazione)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      child: Text(
                        'Ancora nessuna playlist. Usa la riga sopra per crearne una.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  if (playlists.isNotEmpty)
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: playlists.length,
                        itemBuilder: (c, i) {
                          final pl = playlists[i];
                          final giaDentro = uno != null && pl.trackIds.contains(uno.id);
                          return ListTile(
                            leading: Icon(Icons.queue_music_rounded, color: AppTheme.primary),
                            title: Text(pl.name, style: TextStyle(color: AppTheme.textPrimary)),
                            subtitle: Text(
                              '${pl.trackIds.length} brani',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                            trailing: Icon(
                              giaDentro ? Icons.check_rounded : Icons.add_rounded,
                              color: giaDentro ? AppTheme.primary : AppTheme.textSecondary,
                            ),
                            onTap: () async {
                              if (giaDentro && uno != null) {
                                await LibraryService.instance
                                    .removeTrackFromPlaylist(pl.id, uno.id);
                                AppNotice.show('Rimosso da "${pl.name}"');
                              } else {
                                final n = await PlaylistPickerSheet.addTo(pl.id, widget.tracks);
                                AppNotice.show(
                                  n == 0
                                      ? 'Già nella playlist'
                                      : n == 1
                                          ? 'Aggiunto a "${pl.name}"'
                                          : '$n brani aggiunti a "${pl.name}"',
                                );
                              }
                              if (c.mounted) Navigator.pop(c);
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
