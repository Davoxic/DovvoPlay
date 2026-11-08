# SborraPlay

Player musicale locale per iPhone + tool da PC per portarci dentro le tue playlist Spotify.

Due pezzi indipendenti:

| | cosa fa |
|---|---|
| **app iOS** (`SborraPlay/`) | riproduce i file audio che hai sul telefono, con copertine, playlist, lock screen e un server Wi-Fi per caricare la musica dal computer via browser |
| **tool PC** (`tools/`) | legge una playlist Spotify, trova i brani su YouTube, li scarica con yt-dlp, scrive i tag e li manda al telefono |

---

## 1. Ottenere il file .ipa

Non serve un Mac: la build gira su GitHub Actions, che usa runner macOS gratuiti per i repository pubblici.

1. Crea un repository su GitHub e caricaci questa cartella:
   ```bash
   cd sborraplay
   git init && git add . && git commit -m "SborraPlay"
   git branch -M main
   git remote add origin https://github.com/Davoxic/sonora.git
   git push -u origin main
   ```
2. Vai su **Actions** → `Build IPA (unsigned)`. Parte da sola al push; altrimenti premi **Run workflow**.
3. A fine build (5-8 minuti) scarica l'artifact **SborraPlay-unsigned-ipa** e scompattalo: dentro c'è `SborraPlay-unsigned.ipa`.

Se invece hai un Mac con Xcode:

```bash
brew install xcodegen
xcodegen generate
open SborraPlay.xcodeproj      # Signing & Capabilities → scegli il tuo team → Run
```

### Firmare e installare

L'`.ipa` esce **senza firma**: va firmata con il tuo Apple ID prima di finire sul telefono.

| strumento | dove gira | note |
|---|---|---|
| **Sideloadly** | Windows / macOS | il più semplice: trascini l'ipa, metti l'Apple ID, collegi l'iPhone |
| **AltStore / SideStore** | Windows / macOS / on-device | rinnova la firma da solo quando il telefono è sulla stessa rete |
| **ESign / Feather** | direttamente su iPhone | serve un certificato |
| **Xcode** | macOS | Window → Devices and Simulators → trascina l'ipa |

Con un Apple ID gratuito la firma **scade dopo 7 giorni** e puoi avere al massimo 3 app sideloaded: va rinnovata (AltStore lo fa da solo). Con un account sviluppatore a pagamento dura un anno.

Il bundle id è `com.dchietti.sborraplay`: cambialo in `project.yml` se ti serve.

---

## 2. Usare l'app

**Formati**: MP3, M4A/AAC, ALAC, WAV, AIFF, CAF, FLAC. iOS non legge OGG, Opus e WMA — vanno convertiti prima.

### Caricare musica dal computer
1. iPhone e PC sulla stessa rete Wi-Fi.
2. Nell'app: **Impostazioni → Server Wi-Fi** acceso. Compare un indirizzo tipo `http://192.168.1.42:8080`.
3. Apri quell'indirizzo nel browser del PC e trascina i file (anche cartelle intere) nella pagina.
4. La libreria si aggiorna da sola un paio di secondi dopo l'ultimo file.

Tieni l'app in primo piano mentre trasferisci. Il server non ha password ed è raggiungibile da chiunque sia sulla tua rete: spegnilo quando hai finito.

### Altri modi
- **App File**: Sul mio iPhone → SborraPlay → copia i file lì dentro.
- **Finder / iTunes**: collega il cavo, scheda File, trascina su SborraPlay.
- **Impostazioni → Importa da File / iCloud**, anche per i `.m3u`.

### Dove finiscono i file, e cosa si perde

I brani che importi vengono **copiati** dentro l'app: non li rileggo dal percorso d'origine, quindi puoi cancellare gli originali sul computer.

| cosa | dove | si ricostruisce da solo? |
|---|---|---|
| file audio | `Documents/Music/` | no (ma li hai anche sul PC) |
| indice della libreria | `Documents/library.json` | sì, riscansionando |
| playlist | `Documents/playlists.json` | **no** |
| copertine delle playlist | `Documents/Covers/` | **no** |
| copertine dei brani | cache | sì, rileggendo i tag |
| copie automatiche | `Documents/Backups/` | — |

