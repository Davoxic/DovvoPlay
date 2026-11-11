import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppReleaseInfo {
  final String tagName;
  final String name;
  final String body;
  final String? ipaDownloadUrl;
  final int ipaSize;
  final DateTime? publishedAt;
  final String htmlUrl;
  final bool isNewer;

  const AppReleaseInfo({
    required this.tagName,
    required this.name,
    required this.body,
    required this.ipaDownloadUrl,
    required this.ipaSize,
    required this.publishedAt,
    required this.htmlUrl,
    required this.isNewer,
  });

  String get cleanVersion => tagName.replaceFirst(RegExp(r'^v'), '');
}

class UpdateService extends ChangeNotifier {
  static final UpdateService instance = UpdateService._();
  UpdateService._();

  static const String currentVersion = '1.3.3';
  static const String repoOwner = 'Davoxic';
  static const String repoName = 'sonora';

  bool _isChecking = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';
  AppReleaseInfo? _latestRelease;
  File? _downloadedIpa;

  bool get isChecking => _isChecking;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String get downloadStatus => _downloadStatus;
  AppReleaseInfo? get latestRelease => _latestRelease;
  File? get downloadedIpa => _downloadedIpa;

  /// Confronta due stringhe di versione tipo "1.2.1" e "1.2.0"
  /// Ritorna true se [remote] è maggiore di [local]
  static bool isVersionNewer(String remote, String local) {
    try {
      final rParts = remote.replaceFirst('v', '').split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final lParts = local.replaceFirst('v', '').split('.').map((e) => int.tryParse(e) ?? 0).toList();
      while (rParts.length < 3) {
        rParts.add(0);
      }
      while (lParts.length < 3) {
        lParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (rParts[i] > lParts[i]) return true;
        if (rParts[i] < lParts[i]) return false;
      }
    } catch (_) {}
    return false;
  }

  /// Verifica la presenza di una nuova release su GitHub
  Future<AppReleaseInfo?> checkForUpdates({bool isSilent = false}) async {
    if (_isChecking) return _latestRelease;
    _isChecking = true;
    if (!isSilent) notifyListeners();

    try {
      final uri = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
      final res = await http.get(uri, headers: {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'SborraPlay-App',
      }).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final tagName = data['tag_name']?.toString() ?? '';
        final name = data['name']?.toString() ?? tagName;
        final body = data['body']?.toString() ?? '';
        final htmlUrl = data['html_url']?.toString() ?? 'https://github.com/$repoOwner/$repoName/releases';
        final pubDateStr = data['published_at']?.toString();
        final publishedAt = pubDateStr != null ? DateTime.tryParse(pubDateStr) : null;

        String? ipaUrl;
        int ipaSize = 0;
        final assets = data['assets'] as List<dynamic>? ?? [];
        for (final asset in assets) {
          final assetName = asset['name']?.toString().toLowerCase() ?? '';
          if (assetName.endsWith('.ipa')) {
            ipaUrl = asset['browser_download_url']?.toString();
            ipaSize = (asset['size'] as num?)?.toInt() ?? 0;
            break;
          }
        }

        final newer = isVersionNewer(tagName, currentVersion);

        _latestRelease = AppReleaseInfo(
          tagName: tagName,
          name: name,
          body: body,
          ipaDownloadUrl: ipaUrl,
          ipaSize: ipaSize,
          publishedAt: publishedAt,
          htmlUrl: htmlUrl,
          isNewer: newer,
        );
        notifyListeners();
        return _latestRelease;
      }
    } catch (e) {
      print('Errore verifica aggiornamenti GitHub: $e');
    } finally {
      _isChecking = false;
      notifyListeners();
    }
    return null;
  }

  /// Scarica il file .ipa direttamente nella cartella Documents di SborraPlay
  Future<File?> downloadIpa(
    AppReleaseInfo release, {
    void Function(double progress, String status)? onProgress,
  }) async {
    final url = release.ipaDownloadUrl;
    if (url == null || url.isEmpty) return null;

    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadStatus = 'Avvio download del file .ipa...';
    notifyListeners();
    onProgress?.call(0.0, _downloadStatus);

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final targetFile = File('${docsDir.path}/SborraPlay-${release.cleanVersion}.ipa');

      // Se già scaricato completamente in precedenza
      if (await targetFile.exists() && release.ipaSize > 0 && await targetFile.length() == release.ipaSize) {
        _isDownloading = false;
        _downloadProgress = 1.0;
        _downloadStatus = 'Download già completato!';
        _downloadedIpa = targetFile;
        notifyListeners();
        onProgress?.call(1.0, _downloadStatus);
        return targetFile;
      }

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      request.headers['User-Agent'] = 'SborraPlay-App';

      final response = await client.send(request);
      final totalBytes = response.contentLength ?? release.ipaSize;

      final sink = targetFile.openWrite();
      int receivedBytes = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          _downloadProgress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
          final mbReceived = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          final mbTotal = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
          _downloadStatus = 'Scaricati $mbReceived MB di $mbTotal MB (${(_downloadProgress * 100).toInt()}%)';
          notifyListeners();
          onProgress?.call(_downloadProgress, _downloadStatus);
        }
      }

      await sink.flush();
      await sink.close();

      _isDownloading = false;
      _downloadProgress = 1.0;
      _downloadStatus = 'Download completato! Pronto per la firma locale.';
      _downloadedIpa = targetFile;
      notifyListeners();
      onProgress?.call(1.0, _downloadStatus);
      return targetFile;
    } catch (e) {
      _isDownloading = false;
      _downloadStatus = 'Errore durante il download: $e';
      notifyListeners();
      onProgress?.call(0.0, _downloadStatus);
      return null;
    }
  }

  /// Apre il menu di condivisione nativo di iOS (Share Sheet) per passare
  /// l'IPA direttamente all'app di firma (ESign, Scarlet, Feather, GBox) o salvarlo
  Future<void> shareIpa(File ipaFile) async {
    if (!await ipaFile.exists()) return;
    try {
      await Share.shareXFiles(
        [XFile(ipaFile.path)],
        subject: 'SborraPlay Update IPA',
        text: 'Installa o firma SborraPlay con la tua app di firma preferita.',
      );
    } catch (e) {
      print('Errore apertura Share Sheet: $e');
    }
  }

  /// Apre la pagina di rilascio GitHub nel browser Safari
  Future<void> openReleasePage(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }
}
