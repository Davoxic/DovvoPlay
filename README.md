# DovvoPlay

Player musicale per iPhone scritto in **Flutter / Dart** con ricerca **YouTube** e streaming audio in background + server Wi-Fi per caricare brani da PC.

## Caratteristiche principali

- **Ricerca YouTube & Streaming Audio** (`youtube_explode_dart`): cerca qualsiasi brano su YouTube e ascoltalo direttamente in streaming audio leggero (AAC/m4a nativo iOS), funzionante anche a **schermo spento** e con comandi dalla **lock screen** / Centro di Controllo.
- **Salvataggio Offline**: scarica i brani da YouTube direttamente nella memoria locale dell'app con un tocco.
- **Libreria & Playlist**: crea playlist, organizza i brani locali e online, visualizza copertine e metadati.
- **Esplora (catalogo YouTube Music)**: home con le file proposte, classifiche, mood e generi, nuove uscite; ricerca con filtri (brani, video, album, artisti, playlist), completamenti e ricerche recenti; pagine di album, artisti e playlist con "Riproduci", "Casuale", "Scarica tutto" e "Salva come playlist".
- **Player esteso**: coda riordinabile, AutoPlay e radio di un brano con musica simile, testi sincronizzati (LRCLIB), timer di spegnimento, velocita' di riproduzione, dissolvenza tra i brani, "Mi piace", statistiche per nerd.
- **Cronologia e Replay**: tutto cio' che hai ascoltato giorno per giorno, e un riassunto del periodo (brani, artisti, album, orari) condivisibile come immagine.
- **Ascolta insieme**: un party sulla rete Wi-Fi con un codice da condividere; stessa musica in sincrono, coda in comune.
- **Download e scrobbling**: coda dei download sul telefono, gestione delle cache, scrobbling su ListenBrainz.
- **Server Wi-Fi integrato**: attiva il server dall'app, collegati da qualsiasi browser su PC (`http://<ip-iphone>:8080`) e trascina i tuoi file musicali (.mp3, .m4a, .flac, .wav).
- **Tool PC da riga di comando** (`tools/`): esporta playlist Spotify, scarica e invia automaticamente all'iPhone via rete.

---

## 1. Ottenere il file .ipa

La compilazione avviene automaticamente tramite **GitHub Actions** su runner macOS.

1. Fai il push su GitHub sul branch `main`:
   ```bash
   git add -A
   git commit -m "Aggiornamento DovvoPlay"
   git push origin HEAD:main
   ```
2. Il workflow `.github/workflows/build-ipa.yml` si avvia da solo al push:
   - Configura Flutter e le dipendenze
   - Prepara il target iOS con permessi di background audio e condivisione file
   - Compila la release unsigned (`flutter build ios --release --no-codesign`)
   - Impacchetta l'IPA in `Payload/DovvoPlay.app` e zippa in `DovvoPlay-unsigned.ipa`
3. A fine build scarica l'artifact **DovvoPlay-unsigned-ipa**.

### Firmare e installare

L'`.ipa` generato è privo di firma (unsigned): va firmato prima dell'installazione:

| Strumento | Dove gira | Note |
|---|---|---|
| **Sideloadly** | Windows / macOS | Il più semplice: trascini l'ipa, inserisci l'Apple ID, colleghi l'iPhone |
| **AltStore / SideStore** | Windows / macOS / on-device | Rinnova la firma automaticamente |
| **ESign / Feather** | direttamente su iPhone | Serve un certificato per il sideload |

---

## 2. Struttura del progetto

```
dovvoplay/
├── .github/workflows/build-ipa.yml  # Pipeline CI per creare l'unsigned IPA
├── assets/                          # Icone e loghi
├── lib/                             # Codice Dart / Flutter
│   ├── main.dart
│   ├── models/                      # Track, Playlist, YouTubeTrack
│   ├── services/                    # AudioPlayer, YouTubeService, YtMusicService, Lyrics, Party, LibraryService, WifiServer
│   └── ui/                          # Schermate, temi e widget
├── scripts/                         # Script di configurazione per iOS
├── tools/                           # Tool Python da PC per Spotify/YouTube download
├── pubspec.yaml                     # Dipendenze Flutter (youtube_explode_dart, just_audio, ecc.)
└── README.md
```
