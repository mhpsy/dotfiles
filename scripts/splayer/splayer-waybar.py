#!/usr/bin/env python3
"""
waybar-splayer-plugin: Lyrics display for Waybar + SPlayer.
Connects to SPlayer WebSocket, shows current lyric line with cover art.
"""

import asyncio
import json
import os
import signal
import sys
import time
import urllib.request
from pathlib import Path

import websockets

# ── Config ──────────────────────────────────────────────────────────────
WS_URL = os.environ.get("SPLAYER_WS_URL", "ws://localhost:25885")
RECONNECT_INTERVAL = 3
COVER_PATH = Path("/tmp/waybar-splayer-cover.png")
COVER_SIGNAL = 8

COLOR_LYRIC = os.environ.get("SPLAYER_COLOR_LYRIC", "#e8455e")
COLOR_IDLE = os.environ.get("SPLAYER_COLOR_IDLE", "#d4a0aa")


# ── State ───────────────────────────────────────────────────────────────
class State:
    __slots__ = (
        "playing", "song_name", "artist_name", "album_name",
        "cover_url", "last_cover_url",
        "duration_ms", "lrc_data", "yrc_data",
        "server_time_ms", "server_mono",
        "prev_line_idx",
    )

    def __init__(self):
        self.playing = False
        self.song_name = ""
        self.artist_name = ""
        self.album_name = ""
        self.cover_url = ""
        self.last_cover_url = ""
        self.duration_ms = 0.0
        self.lrc_data = []
        self.yrc_data = []
        self.server_time_ms = 0.0
        self.server_mono = time.monotonic()
        self.prev_line_idx = -1

    def sync(self, time_ms):
        self.server_time_ms = float(time_ms)
        self.server_mono = time.monotonic()

    def now_ms(self):
        if not self.playing:
            return self.server_time_ms
        return self.server_time_ms + (time.monotonic() - self.server_mono) * 1000.0

    def lyrics(self):
        return self.yrc_data if self.yrc_data else self.lrc_data


S = State()


