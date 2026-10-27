#!/usr/bin/env python3
"""Terminal client for several qBittorrent instances.

Shows the torrents of every configured instance in one curses interface,
migrates torrents between instances, optionally moving their data, edits
save paths in bulk and summarises statistics. Uses only the Python standard
library (3.11 or newer).

Run ``qbt-tui --sample-config`` for the configuration format.
"""

from __future__ import annotations

import argparse
import curses
import http.client
import http.cookiejar
import json
import locale
import math
import os
import posixpath
import queue
import re
import signal
import subprocess
import sys
import threading
import time
import tomllib
import traceback
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
import uuid
from collections import Counter, deque
from dataclasses import dataclass
from pathlib import Path

VERSION = "1.0.0"
SYSTEM_CONFIG = Path("/etc/qbt-tui/config.toml")

SAMPLE_CONFIG = """\
# qbt-tui configuration (TOML).
# Read in order and merged: /etc/qbt-tui/config.toml, then
# $XDG_CONFIG_HOME/qbt-tui/config.toml (usually ~/.config/qbt-tui/config.toml).
# --config FILE or $QBT_TUI_CONFIG reads only that file.

refresh = 2.0   # seconds between updates from each instance
timeout = 10.0  # HTTP timeout in seconds

# Keys here apply to every instance that does not set them itself. An instance
# that sets any form of password or api_key replaces all forms of it from here.
[defaults]
# username = "admin"
# password = "..."                          # or one of:
# password_cmd = "pass show qbittorrent"    #   command that prints it
# password_file = "/run/secrets/qbt"        #   file that holds it
# api_key_file = "/run/secrets/qbt-api-key" # Web API key (qBittorrent 5.2+);
#                                           # also api_key / api_key_cmd

[instances.movies]
url = "http://10.1.1.12:8041"

[instances.tv]
url = "http://10.1.1.12:8042"
# enabled = false   # hide an instance without deleting it
"""

STOPPED_STATES = frozenset({"stoppedUP", "stoppedDL", "pausedUP", "pausedDL"})
CHECKING_STATES = frozenset({"checkingUP", "checkingDL", "checkingResumeData"})
ERROR_STATES = frozenset({"error", "missingFiles", "unknown"})
DOWNLOAD_STATES = frozenset({
    "downloading", "forcedDL", "metaDL", "forcedMetaDL", "stalledDL", "queuedDL",
    "checkingDL", "stoppedDL", "pausedDL", "allocating",
})
SEED_STATES = frozenset({"uploading", "forcedUP", "stalledUP", "queuedUP", "checkingUP"})

STATE_LABELS = {
    "error": "Errored",
    "missingFiles": "Missing files",
    "unknown": "Unknown",
    "uploading": "Seeding",
    "stalledUP": "Seeding",
    "forcedUP": "[F] Seeding",
    "queuedUP": "Queued",
    "checkingUP": "Checking",
    "stoppedUP": "Stopped",
    "pausedUP": "Stopped",
    "downloading": "Downloading",
    "forcedDL": "[F] Download",
    "metaDL": "Metadata",
    "forcedMetaDL": "[F] Metadata",
    "stalledDL": "Stalled",
    "queuedDL": "Queued",
    "checkingDL": "Checking",
    "stoppedDL": "Stopped",
    "pausedDL": "Stopped",
    "checkingResumeData": "Checking",
    "allocating": "Allocating",
    "moving": "Moving",
}

STATE_FILTERS = {
    "all": ("All", lambda t: True),
    "downloading": ("Downloading", lambda t: t.get("state") in DOWNLOAD_STATES),
    "seeding": ("Seeding", lambda t: t.get("state") in SEED_STATES),
    "completed": ("Completed", lambda t: t.get("progress", 0) >= 1),
    "running": ("Running", lambda t: t.get("state") not in STOPPED_STATES),
    "stopped": ("Stopped", lambda t: t.get("state") in STOPPED_STATES),
    "active": ("Active", lambda t: t.get("dlspeed", 0) > 0 or t.get("upspeed", 0) > 0),
    "inactive": ("Inactive", lambda t: not (t.get("dlspeed", 0) > 0 or t.get("upspeed", 0) > 0)),
    "stalled": ("Stalled", lambda t: t.get("state") in ("stalledUP", "stalledDL")),
    "checking": ("Checking", lambda t: t.get("state") in CHECKING_STATES),
    "moving": ("Moving", lambda t: t.get("state") == "moving"),
    "errored": ("Errored", lambda t: t.get("state") in ERROR_STATES),
}

BUCKETS = {
    "downloading": "Downloading",
    "seeding": "Seeding",
    "stopped": "Stopped",
    "queued": "Queued",
    "busy": "Checking/moving",
    "errored": "Errored",
}

SORT_KEYS = [
    ("name", "Name"),
    ("instance", "Instance"),
    ("size", "Size"),
    ("progress", "Progress"),
    ("state", "State"),
    ("dlspeed", "Download speed"),
    ("upspeed", "Upload speed"),
    ("ratio", "Ratio"),
    ("uploaded", "Uploaded"),
    ("downloaded", "Downloaded"),
    ("added_on", "Added"),
    ("completion_on", "Completed on"),
    ("last_activity", "Last activity"),
    ("seeding_time", "Seeding time"),
    ("num_seeds", "Seeds"),
    ("num_leechs", "Peers"),
    ("category", "Category"),
    ("save_path", "Save path"),
    ("tracker", "Tracker"),
]
STRING_SORT_KEYS = {"name", "state", "category", "save_path", "tracker"}

COLUMNS = {
    "name": "Name",
    "instance": "Instance",
    "size": "Size",
    "progress": "Done",
    "state": "State",
    "dlspeed": "Down/s",
    "upspeed": "Up/s",
    "ratio": "Ratio",
    "category": "Category",
    "added_on": "Added",
    "save_path": "Save path",
}
COLUMN_ORDER = list(COLUMNS)
# Columns are dropped from the end of this list first as the terminal narrows.
COLUMN_PRIORITY = [
    "progress", "size", "state", "instance", "upspeed", "dlspeed", "ratio",
    "category", "save_path", "added_on",
]
COLUMN_WIDTHS = {
    "size": 9, "progress": 5, "state": 12, "dlspeed": 9, "upspeed": 9,
    "ratio": 6, "category": 12, "added_on": 10, "save_path": 30,
}
RIGHT_ALIGNED = {"size", "progress", "dlspeed", "upspeed", "ratio"}
# A column is only shown if the name column keeps at least this many cells.
NAME_ROOM = {"category": 36, "save_path": 60, "added_on": 60}

TRACKER_STATUS = {0: "disabled", 1: "not contacted", 2: "working", 3: "updating", 4: "not working"}

UNICODE_GLYPHS = {
    "mark": "●", "dot": "●", "off": "○", "up": "▲", "down": "▼", "ell": "…",
    "dl": "↓", "ul": "↑", "to": "→", "cur": "▸", "left": "‹", "right": "›",
    "spin": "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏", "dash": "—", "inf": "∞", "space": "␣", "box": "┌┐└┘─│",
}
ASCII_GLYPHS = {
    "mark": "*", "dot": "*", "off": "o", "up": "^", "down": "v", "ell": "~",
    "dl": "D", "ul": "U", "to": "->", "cur": ">", "left": "<", "right": ">",
    "spin": "|/-\\", "dash": "-", "inf": "inf", "space": "Spc", "box": "",
}
G = dict(UNICODE_GLYPHS)

NET_ERRORS = (OSError, ValueError, http.client.HTTPException)


# ----------------------------------------------------------------------------
# Formatting
# ----------------------------------------------------------------------------

_CONTROL = {c: "?" for c in [*range(32), *range(127, 160)]}


def clean(text):
    return str(text).translate(_CONTROL)


def char_width(ch):
    if unicodedata.combining(ch):
        return 0
    return 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1


def text_width(text):
    return len(text) if text.isascii() else sum(char_width(c) for c in text)


def clip(text, width):
    """Truncate to at most width terminal cells, marking cuts with an ellipsis."""
    text = clean(text)
    if width <= 0:
        return ""
    if text_width(text) <= width:
        return text
    out, used = [], 0
    for ch in text:
        w = char_width(ch)
        if used + w > width - 1:
            break
        out.append(ch)
        used += w
    return "".join(out) + G["ell"]


def clip_left(text, width):
    """Like clip, but keeps the end of the text, which matters most for paths."""
    text = clean(text)
    if width <= 0 or text_width(text) <= width:
        return clip(text, width)
    out, used = [], 0
    for ch in reversed(text):
        w = char_width(ch)
        if used + w > width - 1:
            break
        out.append(ch)
        used += w
    return G["ell"] + "".join(reversed(out))


def fit(text, width, right=False, keep_end=False):
    text = clip_left(text, width) if keep_end else clip(text, width)
    pad = " " * max(0, width - text_width(text))
    return pad + text if right else text + pad


def fmt_size(n):
    if n is None or n < 0:
        return "-"
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        # Switching unit at 1000 keeps values within "999.9 MiB" (9 cells).
        if n < 1000:
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} PiB"


def fmt_speed(n):
    return fmt_size(n) if n else ""


def fmt_pct(p):
    p = p or 0
    return "100%" if p >= 1 else f"{math.floor(p * 1000) / 10:.1f}%"


def fmt_ratio(r):
    if r is None:
        return ""
    return f"{r:.2f}" if r < 100 else f"{r:.0f}"


def fmt_date(ts, with_time=False):
    if not ts or ts <= 0:
        return ""
    return time.strftime("%Y-%m-%d %H:%M" if with_time else "%Y-%m-%d", time.localtime(ts))


def fmt_duration(seconds):
    if seconds is None or seconds < 0 or seconds >= 8640000:
        return G["inf"]
    days, rest = divmod(int(seconds), 86400)
    hours, rest = divmod(rest, 3600)
    minutes = rest // 60
    if days:
        return f"{days}d {hours}h"
    if hours:
        return f"{hours}h {minutes}m"
    return f"{minutes}m"


def fmt_limit(value, unit):
    if value is None:
        return ""
    if value == -2:
        return "global"
    if value < 0:
        return "none"
    return f"{value:g} {unit}".strip()


def split_tags(value):
    return [tag.strip() for tag in (value or "").split(",") if tag.strip()]


def bucket(state):
    if state in ERROR_STATES:
        return "errored"
    if state in STOPPED_STATES:
        return "stopped"
    if state in CHECKING_STATES or state in ("moving", "allocating"):
        return "busy"
    if state in ("queuedUP", "queuedDL"):
        return "queued"
    if state in SEED_STATES:
        return "seeding"
    return "downloading"


def state_color(state):
    if state in ERROR_STATES:
        return "red"
    if state in STOPPED_STATES:
        return "dim"
    if state in CHECKING_STATES or state in ("moving", "allocating", "queuedUP", "queuedDL"):
        return "yellow"
    if state in ("downloading", "forcedDL", "metaDL", "forcedMetaDL"):
        return "green"
    if state in ("uploading", "forcedUP"):
        return "cyan"
    return ""


def common_dir(paths):
    paths = [p for p in paths if p]
    if not paths:
        return ""
    if len(set(paths)) == 1:
        return paths[0]
    try:
        common = posixpath.commonpath(paths)
    except ValueError:
        return ""
    return common if common.endswith("/") else common + "/"


def describe_error(error):
    if isinstance(error, urllib.error.URLError) and not isinstance(error, urllib.error.HTTPError):
        reason = error.reason
        if isinstance(reason, OSError) and reason.strerror:
            return reason.strerror.lower()
        return str(reason)
    if isinstance(error, TimeoutError):
        return "timed out"
    if isinstance(error, json.JSONDecodeError):
        return "invalid JSON from server"
    if isinstance(error, OSError) and error.strerror:
        return error.strerror.lower()
    return str(error) or type(error).__name__


# ----------------------------------------------------------------------------
# Web API client
# ----------------------------------------------------------------------------


class ApiError(Exception):
    def __init__(self, message, status=None):
        super().__init__(message)
        self.status = status


class AuthError(ApiError):
    pass


