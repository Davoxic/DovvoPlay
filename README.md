# DovvoPlay (Native Swift & SwiftUI Edition)

Player musicale premium nativo per iPhone scritto al **100% in Swift e SwiftUI**, con equalizzatore audio hardware a 5 bande, tracciamento avanzato delle abitudini d'ascolto (secondo per secondo), server Wi-Fi HTTP integrato, sincronizzazione LAN con PC Companion, integrazione YouTube Music AAC, convertitore Spotify/SoundCloud e 12+ temi visivi OLED.

Zero dipendenze esterne: basato esclusivamente su framework Apple moderni (`SwiftUI`, `AVFoundation`, `MediaPlayer`, `Network`, `Combine`, `UniformTypeIdentifiers`).

---

## 🌟 Caratteristiche Principali

- **Riproduzione Audio Nativa in Background** (`AVFoundation`, `AVAudioSession`, `MPNowPlayingInfoCenter`, `MPRemoteCommandCenter`):
  - Supporto formati audio lossless e compressi (.mp3, .m4a, .aac, .flac, .wav).
  - Controlli completi da Lock Screen, Centro di Controllo e Apple Watch/AirPods.
  - Shuffle intelligente ("Magic Shuffle") basato sul livello di gradimento storico e ascolti effettivi.
- **Equalizzatore Parametrico Hardware a 5 Bande** (`AVAudioUnitEQ`):
  - Controllo frequenze 60Hz, 230Hz, 910Hz, 4kHz, 14kHz da -12dB a +12dB.
  - Guadagno preamplificatore (Preamp Gain).
  - Preset integrati (Flat, Bass Boost, Rock, Pop, Jazz, Electronic, Vocal Boost, Hip Hop, Acoustic).
- **Statistiche & Abitudini d'Ascolto Secondo per Secondo** (`StatsService`):
  - Registrazione tempo di ascolto effettivo e categorizzazione automatica delle tracce:
    - `0% - 15%`: Skip immediato
    - `15% - 35%`: Breve assaggio
    - `35% - 70%`: Ascolto medio
    - `70% - 100%`: Ascolto completo
  - Calcolo del Mood del giorno / mese / anno (con notifiche ed emoji animate).
  - Classifiche Top 5 e Top 30 dei brani più ascoltati, più skippati, più ripetuti e meno ascoltati.
  - Procedura di sicurezza in 2 passaggi per il reset dello storico.
- **Personalizzazione Estetica Totale**:
  - **12+ Temi Visivi**: OLED Gold, Cyberpunk Neon, Emerald Luxury, Midnight Amethyst, Sunset Copper, Ruby Noir, Arctic Silver, Rose Gold, Toxic Lime, Tokyo Drift, Solar Flare, Monolith Platinum.
  - **16 Temi di Animazione Traccia**: Nessuna, Dissolvenza, Salto, Espansione, Scivolamento, Ruota, Onda Sonora, Disco che Gira, Battito Cardiaco, Cubo 3D, Rimbalzo Elastico, Glitch Digitale, Specchio Riflesso, Pioggia di Particelle, Prisma Cosmico, Lampo Neon.
  - **8 Modalità di Visualizzazione Libreria**: Schede Moderne, Elenco Compatto, Griglia 2x2, Griglia 3x3, Custodia CD Gioiello, Vinile Vintage 33 Giri, Cassetta Retrò Anni '80, Minimalista Tipografico.
  - Sfondo dinamico con Glow pulsante a tempo di BPM (TBPM / ID3).
- **Server Wi-Fi PC Integrato** (`NWListener` su porta 8080):
  - Server HTTP puro in Swift per caricare file audio da qualsiasi browser su PC direttamente nella cartella `Documents/Music` dell'iPhone senza cavi né iTunes.
- **PC Companion & Sincronizzazione LAN** (porta 45678):
  - Rilevamento automatico del PC sulla rete Wi-Fi locale via probe UDP/TCP.
  - Coda richieste di download asincrona con delegazione a `yt-dlp` sul computer.
  - Notifiche in tempo reale all'arrivo dei brani sincronizzati.
- **YouTube Music Online**:
  - Ricerca brani tramite API Innertube lightweight.
  - Streaming istantaneo solo audio AAC senza video (leggero e a schermo spento).
  - Download offline nella memoria locale dell'iPhone con barra di avanzamento live.
- **Convertitore Spotify & SoundCloud**:
  - Risoluzione metadati, estrazione tracce playlist e download ad alta fedeltà.
- **Salvataggio & Backup Completo**:
  - Esportazione ed importazione JSON con ripristino automatico in caso di reinstallazione dell'app.
- **Controllo Aggiornamenti In-App**:
  - Verifica automatica delle nuove release su GitHub (`Davoxic/sonora`), download del pacchetto `.ipa` e apertura del foglio di condivisione con 1 tocco.

---

## 📁 Struttura del Progetto

