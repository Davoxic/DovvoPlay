@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion
title SborraPlay
color 0D
cd /d "%~dp0tools"

echo.
echo   ==========================================
echo      SborraPlay - strumenti per il PC
echo   ==========================================
echo.

rem ---------- trova python ----------
set PY=
py -3 --version >nul 2>&1 && set PY=py -3
if not defined PY (
  python --version >nul 2>&1 && set PY=python
)
if not defined PY (
  echo   [X] Python non trovato.
  echo.
  echo   Installalo da https://www.python.org/downloads/
  echo   IMPORTANTE: durante l'installazione spunta "Add python.exe to PATH".
  echo   Poi richiudi e riapri questo file.
  echo.
  pause
  exit /b 1
)

rem ---------- ambiente isolato ----------
if not exist ".venv\Scripts\python.exe" (
  echo   Prima accensione: preparo l'ambiente, ci vuole un minuto...
  %PY% -m venv .venv
  if errorlevel 1 (
    echo   [X] Non sono riuscito a creare l'ambiente.
    pause
    exit /b 1
  )
)
set VPY=.venv\Scripts\python.exe

if not exist ".venv\.installed" (
  echo   Scarico le librerie ^(yt-dlp, mutagen, zeroconf^)...
  "%VPY%" -m pip install --quiet --upgrade pip
  "%VPY%" -m pip install --quiet -r requirements.txt
  if errorlevel 1 (
    echo   [X] Installazione librerie non riuscita. Controlla la connessione.
    pause
    exit /b 1
  )
  echo ok> ".venv\.installed"
  echo   [OK] Pronto.
)

rem ---------- ffmpeg ----------
where ffmpeg >nul 2>&1
if errorlevel 1 (
  echo.
  echo   [!] ffmpeg non trovato: serve per convertire l'audio scaricato.
  set /p inst=   Lo installo adesso con winget? [s/n]:
  if /i "!inst!"=="s" (
    winget install --id Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements
    echo.
    echo   Installato. CHIUDI questa finestra e riapri il file, cosi' ffmpeg viene visto.
    pause
    exit /b 0
  )
)

:menu
cls
echo.
echo   ==========================================
echo      SborraPlay
echo   ==========================================
echo.
echo     1   Scarica una playlist Spotify
echo     2   Manda musica gia' scaricata al telefono
echo     3   Backup del telefono sul PC
echo     4   Rimetti un backup sul telefono
echo     5   Guarda cosa c'e' sul telefono
echo     6   Cerca il telefono sulla rete
echo     7   Aggiorna yt-dlp
echo.
echo     0   Esci
echo.
set /p scelta=   Scegli un numero:

if "%scelta%"=="1" goto playlist
if "%scelta%"=="2" goto push
if "%scelta%"=="3" goto backup
if "%scelta%"=="4" goto restore
if "%scelta%"=="5" goto library
if "%scelta%"=="6" goto discover
if "%scelta%"=="7" goto aggiorna
if "%scelta%"=="0" exit /b 0
goto menu

:playlist
cls
echo.
echo   Incolla il link della playlist Spotify ^(tasto destro per incollare^),
echo   oppure trascina qui dentro un file CSV esportato da exportify.net
echo.
set /p rif=   ^>
if "%rif%"=="" goto menu
echo.
set /p prova=   Scarico solo i primi 3 brani per provare? [s/n]:
echo.
if /i "%prova%"=="s" (
  "%VPY%" sborraplay-dl playlist %rif% --limit 3
) else (
  "%VPY%" sborraplay-dl playlist %rif%
)
echo.
pause
goto menu

:push
cls
echo.
echo   Trascina qui dentro la cartella ^(o i file^) da mandare al telefono
echo.
set /p cart=   ^>
if "%cart%"=="" goto menu
echo.
"%VPY%" sborraplay-dl push %cart%
echo.
pause
goto menu

:backup
cls
echo.
"%VPY%" sborraplay-dl backup -o "%USERPROFILE%\Documents\SborraPlay Backup"
echo.
pause
goto menu

:restore
cls
echo.
echo   Trascina qui dentro il file di backup .sborraplay.json
echo.
set /p bk=   ^>
if "%bk%"=="" goto menu
echo.
set /p sost=   Sostituire le playlist attuali invece di unirle? [s/n]:
echo.
if /i "%sost%"=="s" (
  "%VPY%" sborraplay-dl restore %bk% --replace
) else (
  "%VPY%" sborraplay-dl restore %bk%
)
echo.
pause
goto menu

:library
cls
echo.
"%VPY%" sborraplay-dl library
echo.
pause
goto menu

:discover
cls
echo.
"%VPY%" sborraplay-dl discover
echo.
echo   Se non lo trova: apri SborraPlay sull'iPhone, Impostazioni, accendi il
echo   Server Wi-Fi, e controlla che telefono e PC siano sulla stessa rete.
echo.
pause
goto menu

:aggiorna
cls
echo.
echo   Aggiorno yt-dlp...
"%VPY%" -m pip install --upgrade yt-dlp
echo.
pause
goto menu