def encode_value(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def encode_multipart(fields, files):
    boundary = "qbt-tui-" + uuid.uuid4().hex
    body = bytearray()
    for name, value in fields.items():
        body += f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n'.encode()
        body += value.encode() + b"\r\n"
    for name, filename, content in files:
        body += (
            f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; filename="{filename}"\r\n'
            "Content-Type: application/x-bittorrent\r\n\r\n"
        ).encode()
        body += content + b"\r\n"
    body += f"--{boundary}--\r\n".encode()
    return bytes(body), f"multipart/form-data; boundary={boundary}"


class Client:
    """Minimal qBittorrent Web API v2 client."""

    def __init__(self, url, *, username=None, password=None, api_key=None, timeout=10.0):
        self.url = url.rstrip("/")
        self.username = username
        self.password = password
        self.api_key = api_key
        self.timeout = timeout
        self.api_version = (0,)
        self.login_failed = False
        self._login_lock = threading.Lock()
        jar = http.cookiejar.CookieJar()
        self._opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))

    def can_login(self):
        return bool(self.username) and self.password is not None and not self.api_key and not self.login_failed

    def _open(self, path, params, post, files):
        url = f"{self.url}/api/v2/{path}"
        headers = {"User-Agent": f"qbt-tui/{VERSION}"}
        if self.api_key:
            headers["Authorization"] = f"Bearer {self.api_key}"
        fields = {k: encode_value(v) for k, v in (params or {}).items() if v is not None}
        data = None
        if files is not None:
            data, headers["Content-Type"] = encode_multipart(fields, files)
        elif post:
            data = urllib.parse.urlencode(fields).encode()
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        elif fields:
            url += "?" + urllib.parse.urlencode(fields)
        method = "POST" if data is not None else "GET"
        request = urllib.request.Request(url, data=data, headers=headers, method=method)
        with self._opener.open(request, timeout=self.timeout) as response:
            return response.read(), response.headers.get_content_type()

    def call(self, path, params=None, *, post=False, files=None, raw=False):
        for attempt in (0, 1):
            try:
                body, content_type = self._open(path, params, post, files)
                break
            except urllib.error.HTTPError as error:
                message = error.read().decode(errors="replace").strip()
                # qBittorrent answers 403 "Forbidden" without a session, but also
                # uses 403 with a message for permission errors on valid sessions.
                needs_login = error.code == 401 or (error.code == 403 and message in ("", "Forbidden"))
                if needs_login and attempt == 0 and self.can_login():
                    self.login()
                    continue
                if needs_login:
                    if self.login_failed:
                        raise AuthError("login failed: wrong username or password", error.code) from None
                    hint = "not authorised" if (self.username or self.api_key) else "login required"
                    raise AuthError(hint, error.code) from None
                if "banned" in message:
                    raise AuthError(message, error.code) from None
                raise ApiError(message or f"HTTP {error.code} {error.reason}", error.code) from None
        if raw:
            return body
        if content_type == "application/json":
            return json.loads(body) if body else None
        return body.decode(errors="replace")

    def login(self):
        with self._login_lock:
            params = {"username": self.username, "password": self.password}
            try:
                body, _ = self._open("auth/login", params, True, None)
            except urllib.error.HTTPError as error:
                message = error.read().decode(errors="replace").strip()
                if error.code == 401:
                    self.login_failed = True
                    raise AuthError("login failed: wrong username or password", 401) from None
                raise AuthError(message or f"login refused (HTTP {error.code})", error.code) from None
            # Before 5.0, a failed login returned 200 with this body.
            if body.strip() == b"Fails.":
                self.login_failed = True
                raise AuthError("login failed: wrong username or password")

    def connect(self):
        version = self.call("app/version")
        self.api_version = tuple(int(x) for x in re.findall(r"\d+", self.call("app/webapiVersion")))
        return version

    def default_save_path(self):
        return self.call("app/defaultSavePath")

    def _json(self, path, params, kind):
        # A proxy or login page can answer 200 with HTML instead of the API's JSON.
        data = self.call(path, params)
        if data is None:
            return kind()
        if not isinstance(data, kind):
            raise ApiError(f"unexpected response from {path}")
        return data

    def maindata(self, rid):
        return self._json("sync/maindata", {"rid": rid}, dict)

    def info(self, hashes=None):
        return self._json("torrents/info", {"hashes": "|".join(hashes) if hashes else None}, list)

    def files(self, torrent_hash):
        return self._json("torrents/files", {"hash": torrent_hash}, list)

    def properties(self, torrent_hash):
        return self._json("torrents/properties", {"hash": torrent_hash}, dict)

    def trackers(self, torrent_hash):
        return self._json("torrents/trackers", {"hash": torrent_hash}, list)

    def export(self, torrent_hash):
        return self.call("torrents/export", {"hash": torrent_hash}, raw=True)

    def add(self, *, torrents=(), urls=(), **options):
        if urls:
            options["urls"] = "\n".join(urls)
        files = [("torrents", name, data) for name, data in torrents]
        return self.call("torrents/add", options, post=True, files=files)

    def _for(self, action, hashes, **extra):
        return self.call(f"torrents/{action}", {"hashes": "|".join(hashes), **extra}, post=True)

    def start(self, hashes):
        return self._for("resume" if self.api_version < (2, 11) else "start", hashes)

    def stop(self, hashes):
        return self._for("pause" if self.api_version < (2, 11) else "stop", hashes)

    def delete(self, hashes, *, delete_files=False):
        return self._for("delete", hashes, deleteFiles=delete_files)

    def recheck(self, hashes):
        return self._for("recheck", hashes)

    def reannounce(self, hashes):
        return self._for("reannounce", hashes)

    def set_location(self, hashes, location):
        return self._for("setLocation", hashes, location=location)

    def set_category(self, hashes, category):
        return self._for("setCategory", hashes, category=category)

    def create_category(self, name, save_path=""):
        return self.call("torrents/createCategory", {"category": name, "savePath": save_path}, post=True)

    def add_tags(self, hashes, tags):
        return self._for("addTags", hashes, tags=",".join(tags))

    def remove_tags(self, hashes, tags):
        return self._for("removeTags", hashes, tags=",".join(tags))

    def rename_file(self, torrent_hash, old_path, new_path):
        params = {"hash": torrent_hash, "oldPath": old_path, "newPath": new_path}
        return self.call("torrents/renameFile", params, post=True)

    def set_file_priority(self, torrent_hash, ids, priority):
        params = {"hash": torrent_hash, "id": "|".join(map(str, ids)), "priority": priority}
        return self.call("torrents/filePrio", params, post=True)


# ----------------------------------------------------------------------------
# Instances
# ----------------------------------------------------------------------------


class Instance:
    """One qBittorrent instance, kept current by a background thread."""

    def __init__(self, name, url, client, refresh):
        self.name = name
        self.url = url
        self.client = client
        self.refresh = refresh
        self.lock = threading.Lock()
        self.wake = threading.Event()
        self.status = "connecting"
        self.error = ""
        self.version = ""
        self.default_path = ""
        self.gen = 0
        self.updated = 0.0
        self._clear()

    def _clear(self):
        self.rid = 0
        self.torrents = {}
        self.categories = {}
        self.tags = set()
        self.server = {}

    @property
    def online(self):
        return self.status == "online"

    def snapshot(self):
        with self.lock:
            return list(self.torrents.values())

    def meta(self):
        with self.lock:
            return dict(self.categories), set(self.tags)

    def reconnect(self):
        self.client.login_failed = False
        with self.lock:
            if self.status != "online":
                self.status = "connecting"
                self.error = ""
            self.gen += 1
        self.wake.set()

    def poke(self):
        self.wake.set()

    def run(self, stopping):
        backoff = self.refresh
        while not stopping.is_set():
            delay = self.refresh
            try:
                if not self.online:
                    version = self.client.connect()
                    default_path = self.client.default_save_path()
                    with self.lock:
                        self._clear()
                        self.version = version
                        self.default_path = default_path
                self._apply(self.client.maindata(self.rid))
                backoff = self.refresh
            except AuthError as error:
                self._fail("auth", describe_error(error))
                delay = None
            except Exception as error:
                # Anything unexpected also counts as offline; a dead thread would freeze the instance.
                self._fail("offline", describe_error(error))
                backoff = min(backoff * 2, 30)
                delay = backoff
            self.wake.wait(delay)
            self.wake.clear()

    def _fail(self, status, error):
        with self.lock:
            self._clear()
            self.status = status
            self.error = error
            self.gen += 1

    def _apply(self, data):
        with self.lock:
            if data.get("full_update"):
                self.torrents, self.categories, self.tags, self.server = {}, {}, set(), {}
            for torrent_hash, delta in (data.get("torrents") or {}).items():
                # Replace rather than mutate, so snapshots held by the UI stay consistent.
                torrent = dict(self.torrents.get(torrent_hash) or {"hash": torrent_hash})
                torrent.update(delta)
                self.torrents[torrent_hash] = torrent
            for torrent_hash in data.get("torrents_removed") or ():
                self.torrents.pop(torrent_hash, None)
            for name, delta in (data.get("categories") or {}).items():
                self.categories[name] = {**self.categories.get(name, {}), **delta}
            for name in data.get("categories_removed") or ():
                self.categories.pop(name, None)
            self.tags.update(data.get("tags") or ())
            self.tags.difference_update(data.get("tags_removed") or ())
            self.server.update(data.get("server_state") or {})
            self.rid = data.get("rid", 0)
            self.status = "online"
            self.error = ""
            self.updated = time.time()
            self.gen += 1


# ----------------------------------------------------------------------------
# Jobs and operations
# ----------------------------------------------------------------------------


class Cancelled(Exception):
    pass


class Skip(Exception):
    pass


class Job:
    def __init__(self, title, fn):
        self.title = title
        self.fn = fn
        self.progress = ""
        self.cancel = threading.Event()

    def check(self):
        if self.cancel.is_set():
            raise Cancelled()

    def update(self, text):
        self.progress = text

    def sleep(self, seconds):
        if self.cancel.wait(seconds):
            raise Cancelled()


class JobRunner:
    """Runs jobs one at a time on a worker thread."""

    def __init__(self, log, on_done):
        self.log = log
        self.on_done = on_done
        self.queue = queue.Queue()
        self.current = None
        self.closing = threading.Event()
        self.thread = threading.Thread(target=self._run, daemon=True)
        self.thread.start()

    def submit(self, title, fn):
        self.queue.put(Job(title, fn))

    def shutdown(self):
        """Drop queued jobs and cancel the running one; the worker thread ends once it has rolled back."""
        self.closing.set()
        while True:
            try:
                self.queue.get_nowait()
            except queue.Empty:
                break
        self.queue.put(None)
        job = self.current
        if job is not None:
            job.cancel.set()

    def busy(self):
        return self.current is not None or not self.queue.empty()

    def status(self):
        job = self.current
        if job is None:
            return None
        waiting = self.queue.qsize()
        text = f"{job.title}: {job.progress}" if job.progress else job.title
        return text + (f" (+{waiting} queued)" if waiting else "")

    def _run(self):
        while True:
            job = self.queue.get()
            if job is None:
                return
            self.current = job
            if self.closing.is_set():
                job.cancel.set()
            try:
                self.log(job.fn(job) or f"{job.title}: done")
            except Cancelled:
                self.log(f"{job.title}: cancelled", "warn")
            except (ApiError, *NET_ERRORS) as error:
                self.log(f"{job.title}: {describe_error(error)}", "error")
            except Exception:
                self.log(f"{job.title}: internal error, see log file", "error")
                self.log(traceback.format_exc(), "debug")
            finally:
                self.current = None
                self.on_done()


def wait_until(fn, timeout, interval=0.5, sleep=time.sleep):
    deadline = time.monotonic() + timeout
    while True:
        result = fn()
        if result:
            return result
        if time.monotonic() >= deadline:
            return None
        sleep(interval)


def bdecode(data):
    def parse(i):
        kind = data[i:i + 1]
        if kind == b"i":
            end = data.index(b"e", i)
            return int(data[i + 1:end]), end + 1
        if kind in (b"l", b"d"):
            i += 1
            items = []
            while data[i:i + 1] != b"e":
                value, i = parse(i)
                items.append(value)
            if kind == b"l":
                return items, i + 1
            return dict(zip(items[::2], items[1::2])), i + 1
        colon = data.index(b":", i)
        start = colon + 1
        end = start + int(data[i:colon])
        return data[start:end], end

    return parse(0)[0]


def torrent_metadata(payload):
    """Return a .torrent's name and relative file paths (None for a single file)."""
    info = bdecode(payload)[b"info"]
    name = (info.get(b"name.utf-8") or info[b"name"]).decode("utf-8", "replace")
    if b"files" not in info:
        return name, None
    paths = []
    for entry in info[b"files"]:
        if b"p" in entry.get(b"attr", b""):
            continue
        parts = entry.get(b"path.utf-8") or entry[b"path"]
        paths.append("/".join(part.decode("utf-8", "replace") for part in parts))
    return name, paths


def add_options(torrent, *, skip_checking):
    options = {
        "savepath": torrent.get("save_path"),
        "autoTMM": False,
        "category": torrent.get("category") or None,
        "tags": ",".join(split_tags(torrent.get("tags"))) or None,
        "stopped": True,
        "paused": True,
        "skip_checking": skip_checking,
        "sequentialDownload": torrent.get("seq_dl"),
        "firstLastPiecePrio": torrent.get("f_l_piece_prio"),
        "upLimit": torrent.get("up_limit"),
        "dlLimit": torrent.get("dl_limit"),
        "ratioLimit": torrent.get("ratio_limit"),
        "seedingTimeLimit": torrent.get("seeding_time_limit"),
        "inactiveSeedingTimeLimit": torrent.get("inactive_seeding_time_limit"),
    }
    if isinstance(torrent.get("share_limit_action"), str):
        options["shareLimitAction"] = torrent["share_limit_action"]
    # Always set, or the destination's own "keep incomplete torrents in" applies.
    options["useDownloadPath"] = bool(torrent.get("download_path"))
    if torrent.get("download_path"):
        options["downloadPath"] = torrent["download_path"]
    return {k: v for k, v in options.items() if v is not None}


def align_files(client, torrent_hash, wanted, sleep=time.sleep):
    """Rename files on the destination to match the source's layout."""
    want = {f["index"]: f["name"] for f in wanted}
    have = wait_until(lambda: client.files(torrent_hash), 15, sleep=sleep)
    if not have:
        raise ApiError("destination did not report the torrent's files")
    renames = [(f["name"], want[f["index"]]) for f in have if want.get(f["index"], f["name"]) != f["name"]]
    for old, new in renames:
        client.rename_file(torrent_hash, old, new)

    def matches():
        return all(want.get(f["index"], f["name"]) == f["name"] for f in client.files(torrent_hash))

    if renames and not wait_until(matches, 30, sleep=sleep):
        raise ApiError("file renames on the destination did not finish")
    return len(renames)


def align_priorities(client, torrent_hash, wanted):
    """Give the destination's files the source's priorities, including files not to download."""
    have = {f["index"]: f.get("priority") for f in client.files(torrent_hash)}
    groups = {}
    for f in wanted:
        if "priority" in f and have.get(f["index"]) != f["priority"]:
            groups.setdefault(f["priority"], []).append(f["index"])
    for priority, ids in groups.items():
        client.set_file_priority(torrent_hash, ids, priority)


@dataclass
class Move:
    src: Instance
    dst: Instance
    hash: str
    name: str
    progress: float
    was_running: bool
    verify: bool
    added: bool = False