`Documents/` è visibile dall'app File (Sul mio iPhone → SborraPlay) e dal Finder col cavo, quindi puoi anche copiare tutto a mano.

Reinstallare l'app sopra sé stessa — cosa che farai ogni 7 giorni per rinnovare la firma — **non cancella niente**: per iOS è un aggiornamento. A sparire è tutto solo se disinstalli l'app o se cambi il bundle id.

### Backup

Impostazioni → Backup:

- **Esporta backup** produce un file `SborraPlay-<data>.sborraplay.json` con playlist, copertine, ordinamento, impostazioni e l'elenco dei brani; lo mandi dove vuoi col foglio di condivisione (File, iCloud, AirDrop, Mail).
- **Importa backup** lo rilegge e ti chiede se unire alle playlist attuali o sostituirle. Le playlist con lo stesso nome vengono fuse, non duplicate.
- **Copia automatica giornaliera** (attiva di default) salva una copia in `Documents/Backups/` al massimo una volta al giorno e tiene le ultime 5. Da **Copie automatiche** le riapri, le condividi o le ripristini.

Il backup non contiene l'audio: pesa qualche decina di KB più le copertine. I brani li hai già nella cartella del PC da cui li hai caricati.

Dal computer, senza toccare il telefono:

```bash
sborraplay-dl backup -o ~/Backup            # scarica il backup dall'iPhone
sborraplay-dl restore ~/Backup/SborraPlay-….sborraplay.json
sborraplay-dl restore … --replace           # sostituisce invece di unire
```

Prima di ogni reinstallazione conviene lanciare `sborraplay-dl backup`: dopo il reinstall, `restore` ti rimette playlist e copertine al loro posto.

### API del server (usate dal tool PC)
```
GET    /                      pagina di upload
GET    /api/ping              stato e numero di brani
GET    /api/library           elenco brani e playlist (JSON)
PUT    /api/file/<nome>       carica un file (corpo = byte grezzi)
DELETE /api/file/<nome>       cancella un file
POST   /api/playlist          {"name": "…", "files": ["a.mp3", …]}
GET    /api/backup            backup completo in JSON
POST   /api/restore[?replace=1]   rimanda indietro un backup
```
Esempio: `curl -T "brano.mp3" http://192.168.1.42:8080/api/file/brano.mp3`

---

## 3. Il tool PC

Dettagli completi in [`tools/README.md`](tools/README.md). In breve:

```bash
cd tools
pip install -r requirements.txt        # yt-dlp, mutagen, zeroconf
# serve anche ffmpeg nel PATH

./sborraplay-dl discover                                   # trova l'iPhone sulla rete
./sborraplay-dl playlist https://open.spotify.com/playlist/XXXX
```

Legge la playlist → cerca ogni brano su YouTube e sceglie il risultato più probabile (durata, titolo, canale) → scarica in MP3 320 → scrive tag e copertina → manda tutto al telefono e crea la playlist dentro l'app.

---

## Struttura

```
SborraPlay/
  App/            punto di ingresso SwiftUI
  Models/         Track, Playlist, libreria su disco, lettura metadati, copertine
  Audio/          PlayerEngine: coda, shuffle, repeat, lock screen, interruzioni
  Server/         server HTTP (Network.framework) + pagina di upload
  Views/          libreria, album, artisti, playlist, now playing, impostazioni
tools/
  sborraplay_dl/      spotify.py · matcher.py · downloader.py · pusher.py · cli.py
.github/workflows/build-ipa.yml
project.yml       spec XcodeGen (il .xcodeproj viene generato, non è versionato)
```

## Note

- La musica sta in `Documents/Music` dentro il container dell'app: resta lì tra un aggiornamento e l'altro, sparisce se disinstalli l'app.
- L'indice della libreria è un `library.json`, le playlist un `playlists.json`, le copertine in cache.
- Scarica solo materiale che hai diritto di scaricare; il tool si limita a cercare ciò che gli indichi.