```
CLIENT CODE/
├── DovvoPlay.xcodeproj/          # Progetto Xcode nativo
│   ├── project.pbxproj
│   └── xcshareddata/xcschemes/DovvoPlay.xcscheme
├── DovvoPlay/
│   ├── App/
│   │   └── DovvoPlayApp.swift    # Entry point dell'applicazione (@main)
│   ├── Models/
│   │   ├── Track.swift           # Modello Traccia (Codable, Identifiable, backwards-compatible)
│   │   ├── Playlist.swift        # Modello Playlist
│   │   ├── YouTubeTrack.swift    # Tracce YouTube con conversione a Track
│   │   ├── StatsModels.swift     # Tier d'ascolto, Mood, DayStat, PeriodStat
│   │   └── ExternalModels.swift  # Spotify, SoundCloud, Download Jobs, SyncProgress
│   ├── Services/
│   │   ├── AudioPlayerService.swift     # AVPlayer, AVAudioSession, Lock Screen, Magic Shuffle
│   │   ├── EqualizerService.swift       # AVAudioUnitEQ hardware 5 bande + preset
│   │   ├── LibraryService.swift         # Scansione file locali Documents/Music, ID3 parsing
│   │   ├── MetadataService.swift        # Estrazione AVURLAsset metadati, artwork & TBPM
│   │   ├── StatsService.swift           # Registrazione secondo per secondo, Mood, classifiche
│   │   ├── ThemeService.swift           # 12+ Temi visivi OLED & palette
│   │   ├── AnimationThemeService.swift  # 16 Animazioni di transizione
│   │   ├── ViewModeService.swift        # 8 Layout di visualizzazione libreria
│   │   ├── WifiServerService.swift      # Server HTTP NWListener su porta 8080
│   │   ├── PcSyncService.swift          # LAN Discovery & sync bidirezionale col PC
│   │   ├── DownloadQueueService.swift   # Gestione coda download delegati al PC
│   │   ├── YouTubeService.swift         # Innertube search, stream extraction & audio download
│   │   ├── SpotifyService.swift         # Scraping oEmbed e risoluzione tracce
│   │   ├── SoundCloudService.swift      # Risoluzione stream SoundCloud
│   │   ├── BackupService.swift          # Export/Import JSON & auto-restore persistente
│   │   └── UpdateService.swift          # GitHub Releases checker & download .ipa
│   ├── UI/
│   │   ├── Theme/
│   │   │   └── AppTheme.swift           # Color tokens e gradienti dinamici
│   │   ├── Components/
│   │   │   ├── TrackArtworkView.swift
│   │   │   ├── AnimatedTrackTransitionView.swift
│   │   │   ├── MiniPlayerView.swift
│   │   │   ├── EqualizerSheetView.swift
│   │   │   └── TrackRowView.swift       # Rende tutti gli 8 layout di visualizzazione
│   │   └── Screens/
│   │       ├── HomeScreen.swift         # TabView principale + MiniPlayer + Update dialog
│   │       ├── LibraryTab.swift         # Libreria, ricerca, scrubber alfabetico, layout picker
│   │       ├── PlaylistTab.swift        # Gestione playlist e riproduzione
│   │       ├── PlaylistDetailView.swift # Dettaglio playlist e aggiunta brani
│   │       ├── NowPlayingView.swift     # Player full screen, glow BPM, scrubber, controlli
│   │       ├── SettingsTab.swift        # Impostazioni generali, VIP card, sorgenti, temi
│   │       ├── PcCompanionView.swift    # LAN connect, Spotify import, search hub
│   │       ├── YouTubeTabView.swift     # Ricerca YouTube, streaming AAC e download
│   │       ├── WifiServerView.swift     # Stato server HTTP, URL copia e file recenti
│   │       └── StatsView.swift          # Mood, KPI tempo, 4 tier e classifiche
│   └── Resources/
│       ├── Info.plist                   # Background audio, file sharing, permessi LAN
│       └── Assets.xcassets/             # AppIcon, LaunchLogo, AccentColor
├── .github/workflows/
│   └── build-ipa.yml                    # CI GitHub Actions per compilazione .ipa unsigned
├── tools/                               # Tool PC Companion in Python (server locale e sincronizzazione)
├── generate_xcodeproj.py               # Generatore deterministico per project.pbxproj
└── README.md
```

---

## 🛠️ Compilazione e Rilascio (.ipa)

La compilazione dell'applicazione avviene su GitHub Actions tramite runner macOS con Xcode:

1. Esegui il commit e il push delle modifiche sul repository:
   ```bash
   git add -A
   git commit -m "Aggiornamento DovvoPlay in Swift nativo"
   git push origin main
   ```
2. Il workflow `.github/workflows/build-ipa.yml` si avvia automaticamente:
   - Verifica la toolchain Swift e Xcode
   - Compila l'app con `xcodebuild -project DovvoPlay.xcodeproj -scheme DovvoPlay -configuration Release`
   - Confeziona l'eseguibile compilato in `Payload/DovvoPlay.app`
   - Genera il pacchetto pronto `DovvoPlay-unsigned.ipa`
   - Allega il file alle GitHub Releases per l'installazione o l'aggiornamento automatico in-app!

### Come Firmare e Installare su iPhone

Poiché il pacchetto è unsigned, puoi installarlo su iPhone utilizzando la tua utility preferita:
- **TrollStore** (se supportato dalla versione iOS): installazione diretta permanente senza scadenza a 7 giorni.
- **Sideloadly / AltStore / SideStore**: installazione tramite Apple ID gratuito.
- **ESign / Feather / Scarlet**: firma direttamente su iPhone con certificato.