def migrate_prepare(src, dst, torrent_hash, *, verify, log, sleep=time.sleep):
    sc, dc = src.client, dst.client
    found = sc.info([torrent_hash])
    if not found:
        raise Skip(f"no longer on {src.name}")
    torrent = found[0]
    state = torrent.get("state")
    if state in CHECKING_STATES or state == "moving":
        raise Skip(f"busy on {src.name} ({STATE_LABELS.get(state, state)})")
    if dc.info([torrent_hash]):
        raise Skip(f"already on {dst.name}")

    has_metadata = torrent.get("has_metadata", True)
    complete = torrent.get("progress", 0) >= 1
    source_files = sc.files(torrent_hash) if has_metadata else []
    deselected = any(f.get("priority") == 0 for f in source_files)
    move = Move(
        src=src,
        dst=dst,
        hash=torrent_hash,
        name=torrent.get("name") or torrent_hash,
        progress=torrent.get("progress", 0),
        was_running=state not in STOPPED_STATES,
        # Skipping the hash check is only safe for complete data, and it would
        # also mark files deselected on the source as present.
        verify=has_metadata and (verify or not complete or deselected),
    )
    payload = sc.export(torrent_hash) if has_metadata else None
    options = add_options(torrent, skip_checking=has_metadata and not move.verify)
    if payload is not None:
        try:
            original_name, paths = torrent_metadata(payload)
        except Exception:
            original_name, paths = None, None
        # Files sitting directly in the save path mean the source used the
        # "don't create subfolder" layout; matching it avoids renaming files.
        same_files = paths and sorted(paths) == sorted(f["name"] for f in source_files)
        options["contentLayout"] = "NoSubfolder" if same_files else "Original"
        if move.name != original_name:
            options["rename"] = move.name

    category = torrent.get("category") or ""
    if category and category not in dst.meta()[0]:
        category_path = src.meta()[0].get(category, {}).get("savePath", "")
        try:
            dc.create_category(category, category_path)
        except ApiError as error:
            if error.status != 409:
                raise

    if move.was_running:
        sc.stop([torrent_hash])
    try:
        move.added = True
        if payload is not None:
            dc.add(torrents=[(f"{torrent_hash}.torrent", payload)], **options)
        else:
            dc.add(urls=[torrent["magnet_uri"]], **options)
        if not wait_until(lambda: dc.info([torrent_hash]), 30, sleep=sleep):
            raise ApiError(f"torrent did not appear on {dst.name}")
        if source_files:
            renamed = align_files(dc, torrent_hash, source_files, sleep)
            if renamed:
                log(f"{move.name}: renamed {renamed} file(s) on {dst.name} to match {src.name}")
            # Before the recheck, so progress on both sides covers the same files.
            align_priorities(dc, torrent_hash, source_files)
        if move.verify:
            dc.recheck([torrent_hash])
    except BaseException:
        migrate_rollback(move, log)
        raise
    return move


def migrate_finish(move, *, remove_source, start, log):
    sc, dc = move.src.client, move.dst.client
    started = start == "always" or (start == "same" and move.was_running)
    if started:
        dc.start([move.hash])
    if remove_source:
        sc.delete([move.hash], delete_files=False)
    elif move.was_running and not started:
        # Both copies use the same files, so at most one of them runs.
        sc.start([move.hash])
    log(f"{move.name}: {move.src.name} {G['to']} {move.dst.name}")


def migrate_rollback(move, log):
    """Undo a partial migration. Never deletes files."""
    if move.added:
        try:
            move.dst.client.delete([move.hash], delete_files=False)
        except (ApiError, *NET_ERRORS) as error:
            log(f"{move.name}: could not remove it from {move.dst.name}: {describe_error(error)}", "error")
    if move.was_running:
        try:
            move.src.client.start([move.hash])
        except (ApiError, *NET_ERRORS) as error:
            log(f"{move.name}: could not restart it on {move.src.name}: {describe_error(error)}", "error")


def move_source_files(job, log, plan, dst, location, counts):
    """Have each source move its torrents' files to location; return what is left to migrate.

    Torrents already on the destination are skipped first, because moving
    their files would break the destination's copy.
    """
    hashes = [torrent["hash"] for _, torrent in plan]
    present = set()
    for i in range(0, len(hashes), 100):
        present.update(t["hash"] for t in dst.client.info(hashes[i:i + 100]))
    groups = {}
    for src, torrent in plan:
        if torrent["hash"] in present:
            counts["skipped"] += 1
            log(f"{torrent.get('name') or torrent['hash']}: skipped, already on {dst.name}", "warn")
        else:
            groups.setdefault(src, []).append(torrent)
    remaining = []
    for src, torrents in groups.items():
        job.check()
        job.update(f"{src.name}: moving {len(torrents)} torrent(s) to {location}")
        try:
            src.client.set_location([t["hash"] for t in torrents], location)
        except (ApiError, *NET_ERRORS) as error:
            counts["failed"] += len(torrents)
            log(f"{src.name}: could not move {len(torrents)} torrent(s) to {location}: {describe_error(error)}", "error")
            continue
        log(f"{src.name}: moving the files of {len(torrents)} torrent(s) to {location}")
        remaining.extend((src, torrent) for torrent in torrents)
    return remaining


def migrate(job, log, plan, dst, *, remove_source=True, verify=True, start="same", location=None):
    """Move torrents to dst.

    Each source torrent is stopped and added to the destination stopped, at the
    same save path and file layout. With location, the source first moves the
    files there itself, so the destination picks them up at their new path.
    With verify, the destination rechecks the data and the source copy is only
    removed once the destination has at least the same progress. Failures roll
    back to the source.
    """
    counts = Counter()
    pending = []

    def finish(move):
        try:
            migrate_finish(move, remove_source=remove_source, start=start, log=log)
            counts["moved"] += 1
        except (ApiError, *NET_ERRORS) as error:
            log(f"{move.name}: {describe_error(error)}", "error")
            counts["failed"] += 1

    def check_pending():
        """Finish or roll back the torrents whose destination check has ended."""
        try:
            current = {t["hash"]: t for t in dst.client.info([m.hash for m in pending])}
        except (ApiError, *NET_ERRORS) as error:
            log(f"waiting for {dst.name}: {describe_error(error)}", "warn")
            job.sleep(5)
            return
        for move in list(pending):
            torrent = current.get(move.hash)
            if torrent is not None and (torrent.get("state") in CHECKING_STATES or torrent.get("state") == "moving"):
                continue
            # Leave pending first, so an abort cannot roll back a finished move.
            pending.remove(move)
            if torrent is None:
                log(f"{move.name}: disappeared from {dst.name}; kept on {move.src.name}", "error")
                move.added = False
                migrate_rollback(move, log)
                counts["failed"] += 1
            elif torrent.get("progress", 0) + 1e-9 >= move.progress:
                finish(move)
            else:
                log(
                    f"{move.name}: {dst.name} found {fmt_pct(torrent.get('progress'))} of the data,"
                    f" {move.src.name} had {fmt_pct(move.progress)}; kept on {move.src.name}",
                    "error",
                )
                migrate_rollback(move, log)
                counts["failed"] += 1

    def wait_for_source(src, torrent_hash):
        """Wait for src to finish moving the files; return the save path, or None if the torrent went."""
        while True:
            try:
                found = src.client.info([torrent_hash])
            except (ApiError, *NET_ERRORS) as error:
                log(f"waiting for {src.name}: {describe_error(error)}", "warn")
                job.sleep(5)
                continue
            if not found:
                return None
            if found[0].get("state") != "moving":
                return found[0].get("save_path", "")
            # Earlier torrents can finish their destination check meanwhile.
            if pending:
                check_pending()
            job.sleep(2)

    try:
        if location:
            plan = move_source_files(job, log, plan, dst, location, counts)
        total = len(plan)
        for n, (src, torrent) in enumerate(plan, 1):
            job.check()
            name = torrent.get("name") or torrent["hash"]
            if location:
                job.update(f"moving files {n}/{total} on {src.name}: {name}")
                path = wait_for_source(src, torrent["hash"])
                if path is None:
                    counts["skipped"] += 1
                    log(f"{name}: skipped, no longer on {src.name}", "warn")
                    continue
                # A failed move leaves the torrent at its old path.
                if os.path.normpath(path) != os.path.normpath(location):
                    counts["failed"] += 1
                    log(f"{name}: {src.name} could not move the files to {location}; kept on {src.name} at {path}", "error")
                    continue
            job.update(f"adding {n}/{total}: {name}")
            try:
                move = migrate_prepare(src, dst, torrent["hash"], verify=verify, log=log, sleep=job.sleep)
            except Skip as reason:
                counts["skipped"] += 1
                log(f"{name}: skipped, {reason}", "warn")
                continue
            except (ApiError, *NET_ERRORS) as error:
                counts["failed"] += 1
                log(f"{name}: {describe_error(error)}", "error")
                continue
            if move.verify:
                pending.append(move)
            else:
                finish(move)

        while pending:
            job.update(
                f"verifying {len(pending)} on {dst.name} · moved {counts['moved']}"
                f" · failed {counts['failed']}"
            )
            job.sleep(2)
            check_pending()
    except BaseException:
        # Cancelled or failed unexpectedly: undo every move still waiting for its check.
        for move in pending:
            migrate_rollback(move, log)
        if location:
            log("File moves the sources had already started carry on there", "warn")
        raise
    return (
        f"Migrate {G['to']} {dst.name}: {counts['moved']} moved, {counts['skipped']} skipped,"
        f" {counts['failed']} failed"
    )


def wait_for_moves(job, inst, hashes):
    job.sleep(1)
    while True:
        moving = [t for t in inst.client.info(hashes) if t.get("state") == "moving"]
        if not moving:
            return
        job.update(f"{inst.name}: waiting for {len(moving)} move(s)")
        job.sleep(2)


def relocate(job, changes, *, recheck):
    """Apply (instance, hashes, new path) groups with setLocation."""
    touched = {}
    for n, (inst, hashes, path) in enumerate(changes, 1):
        job.check()
        job.update(f"{n}/{len(changes)} {inst.name}: {path}")
        inst.client.set_location(hashes, path)
        touched.setdefault(inst, []).extend(hashes)
    if recheck:
        for inst, hashes in touched.items():
            wait_for_moves(job, inst, hashes)
            inst.client.recheck(hashes)
    count = sum(len(h) for _, h, _ in changes)
    return f"Location set for {count} torrent(s)" + (", rechecking" if recheck else "")


# ----------------------------------------------------------------------------
# Curses widgets
# ----------------------------------------------------------------------------

CONTINUE = object()
ESC = "\x1b"
ENTER = ("\n", "\r", curses.KEY_ENTER)
BACKSPACE = (curses.KEY_BACKSPACE, "\x7f", "\b")


class Theme(dict):
    def __missing__(self, key):
        return 0


def make_theme():
    theme = Theme(bold=curses.A_BOLD, dim=curses.A_DIM, reverse=curses.A_REVERSE)
    if not curses.has_colors():
        theme["bar"] = curses.A_REVERSE
        return theme
    curses.start_color()
    background = -1
    try:
        curses.use_default_colors()
    except curses.error:
        background = curses.COLOR_BLACK
    colors = {
        "red": curses.COLOR_RED,
        "green": curses.COLOR_GREEN,
        "yellow": curses.COLOR_YELLOW,
        "blue": curses.COLOR_BLUE,
        "magenta": curses.COLOR_MAGENTA,
        "cyan": curses.COLOR_CYAN,
    }
    for n, (name, color) in enumerate(colors.items(), 1):
        curses.init_pair(n, color, background)
        theme[name] = curses.color_pair(n)
    curses.init_pair(10, curses.COLOR_WHITE, curses.COLOR_BLUE)
    theme["bar"] = curses.color_pair(10)
    return theme


def put(win, y, x, text, attr=0):
    height, width = win.getmaxyx()
    if not (0 <= y < height and 0 <= x < width):
        return
    try:
        win.addstr(y, x, clip(text, width - x), attr)
    except curses.error:
        pass  # writing the bottom-right cell moves the cursor off the window


def put_segments(win, y, x, width, segments, skip=0):
    for text, attr in segments:
        text = clean(text)
        if skip:
            if skip >= len(text):
                skip -= len(text)
                continue
            text, skip = text[skip:], 0
        if width <= 0:
            return
        text = clip(text, width)
        put(win, y, x, text, attr)
        used = text_width(text)
        x += used
        width -= used


def as_segments(line):
    if isinstance(line, str):
        return [(line, 0)]
    if isinstance(line, tuple):
        return [line]
    return line


def draw_box(win):
    # ACS line drawing misrenders in some UTF-8 terminals, so draw Unicode when we can.
    if not G["box"]:
        win.box()
        return
    tl, tr, bl, br, hz, vt = G["box"]
    height, width = win.getmaxyx()
    put(win, 0, 0, tl + hz * (width - 2) + tr)
    for y in range(1, height - 1):
        put(win, y, 0, vt)
        put(win, y, width - 1, vt)
    put(win, height - 1, 0, bl + hz * (width - 2) + br)


def vline(win, y, x, length):
    if G["box"]:
        for row in range(y, y + length):
            put(win, row, x, G["box"][5])
    else:
        try:
            win.vline(y, x, curses.ACS_VLINE, length)
        except curses.error:
            pass


