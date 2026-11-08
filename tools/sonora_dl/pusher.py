"""Invio dei file al server Wi-Fi dell'app Sonora sull'iPhone."""
from __future__ import annotations

import json
import socket
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

from .util import human_size, info, warn

DEFAULT_PORT = 8080
SERVICE_TYPE = "_sonora._tcp.local."


@dataclass
class Device:
    name: str
    host: str
    port: int = DEFAULT_PORT

    @property
    def base(self) -> str:
        return f"http://{self.host}:{self.port}"


def normalize_host(raw: str) -> Device:
    """Accetta 192.168.1.9, 192.168.1.9:8080, http://192.168.1.9:8080."""
    raw = (raw or "").strip()
    if not raw:
        raise ValueError("indirizzo vuoto")
    if "://" not in raw:
        raw = "http://" + raw
    parsed = urllib.parse.urlparse(raw)
    host = parsed.hostname or ""
    port = parsed.port or DEFAULT_PORT
    if not host:
        raise ValueError(f"indirizzo non valido: {raw}")
    return Device(name=host, host=host, port=port)


# ------------------------------------------------------------------ scoperta

def discover(timeout: float = 4.0) -> list[Device]:
    """Cerca l'app sulla rete locale via Bonjour. Richiede il pacchetto zeroconf."""
    try:
        from zeroconf import Zeroconf, ServiceBrowser
    except ImportError:
        warn("Pacchetto 'zeroconf' non installato: usa --host con l'indirizzo "
             "mostrato nelle impostazioni dell'app.")
        return []

    found: list[Device] = []

    class Listener:
        def add_service(self, zc, type_, name):
            inf = zc.get_service_info(type_, name, timeout=int(timeout * 1000))
            if not inf:
                return
            for addr in inf.parsed_addresses():
                if ":" in addr:      # scartiamo IPv6
                    continue
                found.append(Device(name=name.split(".")[0], host=addr, port=inf.port or DEFAULT_PORT))
                break

        def update_service(self, zc, type_, name):
            pass

        def remove_service(self, zc, type_, name):
            pass

    zc = Zeroconf()
    try:
        ServiceBrowser(zc, SERVICE_TYPE, Listener())
        import time
        time.sleep(timeout)
    finally:
        zc.close()

    unique: dict[str, Device] = {}
    for d in found:
        unique.setdefault(f"{d.host}:{d.port}", d)
    return list(unique.values())


# ------------------------------------------------------------------ api

def _request(url: str, method: str = "GET", data: bytes | None = None,
             headers: dict | None = None, timeout: int = 20):
    req = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        body = resp.read()
    try:
        return json.loads(body.decode("utf-8"))
    except Exception:
        return {"raw": body.decode("utf-8", "replace")}


def ping(device: Device, timeout: int = 5) -> dict | None:
    try:
        return _request(f"{device.base}/api/ping", timeout=timeout)
    except Exception:
        return None


def library(device: Device) -> dict:
    return _request(f"{device.base}/api/library", timeout=30)


def remote_file_names(device: Device) -> set[str]:
    try:
        data = library(device)
    except Exception:
        return set()
    return {t.get("file", "") for t in data.get("tracks", [])}


class _ProgressReader:
    """File object che riporta l'avanzamento mentre urllib legge."""

    def __init__(self, fh, total: int, callback: Callable[[int, int], None] | None):
        self.fh = fh
        self.total = total
        self.sent = 0
        self.callback = callback

    def read(self, size: int = -1) -> bytes:
        chunk = self.fh.read(size)
        if chunk:
            self.sent += len(chunk)
            if self.callback:
                self.callback(self.sent, self.total)
        return chunk


def upload_file(device: Device, path: Path, overwrite: bool = False,
                progress: Callable[[int, int], None] | None = None,
                timeout: int = 600) -> dict:
    path = Path(path)
    size = path.stat().st_size
    name = urllib.parse.quote(path.name, safe="")
    url = f"{device.base}/api/file/{name}"
    if overwrite:
        url += "?overwrite=1"
    with open(path, "rb") as fh:
        body = _ProgressReader(fh, size, progress)
        req = urllib.request.Request(
            url, data=body, method="PUT",
            headers={"Content-Type": "application/octet-stream",
                     "Content-Length": str(size)},
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read()
    try:
        return json.loads(raw.decode("utf-8"))
    except Exception:
        return {"ok": True, "file": path.name}


def create_playlist(device: Device, name: str, files: list[str]) -> dict:
    payload = json.dumps({"name": name, "files": files}).encode("utf-8")
    return _request(f"{device.base}/api/playlist", method="POST", data=payload,
                    headers={"Content-Type": "application/json"}, timeout=30)


def delete_file(device: Device, file_name: str) -> dict:
    name = urllib.parse.quote(file_name, safe="")
    return _request(f"{device.base}/api/file/{name}", method="DELETE")


def push_many(device: Device, paths: list[Path], skip_existing: bool = True,
              quiet: bool = False) -> tuple[int, list[str]]:
    """Carica una lista di file. Restituisce (quanti ok, nomi caricati)."""
    existing = remote_file_names(device) if skip_existing else set()
    done, names = 0, []
    for i, path in enumerate(paths, start=1):
        path = Path(path)
        if not path.exists():
            warn(f"manca {path}")
            continue
        if skip_existing and path.name in existing:
            if not quiet:
                info(f"[{i}/{len(paths)}] già sul telefono: {path.name}")
            names.append(path.name)
            done += 1
            continue

        label = path.name if len(path.name) <= 48 else path.name[:45] + "…"
        tty = sys.stdout.isatty() and not quiet
        last = {"pct": -1}

        def show(sent: int, total: int, _label=label, _i=i):
            if not tty or not total:
                return
            pct = int(sent * 100 / total)
            if pct == last["pct"]:
                return
            last["pct"] = pct
            bar = "█" * (pct // 5) + "·" * (20 - pct // 5)
            print(f"\r  [{_i}/{len(paths)}] {_label:<48} {bar} {pct:3d}%", end="", flush=True)

        try:
            res = upload_file(device, path, progress=show)
            if not quiet:
                end = "\r" if tty else ""
                print(f"{end}  [{i}/{len(paths)}] {label:<48} {'█'*20} 100%  {human_size(path.stat().st_size)}")
            names.append(res.get("file") or path.name)
            done += 1
        except urllib.error.HTTPError as exc:
            if tty:
                print()
            warn(f"{path.name}: errore {exc.code} dal telefono")
        except (urllib.error.URLError, socket.timeout, OSError) as exc:
            if tty:
                print()
            warn(f"{path.name}: {exc}")
    return done, names