# ── Helpers ─────────────────────────────────────────────────────────────
def esc(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def find_line(lyrics, t_ms):
    for i in range(len(lyrics) - 1, -1, -1):
        st = lyrics[i].get("startTime", lyrics[i].get("time", -1))
        if st >= 0 and t_ms >= st:
            return i
    return -1


def extract_lyric_text(line):
    """Extract plain text from a lyric line (works for both lrc and yrc)."""
    words = line.get("words")
    if words and isinstance(words, list):
        return "".join(w.get("word", w.get("text", "")) for w in words).strip()
    return (line.get("text") or line.get("content") or line.get("lyric") or "").strip()


# ── Output ──────────────────────────────────────────────────────────────
_prev_out = None


def emit(text, tooltip="", css_class="playing"):
    global _prev_out
    obj = json.dumps({"text": text, "tooltip": tooltip, "class": css_class},
                     ensure_ascii=False)
    if obj != _prev_out:
        _prev_out = obj
        sys.stdout.write(obj + "\n")
        sys.stdout.flush()


def emit_idle():
    emit("", "SPlayer", "idle")


# ── Render ──────────────────────────────────────────────────────────────
def render():
    """Render current state and emit to waybar."""
    lyrics = S.lyrics()

    if not S.song_name and not lyrics:
        emit_idle()
        return

    if not lyrics:
        emit(f'<span color="{COLOR_IDLE}">{esc(S.song_name)}</span>',
             f"{S.song_name} - {S.artist_name}", "no-lyrics")
        return

    t_ms = S.now_ms()
    idx = find_line(lyrics, t_ms)

    if idx < 0:
        emit(f'<span color="{COLOR_IDLE}">{esc(S.song_name)}</span>',
             f"{S.song_name} - {S.artist_name}", "waiting")
        S.prev_line_idx = -1
        return

    line = lyrics[idx]
    text = extract_lyric_text(line)

    markup = f'<span color="{COLOR_LYRIC}">{esc(text)}</span>'
    tooltip = f"{S.song_name} - {S.artist_name}\n{S.album_name}"
    cls = "playing" if S.playing else "paused"
    emit(markup, tooltip, cls)


# ── WebSocket handlers ─────────────────────────────────────────────────
def extract_cover(data):
    for k in ("cover", "coverUrl", "pic", "picUrl", "albumPic", "image", "img"):
        v = data.get(k, "")
        if v and isinstance(v, str) and v.strip():
            return v.strip()
    return ""


def on_song_info(d):
    S.song_name = d.get("playName", d.get("name", ""))
    S.artist_name = d.get("artistName", d.get("artists", d.get("artist", "")))
    S.album_name = d.get("albumName", d.get("album", ""))
    S.sync(d.get("currentTime", 0))
    S.duration_ms = float(d.get("duration", 0))
    S.playing = d.get("playStatus") == "play"
    c = extract_cover(d)
    if c:
        S.cover_url = c
    if d.get("yrcData"):
        S.yrc_data = d["yrcData"]
    if d.get("lrcData"):
        S.lrc_data = d["lrcData"]


def on_song_change(d):
    S.song_name = d.get("name", d.get("title", ""))
    S.artist_name = d.get("artist", "")
    S.album_name = d.get("album", "")
    S.duration_ms = float(d.get("duration", 0))
    S.sync(0)
    S.lrc_data = []
    S.yrc_data = []
    S.prev_line_idx = -1
    c = extract_cover(d)
    if c:
        S.cover_url = c


def on_progress(d):
    S.sync(d.get("currentTime", 0))
    if "duration" in d:
        S.duration_ms = float(d["duration"])


def on_status(d):
    st = d.get("status")
    was_playing = S.playing
    S.playing = st is True or st == "play"
    if S.playing and not was_playing:
        S.server_mono = time.monotonic()


def on_lyric(d):
    if d.get("yrcData"):
        S.yrc_data = d["yrcData"]
    if d.get("lrcData"):
        S.lrc_data = d["lrcData"]


# ── Cover download ─────────────────────────────────────────────────────
async def download_cover(url):
    if not url or url == S.last_cover_url:
        return
    S.last_cover_url = url

    def _dl():
        try:
            req = urllib.request.Request(url.strip().strip("`"),
                                         headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=5) as r:
                COVER_PATH.write_bytes(r.read())
            os.system(f"pkill -RTMIN+{COVER_SIGNAL} waybar")
        except Exception:
            pass

    await asyncio.get_event_loop().run_in_executor(None, _dl)


# ── WebSocket loop ─────────────────────────────────────────────────────
async def ws_loop():
    while True:
        try:
            async with websockets.connect(WS_URL) as ws:
                await ws.send(json.dumps({"type": "get-song-info"}))
                hb = asyncio.create_task(_heartbeat(ws))
                try:
                    async for raw in ws:
                        if raw == "PONG":
                            continue
                        try:
                            msg = json.loads(raw)
                        except json.JSONDecodeError:
                            continue
                        tp = msg.get("type", "")
                        d = msg.get("data", {})
                        if tp == "song-info":
                            on_song_info(d)
                            if S.cover_url:
                                asyncio.create_task(download_cover(S.cover_url))
                        elif tp == "song-change":
                            on_song_change(d)
                            if S.cover_url:
                                asyncio.create_task(download_cover(S.cover_url))
                            await ws.send(json.dumps({"type": "get-song-info"}))
                        elif tp == "progress-change":
                            on_progress(d)
                        elif tp == "status-change":
                            on_status(d)
                        elif tp == "lyric-change":
                            on_lyric(d)
                        render()
                finally:
                    hb.cancel()
        except (ConnectionRefusedError, OSError, websockets.exceptions.ConnectionClosed):
            S.playing = False
            S.song_name = ""
            S.yrc_data = []
            S.lrc_data = []
            S.prev_line_idx = -1
            S.last_cover_url = ""
            # Remove cover so image module hides too
            if COVER_PATH.exists():
                COVER_PATH.unlink()
                os.system(f"pkill -RTMIN+{COVER_SIGNAL} waybar")
            emit_idle()
            await asyncio.sleep(RECONNECT_INTERVAL)
        except Exception:
            await asyncio.sleep(RECONNECT_INTERVAL)


async def _heartbeat(ws):
    while True:
        await asyncio.sleep(30)
        try:
            await ws.send("PING")
        except Exception:
            break


# ── Main ────────────────────────────────────────────────────────────────
def main():
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    emit_idle()
    asyncio.run(ws_loop())


if __name__ == "__main__":
    main()
