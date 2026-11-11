import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'library_service.dart';
import 'update_service.dart';

class WifiServerService extends ChangeNotifier {
  static final WifiServerService instance = WifiServerService._();
  WifiServerService._();

  HttpServer? _server;
  bool _isRunning = false;
  String _ipAddress = '127.0.0.1';
  final int _port = 8080;
  final List<String> _recentUploads = [];

  bool get isRunning => _isRunning;
  String get ipAddress => _ipAddress;
  int get port => _port;
  String get serverUrl => 'http://$_ipAddress:$_port';
  List<String> get recentUploads => List.unmodifiable(_recentUploads);

  Future<void> toggle() async {
    if (_isRunning) {
      await stop();
    } else {
      await start();
    }
  }

  Future<void> updateIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('169.254')) {
            _ipAddress = addr.address;
            notifyListeners();
            return;
          }
        }
      }
    } catch (e) {
      print('Errore lettura IP di rete: $e');
    }
  }

  Future<void> start() async {
    if (_isRunning) return;
    try {
      await updateIpAddress();
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _isRunning = true;
      notifyListeners();

      _server!.listen(
        _handleRequest,
        onError: (e) {
          print('Errore server HTTP: $e');
        },
      );
    } catch (e) {
      print('Impossibile avviare il server Wi-Fi: $e');
      _isRunning = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
    notifyListeners();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // CORS headers
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type, Content-Length');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    try {
      if (path == '/' || path == '/index.html') {
        await _serveWebPage(request);
      } else if (path == '/api/ping') {
        _jsonResponse(request, {'ok': true, 'app': 'SborraPlay', 'version': UpdateService.currentVersion});
      } else if (path == '/api/library') {
        final tracks = LibraryService.instance.tracks.map((t) => t.toJson()).toList();
        _jsonResponse(request, {'ok': true, 'tracks': tracks, 'count': tracks.length});
      } else if (path.startsWith('/api/file/')) {
        await _handleFileEndpoint(request);
      } else if (path == '/api/playlist') {
        await _handlePlaylistEndpoint(request);
      } else if (path == '/upload') {
        await _handleUploadForm(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('404 Not Found');
        await request.response.close();
      }
    } catch (e) {
      print('Errore gestione richiesta: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('500 Error: $e');
      await request.response.close();
    }
  }

  Future<void> _handleFileEndpoint(HttpRequest request) async {
    final fileName = Uri.decodeComponent(request.uri.path.replaceFirst('/api/file/', ''));
    if (fileName.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final musicDir = await LibraryService.instance.musicDirectory;
    final file = File('${musicDir.path}/$fileName');

    if (request.method == 'PUT') {
      final sink = file.openWrite();
      await for (final chunk in request) {
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      _recentUploads.insert(0, fileName);
      if (_recentUploads.length > 30) _recentUploads.removeLast();
      notifyListeners();

      await LibraryService.instance.scanLibrary();
      _jsonResponse(request, {'ok': true, 'file': fileName});
    } else if (request.method == 'DELETE') {
      if (await file.exists()) {
        await file.delete();
        await LibraryService.instance.scanLibrary();
      }
      _jsonResponse(request, {'ok': true, 'deleted': fileName});
    } else {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
    }
  }

  Future<void> _handlePlaylistEndpoint(HttpRequest request) async {
    if (request.method == 'POST') {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body);
      final name = data['name'] ?? 'Nuova Playlist';
      final files = (data['files'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

      // Mappa i nomi file agli id traccia.
      // Nota: niente firstWhere con orElse su tracks.first, che andava in
      // errore (500) a libreria vuota o associava la traccia sbagliata.
      final trackIds = <String>[];
      for (final f in files) {
        for (final x in LibraryService.instance.tracks) {
          if (x.id.endsWith(f) || (x.filePath != null && x.filePath!.endsWith(f))) {
            trackIds.add(x.id);
            break;
          }
        }
      }

      if (trackIds.isEmpty) {
        _jsonResponse(request, {
          'ok': false,
          'error': 'Nessuno dei file indicati è presente nella libreria',
          'files': files,
        });
        return;
      }

      final pl = await LibraryService.instance.createPlaylist(name, trackIds);
      _jsonResponse(request, {'ok': true, 'playlist': pl.toJson()});
    } else {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
    }
  }

  Future<void> _handleUploadForm(HttpRequest request) async {
    final contentType = request.headers.contentType;
    if (contentType == null || !contentType.primaryType.contains('multipart')) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('Expected multipart');
      await request.response.close();
      return;
    }

    final boundary = contentType.parameters['boundary'];
    if (boundary == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final musicDir = await LibraryService.instance.musicDirectory;
    final bytesBuilder = BytesBuilder();
    await for (final chunk in request) {
      bytesBuilder.add(chunk);
    }
    final allBytes = bytesBuilder.takeBytes();

    // Estrai il file dal payload multipart
    final boundaryBytes = utf8.encode('--$boundary');
    final parts = _splitBytes(allBytes, Uint8List.fromList(boundaryBytes));

    for (final part in parts) {
      if (part.isEmpty) continue;
      final headerEnd = _findSublist(part, [13, 10, 13, 10]); // \r\n\r\n
      if (headerEnd == -1) continue;

      final headerStr = utf8.decode(part.sublist(0, headerEnd), allowMalformed: true);
      final fileMatch = RegExp(r'filename="([^"]+)"').firstMatch(headerStr);
      if (fileMatch != null) {
        var fileName = fileMatch.group(1)!;
        fileName = fileName.replaceAll(RegExp(r'[\\/:]'), '_').trim();
        if (fileName.isNotEmpty) {
          var fileData = part.sublist(headerEnd + 4);
          if (fileData.length >= 2 && fileData[fileData.length - 2] == 13 && fileData[fileData.length - 1] == 10) {
            fileData = fileData.sublist(0, fileData.length - 2);
          }
          final destFile = File('${musicDir.path}/$fileName');
          await destFile.writeAsBytes(fileData);

          _recentUploads.insert(0, fileName);
          if (_recentUploads.length > 30) _recentUploads.removeLast();
        }
      }
    }

    await LibraryService.instance.scanLibrary();
    notifyListeners();
    _jsonResponse(request, {'ok': true, 'count': _recentUploads.length});
  }

  int _findSublist(List<int> data, List<int> pattern) {
    if (pattern.isEmpty || data.length < pattern.length) return -1;
    for (int i = 0; i <= data.length - pattern.length; i++) {
      bool match = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  List<Uint8List> _splitBytes(Uint8List data, Uint8List delimiter) {
    final result = <Uint8List>[];
    int start = 0;
    while (true) {
      final index = _findSublist(data.sublist(start), delimiter);
      if (index == -1) {
        result.add(data.sublist(start));
        break;
      }
      result.add(data.sublist(start, start + index));
      start = start + index + delimiter.length;
    }
    return result;
  }

  void _jsonResponse(HttpRequest request, Map<String, dynamic> data) {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    request.response.close();
  }

  Future<void> _serveWebPage(HttpRequest request) async {
    request.response.headers.contentType = ContentType.html;
    request.response.write(_webPageHtml);
    await request.response.close();
  }

  static const String _webPageHtml = '''
<!DOCTYPE html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SborraPlay · Carica Musica</title>
<style>
  :root {
    --bg: #0d0a17; --bg2: #171029; --card: rgba(255,255,255,.06);
    --line: rgba(255,255,255,.12); --text: #f2eefb; --muted: #a79dc0;
    --accent: #c96bff; --accent2: #ec5c78; --ok: #4ade80;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; min-height: 100vh; color: var(--text);
    font: 15px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: radial-gradient(1200px 600px at 20% -10%, #3a1d5e 0%, transparent 60%), linear-gradient(160deg, var(--bg), var(--bg2));
    padding: 32px 16px 60px;
  }
  .wrap { max-width: 680px; margin: 0 auto; }
  header { display: flex; align-items: center; gap: 14px; margin-bottom: 24px; }
  .logo {
    width: 48px; height: 48px; border-radius: 14px;
    background: conic-gradient(from 210deg, var(--accent), var(--accent2), var(--accent));
    display: grid; place-items: center; font-weight: bold; font-size: 22px;
  }
  h1 { font-size: 24px; margin: 0; font-weight: 700; }
  .sub { color: var(--muted); font-size: 13px; }
  .drop {
    border: 2px dashed var(--line); border-radius: 20px; padding: 48px 20px; text-align: center;
    background: var(--card); transition: .2s; cursor: pointer;
  }
  .drop:hover, .drop.over { border-color: var(--accent); background: rgba(201,107,255,.12); }
  .btn {
    display: inline-block; margin-top: 18px; padding: 12px 28px; border-radius: 999px; border: 0;
    background: linear-gradient(120deg, var(--accent), var(--accent2)); color: #fff; font-weight: 600;
    font-size: 15px; cursor: pointer;
  }
  input[type=file] { display: none; }
  ul { list-style: none; padding: 0; margin: 24px 0 0; }
  li {
    padding: 12px 16px; border: 1px solid var(--line); border-radius: 12px; margin-bottom: 8px;
    background: var(--card); display: flex; justify-content: space-between; font-size: 14px;
  }
  .ok { color: var(--ok); font-weight: 600; }
</style>
</head>
<body>
<div class="wrap">
  <header>
    <div class="logo">⚡</div>
    <div>
      <h1>SborraPlay</h1>
      <div class="sub">Carica musica direttamente sul tuo iPhone via Wi-Fi</div>
    </div>
  </header>

  <div class="drop" id="drop">
    <h2 style="margin:0 0 8px;">Trascina qui i tuoi brani</h2>
    <p style="margin:0; color:var(--muted);">MP3, M4A, WAV, FLAC, AAC — anche selezioni multiple</p>
    <button class="btn" id="pick" type="button">Scegli file dal computer</button>
    <input type="file" id="file" multiple accept="audio/*,.mp3,.m4a,.wav,.flac,.aac">
  </div>

  <ul id="list"></ul>
</div>

<script>
  const drop = document.getElementById('drop');
  const fileInput = document.getElementById('file');
  const pick = document.getElementById('pick');
  const list = document.getElementById('list');

  pick.onclick = () => fileInput.click();
  fileInput.onchange = () => handleFiles(fileInput.files);

  drop.ondragover = (e) => { e.preventDefault(); drop.classList.add('over'); };
  drop.ondragleave = () => drop.classList.remove('over');
  drop.ondrop = (e) => {
    e.preventDefault();
    drop.classList.remove('over');
    handleFiles(e.dataTransfer.files);
  };

  async function handleFiles(files) {
    for (const f of files) {
      const li = document.createElement('li');
      li.innerHTML = '<span>' + f.name + '</span><span style="color:var(--muted)">caricamento...</span>';
      list.prepend(li);

      const formData = new FormData();
      formData.append('file', f);

      try {
        const res = await fetch('/upload', { method: 'POST', body: formData });
        if (res.ok) {
          li.querySelector('span:last-child').className = 'ok';
          li.querySelector('span:last-child').textContent = '✓ Caricato';
        } else {
          li.querySelector('span:last-child').textContent = 'Errore';
        }
      } catch (e) {
        li.querySelector('span:last-child').textContent = 'Errore connessione';
      }
    }
  }
</script>
</body>
</html>
''';
}