def popup(screen_h, screen_w, height, width):
    height = max(3, min(height, screen_h - 2))
    width = max(10, min(width, screen_w - 2))
    win = curses.newwin(height, width, (screen_h - height) // 2, (screen_w - width) // 2)
    win.erase()
    draw_box(win)
    return win


class LineEdit:
    """Single-line editor with Emacs-style keys and Tab completion."""

    def __init__(self, text="", completions=(), kind="word"):
        self.text = text
        self.pos = len(text)
        self.completions = completions
        self.kind = kind
        self._cycle = None

    def handle(self, key):
        text, pos = self.text, self.pos
        if key == "\t":
            return self.complete()
        self._cycle = None
        if key == curses.KEY_LEFT:
            self.pos = max(0, pos - 1)
        elif key == curses.KEY_RIGHT:
            self.pos = min(len(text), pos + 1)
        elif key in (curses.KEY_HOME, "\x01"):
            self.pos = 0
        elif key in (curses.KEY_END, "\x05"):
            self.pos = len(text)
        elif key in BACKSPACE:
            if pos:
                self.text = text[:pos - 1] + text[pos:]
                self.pos = pos - 1
        elif key in (curses.KEY_DC, "\x04"):
            self.text = text[:pos] + text[pos + 1:]
        elif key == "\x15":
            self.text, self.pos = text[pos:], 0
        elif key == "\x0b":
            self.text = text[:pos]
        elif key == "\x17":
            i = pos
            while i and text[i - 1] in " /,":
                i -= 1
            while i and text[i - 1] not in " /,":
                i -= 1
            self.text, self.pos = text[:i] + text[pos:], i
        elif isinstance(key, str) and key.isprintable():
            self.text = text[:pos] + key + text[pos:]
            self.pos = pos + len(key)
        else:
            return False
        return True

    def _split(self):
        if self.kind == "list":
            cut = self.text.rfind(",") + 1
            base = self.text[:cut]
            return base + (" " if base else ""), self.text[cut:].strip()
        return "", self.text

    def _matches(self, prefix):
        if self.kind == "path":
            found = set()
            for path in self.completions:
                if path.startswith(prefix) and len(path) > len(prefix):
                    i = path.find("/", len(prefix))
                    found.add(path if i < 0 else path[:i + 1])
            return sorted(found)
        folded = prefix.casefold()
        return sorted(c for c in self.completions if c.casefold().startswith(folded) and c != prefix)

    def complete(self):
        if self._cycle and self._cycle[0] == self.text:
            _, base, matches, i = self._cycle
            i = (i + 1) % len(matches)
        else:
            base, prefix = self._split()
            matches = self._matches(prefix)
            if not matches:
                return False
            i = 0
        self.text = base + matches[i]
        self.pos = len(self.text)
        self._cycle = (self.text, base, matches, i)
        return True


class TextField:
    def __init__(self, key, label, value="", completions=(), kind="word"):
        self.key = key
        self.label = label
        self.edit = LineEdit(value, completions, kind)

    def value(self):
        return self.edit.text.strip()

    def draw(self, win, y, x, width, focused, app):
        text, pos = self.edit.text, self.edit.pos
        start = 0
        while start < pos and text_width(text[start:pos]) > width - 1:
            start += 1
        attr = curses.A_UNDERLINE | (curses.A_BOLD if focused else 0)
        put(win, y, x, fit(text[start:], width), attr)
        return x + text_width(text[start:pos]) if focused else None

    def handle(self, key, app):
        return self.edit.handle(key)


class ChoiceField:
    def __init__(self, key, label, options, value=None):
        self.key = key
        self.label = label
        self.options = options
        self.index = next((i for i, (v, _) in enumerate(options) if v == value), 0)

    def value(self):
        return self.options[self.index][0]

    def draw(self, win, y, x, width, focused, app):
        text = f"{G['left']} {self.options[self.index][1]} {G['right']}"
        put(win, y, x, clip(text, width), curses.A_REVERSE if focused else curses.A_BOLD)
        return None

    def handle(self, key, app):
        if key in (curses.KEY_LEFT, "h"):
            self.index = (self.index - 1) % len(self.options)
        elif key in (curses.KEY_RIGHT, "l"):
            self.index = (self.index + 1) % len(self.options)
        elif key == " ":
            picked = app.run_modal(Picker(self.label, [label for _, label in self.options], self.index))
            if picked is not None:
                self.index = picked
        else:
            return False
        return True


class Form:
    """Modal dialog with text and choice fields. Returns a dict, or None on Esc."""

    def __init__(self, title, fields, info=(), *, validate=None, footer=None, on_change=None):
        self.title = title
        self.fields = fields
        self.info = list(info)
        self.validate = validate
        self.footer = footer
        self.on_change = on_change
        self.focus = 0
        self.error = ""

    def values(self):
        return {f.key: f.value() for f in self.fields}

    def footer_text(self):
        if self.footer:
            return self.footer
        if not self.fields:
            return "Enter confirm · Esc cancel"
        parts = ["Enter apply", "Esc cancel", "↑↓ field"]
        if any(isinstance(f, ChoiceField) for f in self.fields):
            parts.append("←→/Space change")
        if any(isinstance(f, TextField) for f in self.fields):
            parts.append("Tab complete")
        return " · ".join(parts)

    def draw(self, app, screen_h, screen_w):
        footer = self.footer_text()
        label_w = max((text_width(f.label) for f in self.fields), default=0)
        info_w = max((sum(text_width(s) for s, _ in as_segments(line)) for line in self.info), default=0)
        width = max(64, info_w + 4, text_width(self.title) + 8, text_width(footer) + 4)
        height = 4 + len(self.info) + (1 if self.info and self.fields else 0) + len(self.fields) + 1
        win = popup(screen_h, screen_w, height, width)
        win_h, win_w = win.getmaxyx()
        put(win, 0, 2, f" {self.title} ", curses.A_BOLD | app.theme["cyan"])
        y = 1
        for line in self.info:
            put_segments(win, y, 2, win_w - 4, as_segments(line))
            y += 1
        if self.info and self.fields:
            y += 1
        cursor = None
        for i, field in enumerate(self.fields):
            focused = i == self.focus
            put(win, y, 2, fit(field.label, label_w), curses.A_BOLD if focused else app.theme["dim"])
            x = 4 + label_w
            cx = field.draw(win, y, x, win_w - x - 2, focused, app)
            if cx is not None:
                cursor = (y, cx)
            y += 1
        if self.error:
            put(win, win_h - 3, 2, self.error, app.theme["red"] | curses.A_BOLD)
        put(win, win_h - 2, 2, footer, app.theme["dim"])
        if cursor:
            win.move(*cursor)
        win.noutrefresh()
        return cursor is not None

    def handle(self, key, app):
        if key == ESC:
            return None
        if key in ENTER:
            values = self.values()
            if self.validate:
                self.error = self.validate(values) or ""
                if self.error:
                    return CONTINUE
            return values
        if not self.fields:
            return CONTINUE
        if key in (curses.KEY_UP, curses.KEY_BTAB):
            self.focus = (self.focus - 1) % len(self.fields)
            return CONTINUE
        if key == curses.KEY_DOWN:
            self.focus = (self.focus + 1) % len(self.fields)
            return CONTINUE
        field = self.fields[self.focus]
        if field.handle(key, app):
            if self.on_change:
                self.on_change(field)
        elif key == "\t":
            self.focus = (self.focus + 1) % len(self.fields)
        self.error = ""
        return CONTINUE


class Picker:
    """List chooser; typing filters the list. Returns an index, or None on Esc."""

    def __init__(self, title, items, index=0):
        self.title = title
        self.items = list(items)
        self.sel = index
        self.query = ""
        self.top = 0
        self.rows = 1

    def matches(self):
        folded = self.query.casefold()
        return [i for i, item in enumerate(self.items) if folded in item.casefold()]

    def draw(self, app, screen_h, screen_w):
        matches = self.matches()
        width = max(40, text_width(self.title) + 16, *(text_width(s) + 6 for s in self.items))
        win = popup(screen_h, screen_w, min(len(self.items), screen_h - 8) + 4, width)
        win_h, win_w = win.getmaxyx()
        self.rows = max(1, win_h - 3)
        title = f" {self.title} " + (f"[{self.query}] " if self.query else "")
        put(win, 0, 2, title, curses.A_BOLD | app.theme["cyan"])
        pos = matches.index(self.sel) if self.sel in matches else 0
        self.top = min(max(self.top, pos - self.rows + 1), pos)
        for row in range(self.rows):
            n = self.top + row
            if n >= len(matches):
                break
            attr = curses.A_REVERSE if n == pos else 0
            put(win, 1 + row, 1, fit(" " + self.items[matches[n]], win_w - 2), attr)
        if not matches:
            put(win, 1, 2, "no match", app.theme["dim"])
        put(win, win_h - 2, 2, "Enter choose · Esc cancel · type to filter", app.theme["dim"])
        win.noutrefresh()
        return False

    def handle(self, key, app):
        matches = self.matches()
        pos = matches.index(self.sel) if self.sel in matches else 0
        if key == ESC:
            if self.query:
                self.query = ""
                return CONTINUE
            return None
        if key in ENTER:
            return matches[pos] if matches else CONTINUE
        moves = {
            curses.KEY_UP: -1,
            curses.KEY_DOWN: 1,
            curses.KEY_PPAGE: -self.rows,
            curses.KEY_NPAGE: self.rows,
            curses.KEY_HOME: -len(self.items),
            curses.KEY_END: len(self.items),
        }
        if key in moves:
            if matches:
                self.sel = matches[max(0, min(len(matches) - 1, pos + moves[key]))]
            return CONTINUE
        if key in BACKSPACE:
            self.query = self.query[:-1]
        elif isinstance(key, str) and key.isprintable():
            self.query += key
        matches = self.matches()
        if matches and self.sel not in matches:
            self.sel = matches[0]
        return CONTINUE


class TextView:
    """Scrollable text. With confirm set, Enter returns True and Esc False."""

    def __init__(self, title, lines, *, confirm=None, follow=False):
        self.title = title
        self.lines = lines
        self.confirm = confirm
        self.follow = follow
        self.top = 0
        self.left = 0
        self.rows = 1
        self.count = 0

    def draw(self, app, screen_h, screen_w):
        lines = self.lines() if callable(self.lines) else self.lines
        self.count = len(lines)
        win = popup(screen_h, screen_w, screen_h - 2, screen_w - 4)
        win_h, win_w = win.getmaxyx()
        self.rows = max(1, win_h - 3)
        if self.follow:
            self.top = max(0, self.count - self.rows)
        self.top = max(0, min(self.top, self.count - self.rows))
        put(win, 0, 2, f" {self.title} ", curses.A_BOLD | app.theme["cyan"])
        for row in range(self.rows):
            n = self.top + row
            if n >= self.count:
                break
            put_segments(win, 1 + row, 2, win_w - 4, as_segments(lines[n]), self.left)
        position = f"{min(self.top + 1, self.count)}-{min(self.top + self.rows, self.count)}/{self.count}"
        action = f"Enter {self.confirm} · Esc back" if self.confirm else "Esc close"
        put(win, win_h - 2, 2, f"{position} · ↑↓ PgUp PgDn scroll · ←→ pan · {action}", app.theme["dim"])
        win.noutrefresh()
        return False

    def handle(self, key, app):
        if self.confirm and (key in ENTER or key == "y"):
            return True
        if key in (ESC, "q") or (not self.confirm and key in ENTER):
            return False if self.confirm else None
        moves = {
            curses.KEY_UP: -1, "k": -1,
            curses.KEY_DOWN: 1, "j": 1,
            curses.KEY_PPAGE: -self.rows, curses.KEY_NPAGE: self.rows, " ": self.rows,
            curses.KEY_HOME: -self.count, "g": -self.count,
            curses.KEY_END: self.count, "G": self.count,
        }
        if key in moves:
            self.top = max(0, min(self.top + moves[key], self.count - self.rows))
            self.follow = self.top >= self.count - self.rows
        elif key in (curses.KEY_LEFT, "h"):
            self.left = max(0, self.left - 8)
        elif key in (curses.KEY_RIGHT, "l"):
            self.left += 8
        return CONTINUE


# ----------------------------------------------------------------------------
# Application
# ----------------------------------------------------------------------------

HINTS = [
    ("space", "select"), ("m", "migrate"), ("l", "location"), ("e", "edit paths"),
    ("s/p", "start/stop"), ("d", "delete"), ("f", "filter"), ("/", "search"),
    ("o", "sort"), ("S", "stats"), ("x", "actions"), ("?", "help"), ("q", "quit"),
]

HELP = [
    ("Movement", [
        ("↑ ↓  j k", "move the cursor"),
        ("PgUp PgDn", "move a page"),
        ("g G  Home End", "first / last torrent"),
        ("Tab", "focus the instance list (↑↓ choose, Tab/Enter back)"),
        ("0-9  [ ]", "show all instances / one instance / previous, next"),
    ]),
    ("Selection", [
        ("Space", "select the torrent and move down"),
        ("a", "select every shown torrent"),
        ("n", "clear the selection"),
        ("i", "invert the selection of shown torrents"),
    ]),
    ("View", [
        ("/", "search name, save path, category, tags and hash (Esc clears)"),
        ("f", "filter by state, category and tag"),
        ("o  O", "choose the sort column / reverse the order"),
        ("Enter", "torrent details, trackers and files"),
        ("S", "statistics for instances, the view and the selection"),
        ("L", "log (also written to ~/.local/state/qbt-tui/qbt-tui.log)"),
        ("r", "reconnect offline instances and refresh"),
    ]),
    ("Actions apply to the selection, or to the torrent under the cursor", [
        ("m", "migrate to another instance, optionally moving the files"),
        ("l", "set location: qBittorrent moves the files"),
        ("e", "edit save paths with find and replace, with a preview"),
        ("s  p", "start / stop"),
        ("R", "recheck"),
        ("C", "set category"),
        ("T", "add or remove tags"),
        ("d", "delete (keeps files unless you choose otherwise)"),
        ("x", "menu of all actions"),
        ("K", "cancel the running job"),
        ("q", "quit"),
    ]),
    ("Migration", [
        ("", "The source torrent stops, then the destination adds it stopped at the"),
        ("", "same save path and file layout. By default the destination rechecks the"),
        ("", "data and the source copy is removed only once the check finds at least"),
        ("", "the same progress; otherwise the migration is rolled back. Files are"),
        ("", "never deleted. Both instances must see the data at the same path."),
        ("", "With Files set to move, the source first moves the data to the new"),
        ("", "path and the destination then adds and checks it there. A source copy"),
        ("", "you keep stays stopped if the destination starts, so the two never run"),
        ("", "on the same files at once."),
    ]),
]


class App:
    def __init__(self, screen, instances, *, log_path=None):
        self.scr = screen
        self.instances = instances
        self.by_name = {inst.name: inst for inst in instances}
        self.theme = make_theme()
        self.logs = deque(maxlen=2000)
        self.message = None
        self.log_file = None
        if log_path:
            try:
                log_path.parent.mkdir(parents=True, exist_ok=True)
                self.log_file = open(log_path, "a", buffering=1, encoding="utf-8")
            except OSError:
                pass
        self.stopping = threading.Event()
        self.jobs = JobRunner(self.log, self.poke_all)

        self.focus = "table"
        self.side_index = 0
        self.inst_filter = None
        self.state_filter = "all"
        self.cat_filter = None
        self.tag_filter = None
        self.search = ""
        self.terms = []
        self.search_edit = None
        self.search_before = ""
        self.sort_key = "name"
        self.sort_rev = False

        self.rows = []
        self.row_keys = set()
        self.index = {}
        self.cursor = 0
        self.cursor_key = None
        self.top = 0
        self.page = 1
        self.selected = set()
        self.view_version = 0
        self.view_key = None
        self.modals = []
        self.frame = 0

        try:
            curses.curs_set(0)
        except curses.error:
            pass
        try:
            curses.set_escdelay(25)
        except (AttributeError, curses.error):
            pass
        screen.keypad(True)
        screen.timeout(250)
        for inst in instances:
            threading.Thread(target=inst.run, args=(self.stopping,), daemon=True).start()

    # -- logging --------------------------------------------------------------

    def log(self, text, level="info"):
        now = time.time()
        if level != "debug":
            entry = (now, level, text)
            self.logs.append(entry)
            self.message = entry
        if self.log_file:
            stamp = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(now))
            try:
                self.log_file.write(f"{stamp} {level.upper():5} {text}\n")
            except OSError:
                pass

    def poke_all(self):
        for inst in self.instances:
            inst.poke()

    # -- view model -----------------------------------------------------------

    def invalidate(self):
        self.view_version += 1

    def refresh_view(self):
        key = (tuple(inst.gen for inst in self.instances), self.view_version)
        if key == self.view_key:
            return
        self.view_key = key
        index = {}
        rows = []
        for inst in self.instances:
            for torrent in inst.snapshot():
                index[(inst.name, torrent["hash"])] = (inst, torrent)
                if self.matches(inst, torrent):
                    rows.append((inst, torrent))
        rows.sort(key=lambda r: (r[1].get("name") or "").casefold())
        rows.sort(key=lambda r: self.sort_value(*r), reverse=self.sort_rev)
        self.index = index
        self.rows = rows
        self.row_keys = {(inst.name, t["hash"]) for inst, t in rows}
        online = {inst.name for inst in self.instances if inst.online}
        # Keep selections on instances that are only briefly offline.
        self.selected = {k for k in self.selected if k in index or k[0] not in online}
        if self.cursor_key is not None:
            for i, (inst, torrent) in enumerate(rows):
                if (inst.name, torrent["hash"]) == self.cursor_key:
                    self.cursor = i
                    break
        self.cursor = max(0, min(self.cursor, len(rows) - 1))
        self.cursor_key = self.row_key(self.cursor)

    def row_key(self, i):
        if 0 <= i < len(self.rows):
            inst, torrent = self.rows[i]
            return (inst.name, torrent["hash"])
        return None

    def matches(self, inst, torrent):
        if self.inst_filter and inst.name != self.inst_filter:
            return False
        if not STATE_FILTERS[self.state_filter][1](torrent):
            return False
        if self.cat_filter is not None and (torrent.get("category") or "") != self.cat_filter:
            return False
        if self.tag_filter is not None:
            tags = split_tags(torrent.get("tags"))
            if (self.tag_filter == "" and tags) or (self.tag_filter and self.tag_filter not in tags):
                return False
        if self.terms:
            haystack = "\n".join(
                str(torrent.get(k) or "") for k in ("name", "save_path", "category", "tags", "hash")
            ).casefold()
            return all(term in haystack for term in self.terms)
        return True

    def sort_value(self, inst, torrent):
        if self.sort_key == "instance":
            return inst.name.casefold()
        if self.sort_key in STRING_SORT_KEYS:
            value = torrent.get(self.sort_key) or ""
            if self.sort_key == "state":
                value = STATE_LABELS.get(value, value)
            return value.casefold()
        value = torrent.get(self.sort_key)
        return value if isinstance(value, (int, float)) else -1

    def targets(self):
        if self.selected:
            found = [self.index[k] for k in self.selected if k in self.index]
            found.sort(key=lambda r: (r[0].name, (r[1].get("name") or "").casefold()))
            return found
        if self.rows:
            return [self.rows[self.cursor]]
        return []

    def known_paths(self):
        paths = {t.get("save_path") for _, t in self.index.values()}
        for inst in self.instances:
            categories, _ = inst.meta()
            paths.update(c.get("savePath") for c in categories.values())
        return sorted(p for p in paths if p)

    def known_categories(self):
        names = {t.get("category") for _, t in self.index.values()}
        for inst in self.instances:
            names.update(inst.meta()[0])
        return sorted((n for n in names if n), key=str.casefold)

    def known_tags(self):
        tags = set()
        for _, torrent in self.index.values():
            tags.update(split_tags(torrent.get("tags")))
        for inst in self.instances:
            tags.update(inst.meta()[1])
        return sorted(tags, key=str.casefold)

    def inst_color(self, inst):
        palette = ("cyan", "magenta", "green", "yellow", "blue", "red")
        return self.theme[palette[self.instances.index(inst) % len(palette)]]

    # -- main loop ------------------------------------------------------------

    def getkey(self):
        try:
            return self.scr.get_wch()
        except curses.error:
            return None

    def run(self):
        self.log(f"qbt-tui {VERSION}: {len(self.instances)} instance(s)", "debug")
        try:
            while True:
                self.refresh_view()
                self.draw()
                key = self.getkey()
                if key is None or key == curses.KEY_RESIZE:
                    continue
                if self.search_edit is not None:
                    self.handle_search(key)
                elif self.handle_key(key) == "quit":
                    break
        finally:
            self.shutdown()

    def shutdown(self):
        """Cancel jobs and wait for the running one to roll back; Ctrl-C again quits at once."""
        self.stopping.set()
        job = self.jobs.current
        self.jobs.shutdown()
        if job is not None:
            self.log(f"Quitting: cancelling {job.title}", "warn")
            job.update("cancelling · Ctrl-C again quits now")
        while self.jobs.thread.is_alive():
            try:
                self.draw()
            except Exception:
                pass  # best effort: the terminal may be gone, and the rollback matters more
            self.jobs.thread.join(0.25)

    def run_modal(self, modal):
        self.modals.append(modal)
        try:
            while True:
                self.refresh_view()
                self.draw()
                key = self.getkey()
                if key is None or key == curses.KEY_RESIZE:
                    continue
                result = modal.handle(key, self)
                if result is not CONTINUE:
                    return result
        finally:
            self.modals.pop()

    # -- drawing --------------------------------------------------------------

    def draw(self):
        self.frame += 1
        scr = self.scr
        scr.erase()
        height, width = scr.getmaxyx()
        show_cursor = False
        if height < 10 or width < 50:
            put(scr, 0, 0, "Terminal too small for qbt-tui")
        else:
            self.draw_header(width)
            side = 26 if width >= 100 else 0
            if side:
                self.draw_sidebar(1, height - 3, side)
            self.draw_table(1, side + (1 if side else 0), height - 3, width - side - (1 if side else 0))
            cursor = self.draw_status(height - 2, width)
            self.draw_hints(height - 1, width)
            if cursor:
                scr.move(*cursor)
                show_cursor = True
        scr.noutrefresh()
        if height >= 10 and width >= 50:
            for modal in self.modals:
                show_cursor = modal.draw(self, height, width)
        try:
            curses.curs_set(1 if show_cursor else 0)
        except curses.error:
            pass
        curses.doupdate()

    def draw_header(self, width):
        online = [inst for inst in self.instances if inst.online]
        down = sum(inst.server.get("dl_info_speed", 0) or 0 for inst in online)
        up = sum(inst.server.get("up_info_speed", 0) or 0 for inst in online)
        size = sum(t.get("size", 0) or 0 for _, t in self.index.values())
        text = (
            f" qbt-tui   {len(online)}/{len(self.instances)} online   "
            f"{G['dl']} {fmt_size(down)}/s  {G['ul']} {fmt_size(up)}/s   "
            f"{len(self.index)} torrents · {fmt_size(size)}"
        )
        clock = time.strftime("%H:%M:%S ")
        bar = self.theme["bar"] | curses.A_BOLD
        put(self.scr, 0, 0, fit(text, width - len(clock)) + clock, bar)

    def draw_sidebar(self, top, bottom, width):
        scr, th = self.scr, self.theme
        vline(scr, top, width, bottom - top + 1)
        put(scr, top, 1, "INSTANCES", curses.A_BOLD | th["dim"])
        items = [None, *self.instances]
        y = top + 1
        for i, inst in enumerate(items):
            if y > bottom:
                return
            chosen = (inst is None and self.inst_filter is None) or (inst is not None and inst.name == self.inst_filter)
            if inst is None:
                dot, dot_attr, name, count = " ", 0, "All", str(len(self.index))
            else:
                dot = G["dot"] if inst.online else G["off"]
                dot_attr = {"online": th["green"], "connecting": th["yellow"]}.get(inst.status, th["red"])
                name = inst.name
                count = str(len(inst.torrents)) if inst.online else {"connecting": "…", "auth": "auth"}.get(inst.status, "offline")
            attr = curses.A_REVERSE if (self.focus == "sidebar" and i == self.side_index) else 0
            attr |= curses.A_BOLD if chosen else 0
            put(scr, y, 0, " " * width, attr)
            put(scr, y, 1, G["cur"] if chosen else " ", attr)
            put(scr, y, 3, dot, attr | dot_attr)
            put(scr, y, 5, fit(name, width - 13), attr)
            put(scr, y, width - 8, fit(count, 7, right=True), attr)
            y += 1
        y += 1
        sort_label = dict(SORT_KEYS)[self.sort_key] + " " + (G["down"] if self.sort_rev else G["up"])
        filters = [
            ("State", STATE_FILTERS[self.state_filter][0], self.state_filter != "all"),
            ("Category", self.describe_filter(self.cat_filter, "uncategorized"), self.cat_filter is not None),
            ("Tag", self.describe_filter(self.tag_filter, "untagged"), self.tag_filter is not None),
            ("Search", self.search or "-", bool(self.search)),
            ("Sort", sort_label, False),
        ]
        if y + len(filters) < bottom:
            put(scr, y, 1, "VIEW", curses.A_BOLD | th["dim"])
            for label, value, active in filters:
                y += 1
                put(scr, y, 1, fit(label, 9), th["dim"])
                put(scr, y, 10, fit(value, width - 11), th["yellow"] | curses.A_BOLD if active else 0)
        speeds_y = y + 2
        if speeds_y + len(self.instances) + 1 <= bottom:
            put(scr, speeds_y, 1, f"SPEED   {G['dl']}/s      {G['ul']}/s", curses.A_BOLD | th["dim"])
            for n, inst in enumerate(self.instances, 1):
                server = inst.server if inst.online else {}
                line = (
                    fit(inst.name, 7) + " "
                    + fit(fmt_speed(server.get("dl_info_speed")), 8, right=True) + " "
                    + fit(fmt_speed(server.get("up_info_speed")), 8, right=True)
                )
                put(scr, speeds_y + n, 1, line, th["dim"] if not inst.online else 0)

    @staticmethod
    def describe_filter(value, empty_label):
        if value is None:
            return "any"
        return value or f"({empty_label})"

    def layout(self, width):
        avail = width - 2
        show_instance = self.inst_filter is None and len(self.instances) > 1
        widths = dict(COLUMN_WIDTHS)
        widths["instance"] = min(12, max(8, *(len(inst.name) for inst in self.instances)))
        chosen, used = set(), 0
        for key in COLUMN_PRIORITY:
            if key == "instance" and not show_instance:
                continue
            if used + widths[key] + 1 <= avail - 1 - NAME_ROOM.get(key, 24):
                chosen.add(key)
                used += widths[key] + 1
        widths["name"] = avail - used - 1
        if "save_path" in chosen and widths["name"] > 70:
            widths["save_path"] += widths["name"] - 70
            widths["name"] = 70
        return [(key, widths[key]) for key in COLUMN_ORDER if key == "name" or key in chosen]

    def cell(self, key, inst, torrent):
        if key == "instance":
            return inst.name
        if key == "size":
            return fmt_size(torrent.get("size"))
        if key == "progress":
            return fmt_pct(torrent.get("progress"))
        if key == "state":
            state = torrent.get("state", "")
            return STATE_LABELS.get(state, state)
        if key in ("dlspeed", "upspeed"):
            return fmt_speed(torrent.get(key))
        if key == "ratio":
            return fmt_ratio(torrent.get("ratio"))
        if key == "added_on":
            return fmt_date(torrent.get("added_on"))
        return str(torrent.get(key) or "")

    def draw_table(self, top, left, bottom, width):
        scr, th = self.scr, self.theme
        columns = self.layout(width)
        x = left + 2
        for key, w in columns:
            title = COLUMNS[key]
            if key == self.sort_key:
                title += G["down"] if self.sort_rev else G["up"]
            put(scr, top, x, fit(title, w, right=key in RIGHT_ALIGNED), curses.A_BOLD | curses.A_UNDERLINE)
            x += w + 1
        self.page = max(1, bottom - top)
        if self.cursor < self.top:
            self.top = self.cursor
        elif self.cursor >= self.top + self.page:
            self.top = self.cursor - self.page + 1
        self.top = max(0, min(self.top, max(0, len(self.rows) - self.page)))

        for row in range(self.page):
            n = self.top + row
            if n >= len(self.rows):
                break
            inst, torrent = self.rows[n]
            y = top + 1 + row
            marked = (inst.name, torrent["hash"]) in self.selected
            state = torrent.get("state", "")
            base = 0
            if n == self.cursor:
                base = curses.A_REVERSE if self.focus == "table" else curses.A_UNDERLINE
                put(scr, y, left, " " * width, base)
            elif state in STOPPED_STATES:
                base = th["dim"]
            if marked:
                put(scr, y, left, G["mark"], base | th["yellow"] | curses.A_BOLD)
            x = left + 2
            for key, w in columns:
                attr = base
                if key == "state":
                    attr |= th[state_color(state)]
                elif key == "instance":
                    attr |= self.inst_color(inst)
                elif key == "name" and marked:
                    attr |= curses.A_BOLD | th["yellow"]
                elif key == "dlspeed" and torrent.get("dlspeed"):
                    attr |= th["green"]
                elif key == "upspeed" and torrent.get("upspeed"):
                    attr |= th["cyan"]
                text = fit(self.cell(key, inst, torrent), w, right=key in RIGHT_ALIGNED, keep_end=key == "save_path")
                put(scr, y, x, text, attr)
                x += w + 1

        if not self.rows:
            if not any(inst.online for inst in self.instances):
                problems = [f"{inst.name}: {inst.error or inst.status}" for inst in self.instances]
                lines = ["No instance is online.", *problems[:bottom - top - 4], "", "r reconnects · L shows the log"]
            elif self.index:
                lines = ["No torrents match the current filters.", "", "f filter · / search · 0 all instances"]
            else:
                lines = ["No torrents."]
            y = top + max(1, (bottom - top - len(lines)) // 2)
            for i, line in enumerate(lines):
                put(scr, y + i, left + max(2, (width - text_width(line)) // 2), line, th["dim"] if i else curses.A_BOLD)

    def draw_status(self, y, width):
        scr, th = self.scr, self.theme
        put(scr, y, 0, " " * width, th["bar"])
        if self.search_edit is not None:
            prompt = " Search: "
            put(scr, y, 0, prompt, th["bar"] | curses.A_BOLD)
            edit = self.search_edit
            room = width - len(prompt) - 1
            start = 0
            while start < edit.pos and text_width(edit.text[start:edit.pos]) > room - 1:
                start += 1
            put(scr, y, len(prompt), edit.text[start:start + room], th["bar"])
            hint = " Enter keep · Esc cancel "
            if width - len(prompt) - text_width(edit.text) > len(hint) + 4:
                put(scr, y, width - len(hint) - 1, hint, th["bar"])
            return (y, len(prompt) + text_width(edit.text[start:edit.pos]))

        parts = [f" {len(self.rows)} shown"]
        if self.selected:
            chosen = [self.index[k] for k in self.selected if k in self.index]
            size = sum(t.get("size", 0) or 0 for _, t in chosen)
            hidden = len(self.selected - self.row_keys)
            parts.append(f"{len(self.selected)} selected · {fmt_size(size)}" + (f" ({hidden} hidden)" if hidden else ""))
        if self.rows:
            parts.append(f"row {self.cursor + 1}")
        left_text = " · ".join(parts)
        put(scr, y, 0, left_text, th["bar"] | curses.A_BOLD)

        job = self.jobs.status()
        if job:
            spin = G["spin"][self.frame % len(G["spin"])]
            right, attr = f"{spin} {job} ", th["bar"] | curses.A_BOLD
        elif self.message and time.time() - self.message[0] < (20 if self.message[1] == "error" else 8):
            level, text = self.message[1], self.message[2].splitlines()[0]
            right = f"{text} "
            attr = th["bar"] | (curses.A_BOLD if level in ("error", "warn") else 0)
        else:
            return None
        room = width - text_width(left_text) - 3
        if room > 10:
            right = clip(right, room)
            put(scr, y, width - text_width(right) - 1, right, attr)
        return None

    def draw_hints(self, y, width):
        x = 1
        for key, label in HINTS:
            key = G.get(key, key)
            need = len(key) + len(label) + 3
            if x + need > width:
                break
            put(self.scr, y, x, key, self.theme["cyan"] | curses.A_BOLD)
            put(self.scr, y, x + len(key) + 1, label, self.theme["dim"])
            x += need

    # -- keys -----------------------------------------------------------------

    def move(self, delta):
        self.move_to(self.cursor + delta)

    def move_to(self, n):
        if self.rows:
            self.cursor = max(0, min(n, len(self.rows) - 1))
            self.cursor_key = self.row_key(self.cursor)

    def set_instance(self, name):
        self.inst_filter = name
        self.side_index = 0 if name is None else [i.name for i in self.instances].index(name) + 1
        self.invalidate()

    def handle_search(self, key):
        if key in ENTER:
            self.search_edit = None
            return
        if key == ESC:
            self.set_search(self.search_before)
            self.search_edit = None
            return
        if key in (curses.KEY_UP, curses.KEY_DOWN):
            self.move(-1 if key == curses.KEY_UP else 1)
            return
        self.search_edit.handle(key)
        self.set_search(self.search_edit.text)

    def set_search(self, text):
        self.search = text
        self.terms = text.casefold().split()
        self.invalidate()

    def handle_sidebar(self, key):
        items = [None, *self.instances]
        if key in (curses.KEY_UP, "k", curses.KEY_DOWN, "j"):
            step = -1 if key in (curses.KEY_UP, "k") else 1
            self.side_index = (self.side_index + step) % len(items)
            chosen = items[self.side_index]
            self.inst_filter = chosen.name if chosen else None
            self.invalidate()
            return True
        if key in ("\t", ESC, curses.KEY_RIGHT, *ENTER):
            self.focus = "table"
            return True
        return False

    def handle_key(self, key):
        if self.focus == "sidebar" and self.handle_sidebar(key):
            return None
        names = [inst.name for inst in self.instances]
        actions = {
            "m": self.act_migrate,
            "l": self.act_location,
            "e": self.act_edit_paths,
            "s": lambda: self.act_simple("Start", lambda c, h: c.start(h)),
            "p": lambda: self.act_simple("Stop", lambda c, h: c.stop(h)),
            "R": self.act_recheck,
            "C": self.act_category,
            "T": self.act_tags,
            "d": self.act_delete,
            "x": self.act_menu,
            "f": self.filter_dialog,
            "o": self.sort_dialog,
            "S": self.show_stats,
            "L": self.show_log,
            "?": self.show_help,
            "K": self.cancel_job,
        }
        if key in (curses.KEY_DOWN, "j"):
            self.move(1)
        elif key in (curses.KEY_UP, "k"):
            self.move(-1)
        elif key == curses.KEY_NPAGE:
            self.move(self.page)
        elif key == curses.KEY_PPAGE:
            self.move(-self.page)
        elif key in (curses.KEY_HOME, "g"):
            self.move_to(0)
        elif key in (curses.KEY_END, "G"):
            self.move_to(len(self.rows) - 1)
        elif key == "\t":
            self.focus = "sidebar"
        elif key in ("[", "]"):
            current = names.index(self.inst_filter) + 1 if self.inst_filter else 0
            step = -1 if key == "[" else 1
            n = (current + step) % (len(names) + 1)
            self.set_instance(names[n - 1] if n else None)
        elif isinstance(key, str) and len(key) == 1 and key in "0123456789":
            n = int(key)
            if n == 0:
                self.set_instance(None)
            elif n <= len(names):
                self.set_instance(names[n - 1])
        elif key == " ":
            row = self.row_key(self.cursor)
            if row:
                self.selected ^= {row}
                self.move(1)
        elif key == "a":
            self.selected |= self.row_keys
        elif key == "n":
            self.selected.clear()
        elif key == "i":
            self.selected ^= self.row_keys
        elif key == "/":
            self.search_before = self.search
            self.search_edit = LineEdit(self.search)
        elif key == ESC:
            if self.search:
                self.set_search("")
        elif key == "O":
            self.sort_rev = not self.sort_rev
            self.invalidate()
        elif key in ENTER:
            self.show_details()
        elif key == "r":
            for inst in self.instances:
                inst.reconnect()
            self.log("Refreshing all instances")
        elif key in ("q", "Q"):
            if not self.jobs.busy() or self.confirm(
                "Quit while a job runs?",
                ["A job is still running. Quitting cancels it and waits",
                 "for unfinished migrations to roll back."],
                "quit",
            ):
                return "quit"
        elif key in actions:
            actions[key]()
        return None

    # -- dialogs --------------------------------------------------------------

    def confirm(self, title, lines, verb="confirm"):
        form = Form(title, [], info=lines, footer=f"Enter {verb} · Esc cancel")
        return self.run_modal(form) is not None

    def filter_dialog(self):
        categories = self.known_categories()
        tags = self.known_tags()
        fields = [
            ChoiceField("state", "State", [(k, v[0]) for k, v in STATE_FILTERS.items()], self.state_filter),
            ChoiceField("cat", "Category", [(None, "any"), ("", "(uncategorized)"), *((c, c) for c in categories)], self.cat_filter),
            ChoiceField("tag", "Tag", [(None, "any"), ("", "(untagged)"), *((t, t) for t in tags)], self.tag_filter),
        ]
        values = self.run_modal(Form("Filter", fields))
        if values is not None:
            self.state_filter = values["state"]
            self.cat_filter = values["cat"]
            self.tag_filter = values["tag"]
            self.invalidate()

    def sort_dialog(self):
        keys = [k for k, _ in SORT_KEYS]
        picked = self.run_modal(Picker("Sort by", [label for _, label in SORT_KEYS], keys.index(self.sort_key)))
        if picked is not None:
            self.sort_key = keys[picked]
            self.invalidate()

    def cancel_job(self):
        job = self.jobs.current
        if job is None:
            self.log("No job is running")
        elif self.confirm("Cancel job?", [job.title, "Unfinished migrations are rolled back."], "cancel the job"):
            job.cancel.set()

    def act_menu(self):
        entries = [
            ("m", "Migrate to another instance", self.act_migrate),
            ("l", "Set location (moves files)", self.act_location),
            ("e", "Edit save paths (find and replace)", self.act_edit_paths),
            ("s", "Start", lambda: self.act_simple("Start", lambda c, h: c.start(h))),
            ("p", "Stop", lambda: self.act_simple("Stop", lambda c, h: c.stop(h))),
            ("R", "Recheck", self.act_recheck),
            ("", "Reannounce", lambda: self.act_simple("Reannounce", lambda c, h: c.reannounce(h))),
            ("C", "Set category", self.act_category),
            ("T", "Add or remove tags", self.act_tags),
            ("d", "Delete", self.act_delete),
        ]
        count = len(self.targets())
        picked = self.run_modal(Picker(f"Actions for {count} torrent(s)", [f"{k:<2} {label}" for k, label, _ in entries]))
        if picked is not None:
            entries[picked][2]()

    def require_targets(self):
        targets = self.targets()
        if not targets:
            self.log("No torrent selected", "warn")
        return targets

    @staticmethod
    def grouped(targets):
        groups = {}
        for inst, torrent in targets:
            groups.setdefault(inst, []).append(torrent["hash"])
        return groups

    def summary(self, targets):
        size = sum(t.get("size", 0) or 0 for _, t in targets)
        sources = sorted({inst.name for inst, _ in targets})
        return f"{len(targets)} torrent(s) · {fmt_size(size)} on {', '.join(sources)}"

    def act_simple(self, verb, fn):
        targets = self.require_targets()
        if not targets:
            return
        groups = self.grouped(targets)

        def run(job):
            for inst, hashes in groups.items():
                job.check()
                fn(inst.client, hashes)
            return f"{verb}: {len(targets)} torrent(s)"

        self.jobs.submit(f"{verb} {len(targets)}", run)

    def act_recheck(self):
        targets = self.require_targets()
        if targets and self.confirm("Recheck", [self.summary(targets), "qBittorrent reads all of their data again."], "recheck"):
            self.act_simple("Recheck", lambda c, h: c.recheck(h))

    def act_migrate(self):
        targets = self.require_targets()
        if not targets:
            return
        sources = {inst for inst, _ in targets}
        destinations = [i for i in self.instances if i.online and not (len(sources) == 1 and i in sources)]
        if not destinations:
            self.log("No other instance is online", "warn")
            return
        suggested = destinations[0].default_path
        fields = [
            ChoiceField("dest", "Destination", [(i.name, i.name) for i in destinations]),
            ChoiceField("move", "Files", [
                (False, "Leave where they are"),
                (True, "Move to the path below"),
            ]),
            TextField("location", "Move to", suggested, self.known_paths(), "path"),
            ChoiceField("remove", "Source copy", [
                (True, "Remove from source (keeps files)"),
                (False, "Keep on source (stopped if the destination starts)"),
            ]),
            ChoiceField("verify", "Checking", [
                (True, "Recheck on destination first"),
                (False, "Skip hash check (complete torrents only)"),
            ]),
            ChoiceField("start", "Start", [
                ("same", "If it was running"),
                ("never", "Leave stopped"),
                ("always", "Always"),
            ]),
        ]
        info = [
            self.summary(targets),
            "Left in place, the destination must see the data at its current path.",
            "Moved, the source moves the files first and the destination picks them",
            "up there. Torrents already on the destination are skipped.",
        ]
        by_key = {field.key: field for field in fields}

        # Follow the destination's default save path until the user edits it;
        # editing the path selects moving.
        def changed(field):
            nonlocal suggested
            location = by_key["location"].edit
            if field.key == "dest" and location.text == suggested:
                suggested = self.by_name[field.value()].default_path
                location.text, location.pos = suggested, len(suggested)
            elif field.key == "location" and location.text != suggested:
                by_key["move"].index = 1

        def validate(values):
            if values["move"] and not values["location"].startswith("/"):
                return "Enter an absolute path to move the files to"
            return None

        form = Form(f"Migrate {len(targets)} torrent(s)", fields, info, validate=validate, on_change=changed)
        values = self.run_modal(form)
        if values is None:
            return
        location = os.path.normpath(values["location"]) if values["move"] else None
        dst = self.by_name[values["dest"]]
        plan = [(inst, torrent) for inst, torrent in targets if inst is not dst]
        if not plan:
            self.log(f"Everything selected is already on {dst.name}", "warn")
            return

        def run(job):
            return migrate(
                job, self.log, plan, dst,
                remove_source=values["remove"], verify=values["verify"], start=values["start"],
                location=location,
            )

        self.jobs.submit(f"Migrate {len(plan)} {G['to']} {dst.name}", run)

    def act_location(self):
        targets = self.require_targets()
        if not targets:
            return
        paths = sorted({t.get("save_path", "") for _, t in targets})
        current = paths[0] if len(paths) == 1 else f"{len(paths)} different paths"
        fields = [
            TextField("path", "New location", common_dir(paths), self.known_paths(), "path"),
            ChoiceField("recheck", "Recheck", [(False, "No"), (True, "Yes, after the move")]),
        ]
        info = [
            self.summary(targets),
            f"Current: {current}",
            "qBittorrent moves the files. Files that already exist at the new",
            "location are kept, so this also repoints torrents at data you moved.",
        ]

        def validate(values):
            if not values["path"].startswith("/"):
                return "Enter an absolute path"
            return None

        values = self.run_modal(Form(f"Set location for {len(targets)} torrent(s)", fields, info, validate=validate))
        if values is None:
            return
        changes = [(inst, hashes, values["path"]) for inst, hashes in self.grouped(targets).items()]
        self.jobs.submit(f"Set location {len(targets)}", lambda job: relocate(job, changes, recheck=values["recheck"]))

    def act_edit_paths(self):
        targets = self.require_targets()
        if not targets:
            return
        prefix = common_dir([t.get("save_path", "") for _, t in targets])
        known = self.known_paths()
        form = Form(
            f"Edit save paths of {len(targets)} torrent(s)",
            [
                ChoiceField("mode", "Match", [
                    ("prefix", "Path prefix"),
                    ("substring", "Text anywhere (first match)"),
                    ("regex", "Regular expression"),
                ]),
                TextField("find", "Find", prefix, known, "path"),
                TextField("replace", "Replace with", prefix, known, "path"),
                ChoiceField("recheck", "Recheck", [(False, "No"), (True, "Yes, after the move")]),
            ],
            [
                self.summary(targets),
                "Each torrent gets its own new path. A preview follows.",
                "qBittorrent moves the files; files already at the new path are kept.",
            ],
        )
        while True:
            values = self.run_modal(form)
            if values is None:
                return
            try:
                changes = self.path_changes(targets, values)
            except re.error as error:
                form.error = f"Invalid regular expression: {error}"
                continue
            if not changes:
                form.error = "No save path changes"
                continue
            bad = [new for _, _, _, new in changes if not new.startswith("/")]
            if bad:
                form.error = f"Not an absolute path: {bad[0]}"
                continue
            if self.run_modal(TextView("Preview save path changes", self.preview_lines(targets, changes), confirm="apply")):
                break
        groups = {}
        for inst, torrent, _, new in changes:
            groups.setdefault((inst, new), []).append(torrent["hash"])
        plan = [(inst, hashes, new) for (inst, new), hashes in groups.items()]
        self.jobs.submit(f"Edit paths {len(changes)}", lambda job: relocate(job, plan, recheck=values["recheck"]))

    @staticmethod
    def path_changes(targets, values):
        find, replace, mode = values["find"], values["replace"], values["mode"]
        pattern = re.compile(find) if mode == "regex" else None
        changes = []
        for inst, torrent in targets:
            old = torrent.get("save_path", "")
            if mode == "prefix":
                new = replace + old[len(find):] if find and old.startswith(find) else old
            elif mode == "substring":
                new = old.replace(find, replace, 1) if find else old
            else:
                new = pattern.sub(replace, old, count=1)
            if new != old:
                changes.append((inst, torrent, old, new))
        return changes

    def preview_lines(self, targets, changes):
        th = self.theme
        pairs = Counter((old, new) for _, _, old, new in changes)
        lines = [
            (f"{len(changes)} of {len(targets)} torrent(s) change, in {len(pairs)} distinct move(s):", curses.A_BOLD),
            "",
        ]
        for (old, new), count in sorted(pairs.items()):
            lines.append([(f"{count:>5}  ", th["dim"]), (old, th["red"])])
            lines.append([(f"       {G['to']} ", th["dim"]), (new, th["green"])])
        lines += ["", ("Torrents", curses.A_BOLD)]
        for inst, torrent, _, new in sorted(changes, key=lambda c: (c[0].name, c[1].get("name", ""))):
            lines.append([(fit(inst.name, 10) + " ", self.inst_color(inst)), (torrent.get("name", ""), 0)])
        return lines

    def act_category(self):
        targets = self.require_targets()
        if not targets:
            return
        current = {t.get("category") or "" for _, t in targets}
        fields = [TextField("category", "Category", current.pop() if len(current) == 1 else "", self.known_categories())]
        info = [
            self.summary(targets),
            "Leave empty to remove the category. Missing categories are created.",
            "Torrents in automatic mode move to the category's save path.",
        ]
        values = self.run_modal(Form("Set category", fields, info))
        if values is None:
            return
        category = values["category"]
        groups = self.grouped(targets)

        def run(job):
            for inst, hashes in groups.items():
                job.check()
                if category and category not in inst.meta()[0]:
                    try:
                        inst.client.create_category(category)
                    except ApiError as error:
                        if error.status != 409:
                            raise
                inst.client.set_category(hashes, category)
            return f"Category {category or '(none)'} set on {len(targets)} torrent(s)"

        self.jobs.submit(f"Set category {len(targets)}", run)

    def act_tags(self):
        targets = self.require_targets()
        if not targets:
            return
        tags = self.known_tags()
        fields = [
            TextField("add", "Add tags", "", tags, "list"),
            TextField("remove", "Remove tags", "", tags, "list"),
        ]
        values = self.run_modal(Form("Edit tags", fields, [self.summary(targets), "Separate tags with commas."]))
        if values is None:
            return
        add, remove = split_tags(values["add"]), split_tags(values["remove"])
        if not add and not remove:
            return
        groups = self.grouped(targets)

        def run(job):
            for inst, hashes in groups.items():
                job.check()
                if add:
                    inst.client.add_tags(hashes, add)
                if remove:
                    inst.client.remove_tags(hashes, remove)
            return f"Tags updated on {len(targets)} torrent(s)"

        self.jobs.submit(f"Edit tags {len(targets)}", run)

    def act_delete(self):
        targets = self.require_targets()
        if not targets:
            return
        fields = [ChoiceField("files", "Files", [(False, "Keep files on disk"), (True, "Delete files from disk")])]
        values = self.run_modal(Form(f"Delete {len(targets)} torrent(s)", fields, [self.summary(targets)]))
        if values is None:
            return
        if values["files"]:
            check = Form(
                "Delete files from disk",
                [TextField("word", 'Type "delete"', "")],
                [self.summary(targets), ("The torrents' data will be deleted permanently.", self.theme["red"] | curses.A_BOLD)],
                validate=lambda v: None if v["word"] == "delete" else 'Type "delete" to confirm',
            )
            if self.run_modal(check) is None:
                return
        groups = self.grouped(targets)

        def run(job):
            for inst, hashes in groups.items():
                job.check()
                inst.client.delete(hashes, delete_files=values["files"])
            return f"Deleted {len(targets)} torrent(s)" + (" and their files" if values["files"] else "")

        self.jobs.submit(f"Delete {len(targets)}", run)

    # -- views ----------------------------------------------------------------

    def show_help(self):
        th = self.theme
        lines = [(f"qbt-tui {VERSION}", curses.A_BOLD), ""]
        for section, entries in HELP:
            lines.append((section, curses.A_BOLD | th["cyan"]))
            for key, text in entries:
                lines.append([(f"  {key:<16}", th["yellow"] | curses.A_BOLD), (text, 0)])
            lines.append("")
        self.run_modal(TextView("Help", lines))

    def show_log(self):
        th = self.theme
        colors = {"error": th["red"], "warn": th["yellow"]}

        def lines():
            out = []
            for stamp, level, text in list(self.logs):
                prefix = time.strftime("%H:%M:%S ", time.localtime(stamp))
                for part in text.splitlines() or [""]:
                    out.append([(prefix, th["dim"]), (part, colors.get(level, 0))])
            return out or ["Nothing logged yet."]

        self.run_modal(TextView("Log", lines, follow=True))

    def show_details(self):
        if not self.rows:
            return
        inst, torrent = self.rows[self.cursor]
        torrent_hash = torrent["hash"]
        extra = {}

        def load():
            try:
                extra["properties"] = inst.client.properties(torrent_hash)
                extra["trackers"] = inst.client.trackers(torrent_hash)
                extra["files"] = inst.client.files(torrent_hash)
            except (ApiError, *NET_ERRORS) as error:
                extra["error"] = describe_error(error)

        threading.Thread(target=load, daemon=True).start()
        self.run_modal(TextView(torrent.get("name", torrent_hash), lambda: self.detail_lines(inst, torrent, extra)))

    def detail_lines(self, inst, torrent, extra):
        th = self.theme
        t = self.index.get((inst.name, torrent["hash"]), (inst, torrent))[1]
        props = extra.get("properties") or {}

        def row(label, value, attr=0):
            return [(f"{label:<15}", th["dim"]), (str(value), attr)]

        state = t.get("state", "")
        lines = [
            row("Instance", f"{inst.name}  ({inst.url})", self.inst_color(inst)),
            row("Hash", t.get("hash", "")),
            row("State", f"{STATE_LABELS.get(state, state)}  ({state})", th[state_color(state)]),
            row("Progress", f"{fmt_pct(t.get('progress'))} of {fmt_size(t.get('size'))}"
                f" (total {fmt_size(t.get('total_size'))})"),
            row("Transferred", f"{G['dl']} {fmt_size(t.get('downloaded'))}   {G['ul']} {fmt_size(t.get('uploaded'))}"
                f"   ratio {fmt_ratio(t.get('ratio'))}"),
            row("Speed", f"{G['dl']} {fmt_size(t.get('dlspeed'))}/s   {G['ul']} {fmt_size(t.get('upspeed'))}/s"
                f"   ETA {fmt_duration(t.get('eta'))}"),
            row("Peers", f"seeds {t.get('num_seeds', 0)} ({t.get('num_complete', 0)})"
                f"   leechers {t.get('num_leechs', 0)} ({t.get('num_incomplete', 0)})"),
            row("Save path", t.get("save_path", "")),
            row("Content path", t.get("content_path", "")),
        ]
        if t.get("download_path"):
            lines.append(row("Download path", t["download_path"]))
        lines += [
            row("Category", t.get("category") or "-"),
            row("Tags", t.get("tags") or "-"),
            row("Auto mode", "yes" if t.get("auto_tmm") else "no"),
            row("Added", fmt_date(t.get("added_on"), True)),
            row("Completed", fmt_date(t.get("completion_on"), True) or "-"),
            row("Active", f"{fmt_duration(t.get('time_active'))}   seeding {fmt_duration(t.get('seeding_time'))}"),
            row("Limits", f"ratio {fmt_limit(t.get('ratio_limit'), '')}"
                f"   seeding {fmt_limit(t.get('seeding_time_limit'), 'min')}"
                f"   action {t.get('share_limit_action', '-')}"),
            row("Private", "yes" if t.get("private") else "no"),
        ]
        if props.get("comment"):
            lines.append(row("Comment", props["comment"]))
        if props.get("created_by"):
            lines.append(row("Created by", props["created_by"]))
        if extra.get("error"):
            lines += ["", (f"Could not load details: {extra['error']}", th["red"])]
            return lines
        if "files" not in extra:
            lines += ["", ("Loading trackers and files…", th["dim"])]
            return lines
        trackers = [tr for tr in extra.get("trackers", []) if not str(tr.get("url", "")).startswith("** [")]
        lines += ["", (f"TRACKERS ({len(trackers)})", curses.A_BOLD | th["cyan"])]
        for tr in trackers:
            status = TRACKER_STATUS.get(tr.get("status"), str(tr.get("status")))
            color = {"working": th["green"], "not working": th["red"]}.get(status, th["dim"])
            message = f"  {tr['msg']}" if tr.get("msg") else ""
            lines.append([(f"  {status:<14}", color), (str(tr.get("url", "")), 0), (message, th["dim"])])
        files = extra["files"]
        lines += ["", (f"FILES ({len(files)})", curses.A_BOLD | th["cyan"])]
        for f in files:
            attr = th["dim"] if f.get("priority") == 0 else 0
            lines.append([(f"  {fmt_pct(f.get('progress')):>6} {fmt_size(f.get('size')):>10}  ", th["dim"]), (f.get("name", ""), attr)])
        return lines

    def show_stats(self):
        self.run_modal(TextView("Statistics", self.stats_lines))

    def stats_lines(self):
        th = self.theme
        head = curses.A_BOLD | th["cyan"]
        columns = [
            ("Instance", 12, False), ("Status", 9, False), ("Version", 9, False),
            ("Torrents", 8, True), ("Down", 5, True), ("Seed", 5, True), ("Stop", 5, True),
            ("Error", 5, True), ("Size", 10, True), (f"{G['dl']}/s", 10, True), (f"{G['ul']}/s", 10, True),
            (f"All-time {G['dl']}", 11, True), (f"All-time {G['ul']}", 11, True), ("Ratio", 6, True),
            ("Free", 10, True),
        ]

        def table_row(values):
            return " ".join(fit(str(v), w, right) for v, (_, w, right) in zip(values, columns))

        lines = [("INSTANCES", head), (table_row([c[0] for c in columns]), curses.A_BOLD | curses.A_UNDERLINE)]
        totals = Counter()
        for inst in self.instances:
            torrents = inst.snapshot()
            server = dict(inst.server)
            counts = Counter(bucket(t.get("state", "")) for t in torrents)
            size = sum(t.get("size", 0) or 0 for t in torrents)
            values = [
                inst.name, inst.status, inst.version, len(torrents), counts["downloading"], counts["seeding"],
                counts["stopped"], counts["errored"], fmt_size(size), fmt_speed(server.get("dl_info_speed")),
                fmt_speed(server.get("up_info_speed")), fmt_size(server.get("alltime_dl")),
                fmt_size(server.get("alltime_ul")), server.get("global_ratio", ""),
                fmt_size(server.get("free_space_on_disk")),
            ]
            if inst.online:
                lines.append(table_row(values))
            else:
                lines.append((f"{fit(inst.name, 12)} {fit(inst.status, 9)} {inst.error}", th["red"]))
            totals.update(
                torrents=len(torrents), size=size, dl=server.get("dl_info_speed", 0) or 0,
                ul=server.get("up_info_speed", 0) or 0, alltime_dl=server.get("alltime_dl", 0) or 0,
                alltime_ul=server.get("alltime_ul", 0) or 0, **counts,
            )
        ratio = f"{totals['alltime_ul'] / totals['alltime_dl']:.2f}" if totals["alltime_dl"] else ""
        lines.append((table_row([
            "Total", f"{sum(i.online for i in self.instances)}/{len(self.instances)}", "", totals["torrents"],
            totals["downloading"], totals["seeding"], totals["stopped"], totals["errored"],
            fmt_size(totals["size"]), fmt_speed(totals["dl"]), fmt_speed(totals["ul"]),
            fmt_size(totals["alltime_dl"]), fmt_size(totals["alltime_ul"]), ratio, "",
        ]), curses.A_BOLD))
        lines.append(("Free is the space at each instance's default save path.", th["dim"]))

        if self.selected:
            scope = [self.index[k] for k in self.selected if k in self.index]
            title = f"SELECTION ({len(scope)})"
        else:
            scope = list(self.rows)
            filters = self.describe_view()
            title = f"CURRENT VIEW ({len(scope)})" + (f": {filters}" if filters else "")
        lines += ["", (title, head)]
        torrents = [t for _, t in scope]
        size = sum(t.get("size", 0) or 0 for t in torrents)
        downloaded = sum(t.get("downloaded", 0) or 0 for t in torrents)
        uploaded = sum(t.get("uploaded", 0) or 0 for t in torrents)
        counts = Counter(bucket(t.get("state", "")) for t in torrents)
        lines += [
            f"  Size         {fmt_size(size)}",
            f"  Downloaded   {fmt_size(downloaded)}",
            f"  Uploaded     {fmt_size(uploaded)}" + (f"   ratio {uploaded / downloaded:.2f}" if downloaded else ""),
            "  States       " + (" · ".join(f"{BUCKETS[k]} {n}" for k, n in counts.most_common()) or "-"),
        ]
        if len(self.instances) > 1:
            per_instance = Counter(inst.name for inst, _ in scope)
            lines.append("  Instances    " + (" · ".join(f"{k} {n}" for k, n in per_instance.most_common()) or "-"))

        def top_table(title, keyfn, limit=12):
            groups = {}
            for t in torrents:
                group = groups.setdefault(keyfn(t), [0, 0, 0])
                group[0] += 1
                group[1] += t.get("size", 0) or 0
                group[2] += t.get("uploaded", 0) or 0
            out = ["", (f"{title}  (by size)", head),
                   (f"  {'':<40} {'Torrents':>8} {'Size':>10} {'Uploaded':>10}", curses.A_BOLD)]
            for name, (n, sz, up) in sorted(groups.items(), key=lambda kv: -kv[1][1])[:limit]:
                out.append(f"  {fit(name, 40)} {n:>8} {fmt_size(sz):>10} {fmt_size(up):>10}")
            if len(groups) > limit:
                out.append((f"  … and {len(groups) - limit} more", th["dim"]))
            return out

        if torrents:
            lines += top_table("CATEGORIES", lambda t: t.get("category") or "(uncategorized)")
            lines += top_table("TRACKERS", lambda t: urllib.parse.urlsplit(t.get("tracker") or "").hostname or "(no working tracker)")
            lines += top_table("SAVE PATHS", lambda t: t.get("save_path") or "?")

        seen = {}
        for inst, t in self.index.values():
            seen.setdefault(t["hash"], []).append((inst, t))
        duplicates = [entries for entries in seen.values() if len(entries) > 1]
        lines += ["", (f"ON MORE THAN ONE INSTANCE ({len(duplicates)})", head)]
        for entries in sorted(duplicates, key=lambda e: e[0][1].get("name", ""))[:50]:
            names = ", ".join(inst.name for inst, _ in entries)
            lines.append([("  " + fit(names, 24) + " ", th["yellow"]), (entries[0][1].get("name", ""), 0)])
        if not duplicates:
            lines.append(("  none", th["dim"]))
        return lines

    def describe_view(self):
        parts = []
        if self.inst_filter:
            parts.append(f"instance {self.inst_filter}")
        if self.state_filter != "all":
            parts.append(STATE_FILTERS[self.state_filter][0].lower())
        if self.cat_filter is not None:
            parts.append(f"category {self.describe_filter(self.cat_filter, 'uncategorized')}")
        if self.tag_filter is not None:
            parts.append(f"tag {self.describe_filter(self.tag_filter, 'untagged')}")
        if self.search:
            parts.append(f'search "{self.search}"')
        return ", ".join(parts)


# ----------------------------------------------------------------------------
# Configuration and entry point
# ----------------------------------------------------------------------------


def deep_merge(base, extra):
    merged = dict(base)
    for key, value in extra.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = value
    return merged


def config_files(explicit):
    chosen = explicit or os.environ.get("QBT_TUI_CONFIG")
    if chosen:
        return [Path(chosen).expanduser()], True
    config_home = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    return [SYSTEM_CONFIG, config_home / "qbt-tui" / "config.toml"], False


def load_config(explicit=None):
    paths, required = config_files(explicit)
    config = {}
    for path in paths:
        try:
            with open(path, "rb") as f:
                config = deep_merge(config, tomllib.load(f))
        except FileNotFoundError:
            if required:
                raise SystemExit(f"qbt-tui: {path}: no such file") from None
        except (OSError, tomllib.TOMLDecodeError) as error:
            raise SystemExit(f"qbt-tui: {path}: {error}") from None
    return config


_secret_cache = {}


def read_secret(spec, key):
    if spec.get(key) is not None:
        return str(spec[key])
    if spec.get(f"{key}_file"):
        return Path(spec[f"{key}_file"]).expanduser().read_text().strip()
    command = spec.get(f"{key}_cmd")
    if command:
        if command not in _secret_cache:
            result = subprocess.run(command, shell=True, check=True, stdout=subprocess.PIPE, text=True)
            _secret_cache[command] = result.stdout.strip()
        return _secret_cache[command]
    return None


def normalize_url(url):
    url = url.strip().rstrip("/")
    return url if re.match(r"^https?://", url) else f"http://{url}"


def scan(target, timeout):
    """Find qBittorrent Web UIs on HOST:PORT or HOST:FIRST-LAST."""
    target = re.sub(r"^https?://", "", target)
    host, _, ports = target.rpartition(":")
    first, _, last = ports.partition("-")
    if not host or not first.isdigit() or (last and not last.isdigit()):
        raise SystemExit(f"qbt-tui: --scan expects HOST:PORT or HOST:FIRST-LAST, not {target!r}")
    found = []

    def probe(port):
        url = f"http://{host}:{port}"
        try:
            with urllib.request.urlopen(f"{url}/api/v2/app/version", timeout=timeout) as response:
                if response.read(32).startswith(b"v"):
                    found.append((port, url))
        except urllib.error.HTTPError as error:
            if error.code == 403 and error.read(32).strip() in (b"", b"Forbidden"):
                found.append((port, url))
        except NET_ERRORS:
            pass

    threads = [threading.Thread(target=probe, args=(p,)) for p in range(int(first), int(last or first) + 1)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    return [url for _, url in sorted(found)]


def build_instances(config, urls, scans):
    refresh = float(config.get("refresh", 2.0))
    timeout = float(config.get("timeout", 10.0))
    defaults = config.get("defaults") or {}
    specs = {}
    for name, spec in (config.get("instances") or {}).items():
        if not isinstance(spec, dict) or not spec.get("url"):
            raise SystemExit(f"qbt-tui: instance {name!r} needs a url")
        merged = {**defaults, **spec}
        # An instance's own secret, in any form, replaces every form of it from defaults.
        for key in ("password", "api_key"):
            forms = (key, f"{key}_file", f"{key}_cmd")
            if any(form in spec for form in forms):
                merged.update({form: spec.get(form) for form in forms})
        if merged.get("enabled", True):
            specs[name] = merged
    configured = {normalize_url(s["url"]) for s in specs.values()}
    extra = [normalize_url(u) for u in urls]
    for target in scans:
        extra += scan(target, min(timeout, 2.0))
    for url in extra:
        if url not in configured:
            configured.add(url)
            specs[urllib.parse.urlsplit(url).netloc] = {**defaults, "url": url}

    instances = []
    for name, spec in specs.items():
        try:
            password = read_secret(spec, "password")
            api_key = read_secret(spec, "api_key")
        except (OSError, subprocess.CalledProcessError) as error:
            raise SystemExit(f"qbt-tui: instance {name!r}: cannot read secret: {error}") from None
        url = normalize_url(spec["url"])
        client = Client(url, username=spec.get("username"), password=password, api_key=api_key, timeout=timeout)
        instances.append(Instance(name, url, client, refresh))
    return instances


def list_instances(instances):
    results = {}

    def probe(inst):
        try:
            version = inst.client.connect()
            data = inst.client.maindata(0)
            torrents = (data.get("torrents") or {}).values()
            server = data.get("server_state") or {}
            results[inst.name] = (
                "online", clean(version), str(len(torrents)), fmt_size(sum(t.get("size", 0) or 0 for t in torrents)),
                f"{fmt_size(server.get('dl_info_speed', 0))}/s", f"{fmt_size(server.get('up_info_speed', 0))}/s",
            )
        except AuthError as error:
            results[inst.name] = ("auth", clean(describe_error(error)))
        except Exception as error:
            results[inst.name] = ("offline", clean(describe_error(error)))

    threads = [threading.Thread(target=probe, args=(inst,)) for inst in instances]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    name_w = max(8, *(len(i.name) for i in instances))
    url_w = max(3, *(len(i.url) for i in instances))
    print(f"{'INSTANCE':<{name_w}}  {'URL':<{url_w}}  {'STATUS':<8} {'VERSION':<9} {'TORRENTS':>8} {'SIZE':>10} {'DOWN':>12} {'UP':>12}")
    for inst in instances:
        status, *rest = results[inst.name]
        if status == "online":
            version, count, size, down, up = rest
            print(f"{inst.name:<{name_w}}  {inst.url:<{url_w}}  {status:<8} {version:<9} {count:>8} {size:>10} {down:>12} {up:>12}")
        else:
            print(f"{inst.name:<{name_w}}  {inst.url:<{url_w}}  {status:<8} {rest[0]}")
    return 0 if all(r[0] == "online" for r in results.values()) else 1


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="qbt-tui",
        description="Manage several qBittorrent instances from one terminal interface.",
        epilog="Configuration: /etc/qbt-tui/config.toml and ~/.config/qbt-tui/config.toml. "
        "Run --sample-config for the format.",
    )
    parser.add_argument("urls", nargs="*", metavar="URL", help="extra instance, for example http://10.1.1.12:8041")
    parser.add_argument("-c", "--config", metavar="FILE", help="read only this configuration file")
    parser.add_argument("--scan", action="append", default=[], metavar="HOST:PORTS",
                        help="probe ports for Web UIs, for example 10.1.1.12:8040-8060 (repeatable)")
    parser.add_argument("--list", action="store_true", help="print each instance's status and exit")
    parser.add_argument("--sample-config", action="store_true", help="print an example configuration and exit")
    parser.add_argument("--version", action="version", version=f"qbt-tui {VERSION}")
    args = parser.parse_args(argv)

    if args.sample_config:
        print(SAMPLE_CONFIG, end="")
        return 0
    instances = build_instances(load_config(args.config), args.urls, args.scan)
    if not instances:
        print(
            "qbt-tui: no instances configured. Add them to ~/.config/qbt-tui/config.toml\n"
            "(see --sample-config), pass URLs, or use --scan HOST:PORTS.",
            file=sys.stderr,
        )
        return 1
    if args.list:
        return list_instances(instances)
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        print("qbt-tui: the interface needs a terminal; use --list for a status table", file=sys.stderr)
        return 1

    locale.setlocale(locale.LC_ALL, "")
    if locale.getpreferredencoding(False).lower().replace("-", "") != "utf8":
        G.update(ASCII_GLYPHS)
    os.environ.setdefault("ESCDELAY", "25")
    state_home = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local" / "state")
    log_path = state_home / "qbt-tui" / "qbt-tui.log"

    # Unwind like Ctrl-C, so a closed terminal or kill still rolls back the running job.
    def exit_on_signal(signum, frame):
        raise SystemExit(128 + signum)

    for signum in (signal.SIGHUP, signal.SIGTERM):
        signal.signal(signum, exit_on_signal)
    curses.wrapper(lambda screen: App(screen, instances, log_path=log_path).run())
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
