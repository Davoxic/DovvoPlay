#!/bin/bash
# Doppio clic su macOS (o ./SborraPlay.command su Linux).
cd "$(dirname "$0")/tools" || exit 1

VIOLA=$'\033[35m'; VERDE=$'\033[32m'; GIALLO=$'\033[33m'; ROSSO=$'\033[31m'; FINE=$'\033[0m'

intestazione() {
  clear
  echo
  echo "${VIOLA}  ==========================================${FINE}"
  echo "${VIOLA}     SborraPlay${FINE}"
  echo "${VIOLA}  ==========================================${FINE}"
  echo
}

# ---------- python ----------
PY=""
for c in python3 python; do
  if command -v "$c" >/dev/null 2>&1; then PY="$c"; break; fi
done
if [ -z "$PY" ]; then
  intestazione
  echo "${ROSSO}  [X] Python non trovato.${FINE}"
  echo "      macOS:  brew install python"
  echo "      oppure: https://www.python.org/downloads/"
  echo
  read -r -p "  Invio per chiudere "
  exit 1
fi

# ---------- ambiente isolato ----------
if [ ! -x ".venv/bin/python" ]; then
  intestazione
  echo "  Prima accensione: preparo l'ambiente, ci vuole un minuto..."
  "$PY" -m venv .venv || { echo "${ROSSO}  [X] venv non creato${FINE}"; read -r -p "  Invio "; exit 1; }
fi
VPY=".venv/bin/python"

if [ ! -f ".venv/.installed" ]; then
  echo "  Scarico le librerie (yt-dlp, mutagen, zeroconf)..."
  "$VPY" -m pip install --quiet --upgrade pip
  if "$VPY" -m pip install --quiet -r requirements.txt; then
    touch ".venv/.installed"
    echo "${VERDE}  [OK] Pronto.${FINE}"
  else
    echo "${ROSSO}  [X] Installazione non riuscita. Controlla la connessione.${FINE}"
    read -r -p "  Invio per chiudere "
    exit 1
  fi
fi

# ---------- ffmpeg ----------
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo
  echo "${GIALLO}  [!] ffmpeg non trovato: serve per convertire l'audio.${FINE}"
  if command -v brew >/dev/null 2>&1; then
    read -r -p "  Lo installo con Homebrew? [s/n] " risposta
    if [ "$risposta" = "s" ]; then brew install ffmpeg; fi
  else
    echo "      Installa Homebrew da https://brew.sh e poi: brew install ffmpeg"
    read -r -p "  Invio per continuare lo stesso "
  fi
fi


# ---------- menu ----------
while true; do
  intestazione
  echo "    1   Scarica una playlist Spotify"
  echo "    2   Manda musica già scaricata al telefono"
  echo "    3   Backup del telefono sul PC"
  echo "    4   Rimetti un backup sul telefono"
  echo "    5   Guarda cosa c'è sul telefono"
  echo "    6   Cerca il telefono sulla rete"
  echo "    7   Aggiorna yt-dlp"
  echo
  echo "    0   Esci"
  echo
  read -r -p "  Scegli un numero: " scelta
  echo

  case "$scelta" in
    1)
      echo "  Incolla il link Spotify, oppure trascina qui un CSV di exportify.net"
      read -r -p "  > " rif
      [ -z "$rif" ] && continue
      read -r -p "  Scarico solo i primi 3 brani per provare? [s/n] " prova
      echo
      if [ "$prova" = "s" ]; then
        eval "\"$VPY\" sborraplay-dl playlist $rif --limit 3"
      else
        eval "\"$VPY\" sborraplay-dl playlist $rif"
      fi
      ;;
    2)
      echo "  Trascina qui la cartella (o i file) da mandare al telefono"
      read -r -p "  > " cart
      [ -z "$cart" ] && continue
      echo
      eval "\"$VPY\" sborraplay-dl push $cart"
      ;;
    3)
      "$VPY" sborraplay-dl backup -o "$HOME/Documents/SborraPlay Backup"
      ;;
    4)
      echo "  Trascina qui il file .sborraplay.json"
      read -r -p "  > " bk
      [ -z "$bk" ] && continue
      read -r -p "  Sostituire le playlist attuali invece di unirle? [s/n] " sost
      echo
      if [ "$sost" = "s" ]; then
        eval "\"$VPY\" sborraplay-dl restore $bk --replace"
      else
        eval "\"$VPY\" sborraplay-dl restore $bk"
      fi
      ;;
    5) "$VPY" sborraplay-dl library ;;
    6)
      "$VPY" sborraplay-dl discover
      echo
      echo "  Se non lo trova: apri SborraPlay sull'iPhone, Impostazioni,"
      echo "  accendi il Server Wi-Fi, e controlla di essere sulla stessa rete."
      ;;
    7) "$VPY" -m pip install --upgrade yt-dlp ;;
    0) exit 0 ;;
    *) continue ;;
  esac

  echo
  read -r -p "  Invio per tornare al menu "
done
