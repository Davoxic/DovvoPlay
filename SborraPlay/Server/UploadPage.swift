import Foundation

enum UploadPage {
    static let html: String = #"""
<!DOCTYPE html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SborraPlay · carica musica</title>
<style>
  :root {
    --bg: #0d0a17;
    --bg2: #171029;
    --card: rgba(255,255,255,.05);
    --line: rgba(255,255,255,.12);
    --text: #f2eefb;
    --muted: #a79dc0;
    --accent: #c96bff;
    --accent2: #ec5c78;
    --ok: #4ade80;
    --err: #f87171;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; min-height: 100vh; color: var(--text);
    font: 15px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: radial-gradient(1200px 600px at 20% -10%, #3a1d5e 0%, transparent 60%), linear-gradient(160deg, var(--bg), var(--bg2));
    padding: 28px 16px 60px;
  }
  .wrap { max-width: 760px; margin: 0 auto; }
  header { display: flex; align-items: center; gap: 14px; margin-bottom: 26px; }
  .logo {
    width: 46px; height: 46px; border-radius: 13px; flex: 0 0 auto;
    background: conic-gradient(from 210deg, var(--accent), var(--accent2), var(--accent));
    display: grid; place-items: center;
  }
  .logo span { width: 14px; height: 14px; border-radius: 50%; background: #16102a; box-shadow: 0 0 0 4px rgba(255,255,255,.25); }
  h1 { font-size: 21px; margin: 0; letter-spacing: .2px; }
  .sub { color: var(--muted); font-size: 13px; margin-top: 2px; }
  .drop {
    border: 2px dashed var(--line); border-radius: 18px; padding: 42px 20px; text-align: center;
    background: var(--card); transition: .18s border-color, .18s background, .18s transform;
    cursor: pointer;
  }
  .drop:hover { border-color: var(--accent); }
  .drop.over { border-color: var(--accent); background: rgba(201,107,255,.12); transform: scale(1.01); }
  .drop h2 { margin: 0 0 6px; font-size: 17px; font-weight: 600; }
  .drop p { margin: 0; color: var(--muted); font-size: 13px; }
  .btn {
    display: inline-block; margin-top: 16px; padding: 10px 20px; border-radius: 999px; border: 0;
    background: linear-gradient(120deg, var(--accent), var(--accent2)); color: #fff; font-weight: 600;
    font-size: 14px; cursor: pointer;
  }
  .btn.ghost { background: transparent; border: 1px solid var(--line); color: var(--text); font-weight: 500; }
  input[type=file] { display: none; }
  .bar { height: 6px; border-radius: 999px; background: rgba(255,255,255,.08); overflow: hidden; }
  .bar > i { display: block; height: 100%; width: 0; background: linear-gradient(90deg, var(--accent), var(--accent2)); transition: width .15s; }
  .total { margin: 22px 0 8px; display: none; }
  .total .label { display: flex; justify-content: space-between; font-size: 13px; color: var(--muted); margin-bottom: 6px; }
  ul { list-style: none; padding: 0; margin: 18px 0 0; }
  li {
    display: grid; grid-template-columns: 1fr auto; gap: 4px 12px; align-items: center;
    padding: 11px 14px; border: 1px solid var(--line); border-radius: 12px; margin-bottom: 8px;
    background: var(--card);
  }
  li .name { font-size: 14px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  li .state { font-size: 12px; color: var(--muted); font-variant-numeric: tabular-nums; }
  li .bar { grid-column: 1 / -1; margin-top: 4px; }
  li.done .state { color: var(--ok); }
  li.err .state { color: var(--err); }
  .panel { margin-top: 30px; border-top: 1px solid var(--line); padding-top: 18px; }
  .panel h3 { font-size: 14px; margin: 0 0 10px; color: var(--muted); font-weight: 600; text-transform: uppercase; letter-spacing: .08em; }
  .lib { max-height: 260px; overflow: auto; font-size: 13px; color: var(--muted); }
  .lib div { padding: 5px 0; border-bottom: 1px solid rgba(255,255,255,.05); }
  .row { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
  footer { margin-top: 28px; color: var(--muted); font-size: 12px; text-align: center; }
  code { background: rgba(255,255,255,.08); padding: 2px 6px; border-radius: 6px; }
</style>
</head>
<body>
<div class="wrap">
  <header>
    <div class="logo"><span></span></div>
    <div>
      <h1>SborraPlay</h1>
      <div class="sub" id="sub">caricamento in corso…</div>
    </div>
  </header>

  <div class="drop" id="drop">
    <h2>Trascina qui i tuoi brani</h2>
    <p>MP3, M4A, WAV, AIFF, FLAC, ALAC — anche cartelle intere e file .m3u</p>
    <button class="btn" id="pick" type="button">Scegli i file</button>
    <input type="file" id="file" multiple accept=".mp3,.m4a,.aac,.wav,.aif,.aiff,.caf,.flac,.alac,.m4b,.m3u,.m3u8,audio/*">
  </div>

  <div class="total" id="total">
    <div class="label"><span id="totalText">0 / 0</span><span id="totalPct">0%</span></div>
    <div class="bar"><i id="totalBar"></i></div>
  </div>

  <ul id="list"></ul>

  <div class="panel">
    <div class="row">
      <h3 style="margin:0;flex:1">Già sul telefono</h3>
      <button class="btn ghost" id="refresh" type="button">Aggiorna</button>
    </div>
    <div class="lib" id="lib">—</div>
  </div>

  <footer>
    Dalla riga di comando: <code>curl -T brano.mp3 http://INDIRIZZO/api/file/brano.mp3</code><br>
    La libreria si aggiorna da sola un paio di secondi dopo l'ultimo file.
  </footer>
</div>

<script>
const drop = document.getElementById('drop');
const fileInput = document.getElementById('file');
const list = document.getElementById('list');
const totalBox = document.getElementById('total');
const totalBar = document.getElementById('totalBar');
const totalText = document.getElementById('totalText');
const totalPct = document.getElementById('totalPct');

const AUDIO = /\.(mp3|m4a|m4b|aac|wav|wave|aif|aiff|aifc|caf|flac|alac|mp4|au|m3u|m3u8)$/i;
let queue = [], busy = false, doneCount = 0, totalCount = 0;

document.getElementById('pick').onclick = () => fileInput.click();
drop.onclick = e => { if (e.target === drop || e.target.tagName === 'H2' || e.target.tagName === 'P') fileInput.click(); };
fileInput.onchange = () => { addFiles([...fileInput.files]); fileInput.value = ''; };

['dragenter','dragover'].forEach(ev => drop.addEventListener(ev, e => {
  e.preventDefault(); drop.classList.add('over');
}));
['dragleave','drop'].forEach(ev => drop.addEventListener(ev, e => {
  e.preventDefault(); drop.classList.remove('over');
}));
drop.addEventListener('drop', async e => {
  const items = e.dataTransfer.items;
  if (items && items.length && items[0].webkitGetAsEntry) {
    const files = [];
    await Promise.all([...items].map(i => walk(i.webkitGetAsEntry(), files)));
    addFiles(files);
  } else {
    addFiles([...e.dataTransfer.files]);
  }
});

function walk(entry, out) {
  return new Promise(resolve => {
    if (!entry) return resolve();
    if (entry.isFile) {
      entry.file(f => { out.push(f); resolve(); }, resolve);
    } else if (entry.isDirectory) {
      const reader = entry.createReader();
      const readAll = () => reader.readEntries(async entries => {
        if (!entries.length) return resolve();
        await Promise.all(entries.map(en => walk(en, out)));
        readAll();
      }, resolve);
      readAll();
    } else resolve();
  });
}

function addFiles(files) {
  const good = files.filter(f => AUDIO.test(f.name));
  const skipped = files.length - good.length;
  if (skipped > 0) toast(skipped + ' file ignorati (formato non supportato)');
  if (!good.length) return;
  totalCount += good.length;
  totalBox.style.display = 'block';
  good.forEach(f => {
    const li = document.createElement('li');
    li.innerHTML = '<div class="name"></div><div class="state">in coda</div><div class="bar"><i></i></div>';
    li.querySelector('.name').textContent = f.name;
    list.prepend(li);
    queue.push({ file: f, li });
  });
  updateTotal();
  pump();
}

function pump() {
  if (busy) return;
  const job = queue.shift();
  if (!job) { busy = false; return; }
  busy = true;
  upload(job).then(() => { busy = false; doneCount++; updateTotal(); pump(); });
}

function upload(job) {
  return new Promise(resolve => {
    const { file, li } = job;
    const state = li.querySelector('.state');
    const bar = li.querySelector('.bar > i');
    const xhr = new XMLHttpRequest();
    xhr.open('PUT', '/api/file/' + encodeURIComponent(file.name));
    xhr.upload.onprogress = e => {
      if (!e.lengthComputable) return;
      const pct = Math.round(e.loaded / e.total * 100);
      bar.style.width = pct + '%';
      state.textContent = pct + '%';
    };
    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        li.classList.add('done'); state.textContent = 'fatto'; bar.style.width = '100%';
      } else {
        li.classList.add('err');
        let msg = 'errore ' + xhr.status;
        try { const j = JSON.parse(xhr.responseText); if (j.error) msg = j.error; } catch (_) {}
        state.textContent = msg;
      }
      resolve();
    };
    xhr.onerror = () => { li.classList.add('err'); state.textContent = 'connessione persa'; resolve(); };
    xhr.send(file);
  });
}

function updateTotal() {
  const pct = totalCount ? Math.round(doneCount / totalCount * 100) : 0;
  totalBar.style.width = pct + '%';
  totalText.textContent = doneCount + ' / ' + totalCount + ' file';
  totalPct.textContent = pct + '%';
  if (doneCount === totalCount && totalCount > 0) setTimeout(loadLibrary, 2500);
}

function toast(msg) {
  document.getElementById('sub').textContent = msg;
}

async function loadLibrary() {
  try {
    const r = await fetch('/api/library');
    const j = await r.json();
    document.getElementById('sub').textContent = j.count + (j.count === 1 ? ' brano sul telefono' : ' brani sul telefono');
    const box = document.getElementById('lib');
    box.innerHTML = '';
    if (!j.tracks.length) { box.textContent = 'Ancora niente. Trascina i primi file qui sopra.'; return; }
    j.tracks.slice().sort((a, b) => a.artist.localeCompare(b.artist)).forEach(t => {
      const d = document.createElement('div');
      d.textContent = t.artist + ' — ' + t.title;
      box.appendChild(d);
    });
  } catch (e) {
    document.getElementById('sub').textContent = 'connessione al telefono persa';
  }
}

document.getElementById('refresh').onclick = loadLibrary;
loadLibrary();
</script>
</body>
</html>
"""#
}
