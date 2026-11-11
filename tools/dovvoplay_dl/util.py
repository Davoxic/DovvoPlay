from __future__ import annotations

import json
import os
import re
import sys
import unicodedata
from pathlib import Path

CONFIG_PATH = Path(os.path.expanduser("~")) / ".dovvoplay-dl.json"

# ---------------------------------------------------------------- output

_COLOR = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None


def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _COLOR else text


def info(msg: str) -> None:
    print(_c("36", "·"), msg)


def ok(msg: str) -> None:
    print(_c("32", "✓"), msg)


def warn(msg: str) -> None:
    print(_c("33", "!"), msg)


def err(msg: str) -> None:
    print(_c("31", "✗"), msg, file=sys.stderr)


def step(msg: str) -> None:
    print()
    print(_c("1;35", msg))


# ---------------------------------------------------------------- testo

_SAFE = re.compile(r'[<>:"/\\|?*\x00-\x1f]')
_SPACES = re.compile(r"\s+")


def safe_filename(name: str, max_len: int = 150) -> str:
    """Nome file valido su Windows, macOS e iOS."""
    name = unicodedata.normalize("NFC", name)
    name = _SAFE.sub("-", name)
    name = name.replace("⁄", "-")
    name = _SPACES.sub(" ", name).strip(" .")
    if not name:
        name = "brano"
    return name[:max_len]


_PAREN = re.compile(r"[\(\[][^)\]]*[\)\]]")
_NONWORD = re.compile(r"[^\w\s]", re.UNICODE)


def normalize(text: str, drop_parens: bool = True) -> str:
    """Forma confrontabile di un titolo: minuscole, senza accenti né punteggiatura."""
    text = unicodedata.normalize("NFKD", text or "")
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    text = text.lower()
    if drop_parens:
        text = _PAREN.sub(" ", text)
    text = text.replace("&", " and ")
    text = _NONWORD.sub(" ", text)
    return _SPACES.sub(" ", text).strip()


def human_time(seconds: float) -> str:
    seconds = int(round(seconds or 0))
    m, s = divmod(seconds, 60)
    h, m = divmod(m, 60)
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"


def human_size(n: float) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} GB"


# ---------------------------------------------------------------- config

def load_config() -> dict:
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return {}


def save_config(data: dict) -> None:
    try:
        current = load_config()
        current.update(data)
        with open(CONFIG_PATH, "w", encoding="utf-8") as fh:
            json.dump(current, fh, indent=2)
    except Exception:
        pass
