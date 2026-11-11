import 'dart:async';
import 'package:flutter/foundation.dart';
import 'pc_sync_service.dart';

/// Cosa c'e' in coda: una playlist da importare, o un singolo brano.
enum DownloadJobKind { playlist, singolo }

/// Stato di una voce in coda.
enum DownloadJobStatus { attesa, inCorso, completato, errore, annullato }

/// Una richiesta di download messa in coda.
///
/// Non e' una coda di riproduzione: qui ci sono le operazioni da far fare al
/// PC, in ordine cronologico di inserimento.
class DownloadJob {
  final String id;
  final DownloadJobKind kind;
  final String url;
  final String label;
  final bool createPlaylist;
  final DateTime addedAt;

  DownloadJobStatus status;
  String? error;
  int received;
  int total;

  DownloadJob({
    required this.id,
    required this.kind,
    required this.url,
    required this.label,
    this.createPlaylist = false,
    DateTime? addedAt,
    this.status = DownloadJobStatus.attesa,
    this.error,
    this.received = 0,
    this.total = 0,
  }) : addedAt = addedAt ?? DateTime.now();

  bool get isDone =>
      status == DownloadJobStatus.completato ||
      status == DownloadJobStatus.errore ||
      status == DownloadJobStatus.annullato;

  String get statusLabel {
    switch (status) {
      case DownloadJobStatus.attesa:
        return 'In attesa';
      case DownloadJobStatus.inCorso:
        return total > 0 ? 'In corso · $received/$total' : 'In corso';
      case DownloadJobStatus.completato:
        return total > 0 ? 'Completato · $received/$total' : 'Completato';
      case DownloadJobStatus.errore:
        return 'Errore';
      case DownloadJobStatus.annullato:
        return 'Annullato';
    }
  }
}

/// Coda delle richieste di download verso il PC, servite una per volta.
///
/// Serve perche' il PC accetta una sincronizzazione alla volta: senza coda, una
/// seconda richiesta inviata mentre la prima e' in corso verrebbe rifiutata.
/// Cosi' si possono accodare una playlist, poi un brano da YouTube, poi uno da
/// Spotify, e vengono eseguiti nell'ordine in cui sono stati aggiunti.
class DownloadQueueService extends ChangeNotifier {
  static final DownloadQueueService instance = DownloadQueueService._();
  DownloadQueueService._();

  final List<DownloadJob> _jobs = [];
  bool _working = false;
  int _contatore = 0;

  List<DownloadJob> get jobs => List.unmodifiable(_jobs);
  bool get isWorking => _working;
  int get pendingCount =>
      _jobs.where((j) => j.status == DownloadJobStatus.attesa).length;

  DownloadJob? get current {
    for (final j in _jobs) {
      if (j.status == DownloadJobStatus.inCorso) return j;
    }
    return null;
  }

  /// Accoda una playlist, un album o un brano singolo.
  DownloadJob enqueue({
    required String url,
    required String label,
    DownloadJobKind kind = DownloadJobKind.singolo,
    bool createPlaylist = false,
  }) {
    _contatore++;
    final job = DownloadJob(
      id: 'job_${DateTime.now().millisecondsSinceEpoch}_$_contatore',
      kind: kind,
      url: url.trim(),
      label: label,
      createPlaylist: createPlaylist,
    );
    _jobs.add(job);
    notifyListeners();
    _pump();
    return job;
  }

  /// Toglie dalla coda una voce non ancora iniziata.
  void remove(String id) {
    final i = _jobs.indexWhere((j) => j.id == id);
    if (i == -1) return;
    if (_jobs[i].status == DownloadJobStatus.inCorso) return; // non si strappa
    _jobs.removeAt(i);
    notifyListeners();
  }

  /// Svuota le voci concluse, lasciando quelle in attesa e quella in corso.
  void clearDone() {
    _jobs.removeWhere((j) => j.isDone);
    notifyListeners();
  }

  /// Esegue le voci una per volta, nell'ordine di inserimento.
  Future<void> _pump() async {
    if (_working) return;
    _working = true;
    notifyListeners();

    try {
      while (true) {
        final job = _jobs.firstWhere(
          (j) => j.status == DownloadJobStatus.attesa,
          orElse: () => DownloadJob(
              id: '', kind: DownloadJobKind.singolo, url: '', label: ''),
        );
        if (job.id.isEmpty) break;

        job.status = DownloadJobStatus.inCorso;
        notifyListeners();

        final sync = PcSyncService.instance;
        final avviato = await sync.startPlaylistSync(
          job.url,
          createPlaylist: job.createPlaylist,
        );

        if (!avviato) {
          job.status = DownloadJobStatus.errore;
          job.error = 'Il PC non ha accettato la richiesta';
          notifyListeners();
          continue;
        }

        // Attende la fine di questa sincronizzazione prima della prossima.
        // Limite di sicurezza: due ore, per non restare appesi in eterno se il
        // PC si spegne a metà.
        final scadenza = DateTime.now().add(const Duration(hours: 2));
        while (DateTime.now().isBefore(scadenza)) {
          await Future.delayed(const Duration(seconds: 2));
          final p = sync.syncProgress;
          if (p != null) {
            job.received = p.received;
            job.total = p.toSend > 0 ? p.toSend : p.toDownload;
            notifyListeners();
          }
          if (p == null || !p.active) break;
        }

        final finale = sync.syncProgress;
        if (finale != null && finale.hasError) {
          job.status = DownloadJobStatus.errore;
          job.error = finale.error;
        } else {
          job.status = DownloadJobStatus.completato;
          if (finale != null) {
            job.received = finale.received;
            job.total = finale.toSend > 0 ? finale.toSend : finale.toDownload;
          }
        }
        notifyListeners();
      }
    } finally {
      _working = false;
      notifyListeners();
    }
  }
}
