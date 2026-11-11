# dovvoplay-dl

Dalla playlist Spotify ai file sul tuo iPhone: legge la playlist, trova i brani su YouTube,
li scarica con yt-dlp, scrive i tag e li carica nell'app DovvoPlay.

## Installazione

```bash
pip install -r requirements.txt
```

Serve anche **ffmpeg** nel PATH:

| sistema | comando |
|---|---|
| macOS | `brew install ffmpeg` |
| Windows | `winget install Gyan.FFmpeg` |
| Debian/Ubuntu | `sudo apt install ffmpeg` |

Poi si usa direttamente: `./dovvoplay-dl …` (oppure `python -m dovvoplay_dl …`).

## Comandi

```bash
dovvoplay-dl discover                       # cerca l'iPhone sulla rete e lo ricorda
dovvoplay-dl playlist <url Spotify>         # scarica tutto e lo manda al telefono
dovvoplay-dl playlist export.csv --no-push  # solo download, niente invio
dovvoplay-dl push ~/Musica/Estate --playlist "Estate 2026"
dovvoplay-dl library                        # cosa c'è già sul telefono
```

### Opzioni di `playlist`

| opzione | effetto |
|---|---|
| `-o DIR` | cartella di destinazione (default `./DovvoPlay/<nome playlist>`) |
| `-f mp3\|m4a\|flac` | formato finale (default mp3) |
| `-q 320` | bitrate mp3 |
| `--host 192.168.1.42:8080` | indirizzo del telefono (altrimenti Bonjour o quello salvato) |
| `--no-push` | non inviare nulla |
| `--workers 4` | download in parallelo (default 3) |
| `--limit 20` | solo i primi N brani |
| `--dry-run` | mostra cosa farebbe |
| `--min-score 45` | alza la soglia se ti scarica brani sbagliati |
| `--overwrite` | riscarica anche ciò che esiste già |
| `--cookies-from-browser chrome` | usa i tuoi cookie se YouTube chiede la verifica età/bot |

## Come legge la playlist Spotify

Prova in ordine, e si ferma al primo che funziona:

1. **API ufficiali** se trova `SPOTIFY_CLIENT_ID` e `SPOTIFY_CLIENT_SECRET` nell'ambiente.
   È l'unica via senza limiti di lunghezza e con ISRC e copertine. Registrare l'app su
   [developer.spotify.com](https://developer.spotify.com/dashboard) richiede due minuti:
   ```bash
   export SPOTIFY_CLIENT_ID=xxxx
   export SPOTIFY_CLIENT_SECRET=yyyy
   ```
2. **Pagina pubblica embed** — nessuna credenziale, ma si ferma intorno ai 100 brani
   (e può smettere di funzionare se Spotify cambia la pagina).
3. **Token anonimo del web player** — ultimo tentativo, spesso bloccato.
4. **File locale**: passa un `.csv`, `.json` o `.txt` invece dell'URL. Funziona con
   l'export di [Exportify](https://exportify.net) (colonne `Track Name`, `Artist Name(s)`,
   `Album Name`, `Duration (ms)`) e anche con un semplice elenco `Artista - Titolo` riga per riga.
   **Per playlist lunghe o private questa è la strada più affidabile.**

## Come sceglie il video su YouTube

Per ogni brano fa fino a 3 ricerche (`artista - titolo audio`, `artista titolo`, con album;
l'ISRC per primo se disponibile) e dà un punteggio a ogni risultato:

- **durata** vicina a quella Spotify: è il segnale più forte (±2 s vale 42 punti, oltre 45 s di scarto −55)
- **somiglianza del titolo** (fino a 30 punti) e presenza dell'artista nel canale o nel titolo
- **bonus** per i canali `… - Topic` (gli upload ufficiali di YouTube Music) e VEVO
- **malus** per live, cover, karaoke, remix, sped up, nightcore, reaction, 8D…
  ma solo se quelle parole non erano già nel titolo che cerchi
- un filo di peso alle visualizzazioni

Sotto la soglia (`--min-score`, default 35) il brano viene saltato e finito in
`_non_scaricati.txt` nella cartella di destinazione, così puoi riprovare a mano.

## Dopo il download

- i file si chiamano `Artista - Titolo.mp3`, con tag ID3 (titolo, artista, album, traccia, anno, ISRC) e copertina presa da Spotify
- viene scritto anche un `.m3u` con l'ordine della playlist
- i file vengono caricati sul telefono via `PUT /api/file/...` e l'app crea la playlist con lo stesso nome
- `.yt-archive.txt` tiene traccia dei video già scaricati, così rilanciare il comando non riscarica nulla
- l'indirizzo del telefono viene ricordato in `~/.dovvoplay-dl.json`

## Se qualcosa non va

| sintomo | cosa fare |
|---|---|
| `ffmpeg non trovato` | installalo (tabella sopra) |
| `Telefono non raggiungibile` | app aperta + server acceso in Impostazioni, stessa rete, poi `--host IP:8080` |
| Bonjour non trova niente | `pip install zeroconf`, oppure usa `--host` |
| scarica la versione sbagliata | alza `--min-score`, o scarica quel brano a mano e usa `dovvoplay-dl push` |
| YouTube chiede la verifica | `--cookies-from-browser chrome` |
| playlist tagliata a 100 brani | usa l'export CSV o le credenziali Spotify |
