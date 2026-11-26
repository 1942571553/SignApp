#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
艺祥签服务端 v2
- Python 3.6+ 标准库 + SQLite，无第三方依赖
- 客户端配置、用户注册/登录、设备、软件源、卡密、时间锁、安装包分发
- 管理后台 /admin
"""
import base64
import hashlib
import hmac
import html
import io
import json
import mimetypes
import os
import plistlib
import random
import re
import secrets
import shutil
import sqlite3
import string
import sys
import time
import traceback
import urllib.parse
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DATA = Path(os.environ.get("YIXIANG_DATA", ROOT / "data"))
DB_PATH = Path(os.environ.get("YIXIANG_DB", DATA / "yixiang.db"))
INSTALL_DIR = DATA / "installs"
UPLOAD_DIR = DATA / "uploads"
TMP_DIR = DATA / "tmp"
PORT = int(os.environ.get("YIXIANG_PORT", "8091"))
BASE_URL = os.environ.get("YIXIANG_BASE_URL", "https://sign.yixsc.cn").rstrip("/")
DEFAULT_ADMIN_PASSWORD = os.environ.get("YIXIANG_ADMIN_PASSWORD", "yixiang2026")
SESSION_SECRET = os.environ.get("YIXIANG_SECRET", "")
SERVER_VERSION = "2.0.0"

for folder in (DATA, INSTALL_DIR, UPLOAD_DIR, TMP_DIR):
    folder.mkdir(parents=True, exist_ok=True)

SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  salt TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'user',
  status TEXT NOT NULL DEFAULT 'active',
  expires_at INTEGER,
  created_at INTEGER NOT NULL,
  last_login INTEGER
);
CREATE TABLE IF NOT EXISTS sessions (
  token TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS devices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER,
  device_id TEXT NOT NULL,
  udid TEXT,
  name TEXT,
  model TEXT,
  ios TEXT,
  created_at INTEGER NOT NULL,
  last_seen INTEGER,
  UNIQUE(user_id, device_id)
);
CREATE TABLE IF NOT EXISTS sources (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  url TEXT NOT NULL UNIQUE,
  icon_url TEXT,
  description TEXT,
  requires_card INTEGER NOT NULL DEFAULT 0,
  price TEXT,
  time_start INTEGER,
  time_end INTEGER,
  enabled INTEGER NOT NULL DEFAULT 1,
  sort INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS cards (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT UNIQUE NOT NULL,
  source_id INTEGER NOT NULL,
  days INTEGER NOT NULL DEFAULT 30,
  max_devices INTEGER NOT NULL DEFAULT 1,
  used_count INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS redemptions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  card_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  device_id TEXT,
  source_id INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS installs (
  token TEXT PRIMARY KEY,
  user_id INTEGER,
  device_id TEXT,
  app_name TEXT NOT NULL,
  bundle_id TEXT NOT NULL,
  version TEXT,
  ipa_path TEXT NOT NULL,
  icon_path TEXT,
  size INTEGER,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT
);
CREATE TABLE IF NOT EXISTS logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  level TEXT,
  action TEXT,
  detail TEXT,
  created_at INTEGER NOT NULL
);
"""

DEFAULT_SETTINGS = {
    "brand_name": "艺祥签",
    "brand_subtitle": "iOS 签名与资源管理",
    "announcement": "欢迎使用艺祥签。签名在设备本地完成，证书不会上传服务器。",
    "support_url": "https://sign.yixsc.cn",
    "client_version": "2.0.0",
    "client_min_version": "2.0.0",
    "force_update": "0",
    "client_download_url": "",
    "allow_sign": "1",
    "allow_install": "1",
    "allow_store": "1",
    "allow_tools": "1",
    "registration_enabled": "1",
    "default_user_days": "30",
    "require_login_install": "1",
    "global_lock_start": "",
    "global_lock_end": "",
    "global_lock_reason": "服务端维护中，请稍后再试",
    "install_ttl_hours": "24",
    "theme_primary": "#7C4DFF",
    "theme_secondary": "#A855F7",
    "theme_accent": "#F472B6",
}


def now_ts():
    return int(time.time())


def fmt_time(ts):
    if not ts:
        return "—"
    return datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M")


def esc(value):
    return html.escape(str(value or ""), quote=True)


def db():
    conn = sqlite3.connect(str(DB_PATH), timeout=20)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = db()
    conn.executescript(SCHEMA)
    for key, value in DEFAULT_SETTINGS.items():
        conn.execute("INSERT OR IGNORE INTO settings (key,value) VALUES (?,?)", (key, value))
    admin = conn.execute("SELECT * FROM users WHERE username='admin'").fetchone()
    if not admin:
        salt = secrets.token_hex(16)
        pw = hash_password(DEFAULT_ADMIN_PASSWORD, salt)
        conn.execute(
            "INSERT INTO users (username,password_hash,salt,role,status,created_at) VALUES (?,?,?,?,?,?)",
            ("admin", pw, salt, "admin", "active", now_ts()),
        )
    conn.commit()
    conn.close()


def hash_password(password, salt):
    return hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), bytes.fromhex(salt), 120000).hex()


def verify_password(password, salt, expected):
    return hmac.compare_digest(hash_password(password, salt), expected)


def setting(conn, key, default=""):
    row = conn.execute("SELECT value FROM settings WHERE key=?", (key,)).fetchone()
    return row["value"] if row else default


def set_setting(conn, key, value):
    conn.execute("INSERT OR REPLACE INTO settings (key,value) VALUES (?,?)", (key, value))


def setting_bool(conn, key):
    return setting(conn, key, "0") == "1"


def log(conn, action, detail="", level="info"):
    try:
        conn.execute("INSERT INTO logs (level,action,detail,created_at) VALUES (?,?,?,?)", (level, action, detail, now_ts()))
        conn.commit()
    except Exception:
        pass


def parse_int(value, default=None):
    try:
        if value is None or value == "":
            return default
        return int(value)
    except Exception:
        return default


def parse_dt_local(value):
    """HTML datetime-local -> unix timestamp. Empty -> None."""
    if not value:
        return None
    value = value.strip().replace("T", " ")
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d"):
        try:
            dt = datetime.strptime(value, fmt)
            return int(time.mktime(dt.timetuple()))
        except ValueError:
            continue
    return None


def dt_local(ts):
    if not ts:
        return ""
    return datetime.fromtimestamp(ts).strftime("%Y-%m-%dT%H:%M")


def time_window(conn):
    start = parse_int(setting(conn, "global_lock_start"), 0) or 0
    end = parse_int(setting(conn, "global_lock_end"), 0) or 0
    active = bool(start or end) and not (start <= now_ts() <= end)
    return {
        "start": start or None,
        "end": end or None,
        "active": active,
        "reason": setting(conn, "global_lock_reason", "服务端维护中，请稍后再试") if active else "",
    }


def auth_user(handler, conn):
    token = ""
    header = handler.headers.get("Authorization", "")
    if header.startswith("Bearer "):
        token = header[7:].strip()
    if not token:
        token = handler.headers.get("X-Auth-Token", "")
    if not token:
        return None
    row = conn.execute(
        "SELECT u.* FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token=? AND s.expires_at>?",
        (token, now_ts()),
    ).fetchone()
    if not row:
        return None
    return dict(row)


def issue_token(conn, user_id):
    token = secrets.token_urlsafe(32)
    conn.execute(
        "INSERT INTO sessions (token,user_id,created_at,expires_at) VALUES (?,?,?,?)",
        (token, user_id, now_ts(), now_ts() + 30 * 86400),
    )
    return token


def user_json(user):
    if not user:
        return None
    return {
        "id": user["id"],
        "username": user["username"],
        "role": user.get("role", "user"),
        "status": user.get("status", "active"),
        "expiresAt": user.get("expires_at"),
        "createdAt": user.get("created_at"),
    }


def source_unlocked(conn, source, user, device_id):
    if not source["requires_card"]:
        return True
    if not user:
        return False
    row = conn.execute(
        "SELECT * FROM redemptions WHERE user_id=? AND source_id=? AND expires_at>? ORDER BY expires_at DESC LIMIT 1",
        (user["id"], source["id"], now_ts()),
    ).fetchone()
    if not row:
        return False
    return True


def source_json(conn, source, user, device_id):
    unlocked = source_unlocked(conn, source, user, device_id)
    return {
        "id": str(source["id"]),
        "name": source["name"],
        "url": source["url"],
        "iconURL": source["icon_url"] or "",
        "description": source["description"] or "",
        "requiresCard": bool(source["requires_card"]),
        "price": source["price"] or "",
        "timeStart": source["time_start"],
        "timeEnd": source["time_end"],
        "unlocked": unlocked,
        "expiresAt": None,
        "sort": source["sort"],
    }


def build_config(conn, user, device_id=""):
    rows = conn.execute("SELECT * FROM sources WHERE enabled=1 ORDER BY sort ASC, id ASC").fetchall()
    lock = time_window(conn)
    user_expired = bool(user and user.get("expires_at") and user["expires_at"] < now_ts())
    if user_expired:
        lock = {"start": None, "end": None, "active": True, "reason": "账号授权已到期，请联系管理员续期"}
    return {
        "ok": True,
        "brand": {
            "name": setting(conn, "brand_name", "艺祥签"),
            "subtitle": setting(conn, "brand_subtitle", "iOS 签名与资源管理"),
            "announcement": setting(conn, "announcement", ""),
            "supportURL": setting(conn, "support_url", BASE_URL),
        },
        "client": {
            "allowSign": setting_bool(conn, "allow_sign"),
            "allowInstall": setting_bool(conn, "allow_install"),
            "allowStore": setting_bool(conn, "allow_store"),
            "allowTools": setting_bool(conn, "allow_tools"),
            "forceUpdate": setting_bool(conn, "force_update"),
            "minVersion": setting(conn, "client_min_version", SERVER_VERSION),
            "version": setting(conn, "client_version", SERVER_VERSION),
            "downloadURL": setting(conn, "client_download_url", ""),
        },
        "announcement": setting(conn, "announcement", ""),
        "serverTime": now_ts(),
        "defaultSources": [source_json(conn, row, user, device_id) for row in rows],
        "timeLock": lock,
        "user": user_json(user),
        "features": {
            "store": setting_bool(conn, "allow_store"),
            "signing": setting_bool(conn, "allow_sign"),
            "install": setting_bool(conn, "allow_install"),
            "tools": setting_bool(conn, "allow_tools"),
        },
    }


def make_manifest(token, app_name, bundle_id, version):
    base = BASE_URL + "/api/install/" + token
    plist = {
        "items": [{
            "assets": [
                {"kind": "software-package", "url": base + "/app.ipa"},
                {"kind": "display-image", "url": base + "/icon.png"},
                {"kind": "full-size-image", "url": base + "/icon.png"},
            ],
            "metadata": {
                "bundle-identifier": bundle_id,
                "bundle-version": version or "1.0",
                "kind": "software",
                "title": app_name,
            },
        }]
    }
    return plistlib.dumps(plist, fmt=plistlib.FMT_XML)


def extract_icon(ipa_path, token):
    """Best effort extract app icon from IPA."""
    try:
        import zipfile
        with zipfile.ZipFile(ipa_path) as zf:
            names = [n for n in zf.namelist() if n.startswith("Payload/") and n.endswith(".app/") is False]
            candidates = [n for n in names if re.search(r"AppIcon.*\.png$", n, re.I)]
            if not candidates:
                candidates = [n for n in names if n.lower().endswith(".png") and "appicon" in n.lower()]
            if candidates:
                data = zf.read(candidates[0])
                path = INSTALL_DIR / (token + ".png")
                path.write_bytes(data)
                return path
    except Exception:
        pass
    # 1x1 transparent png fallback
    png = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")
    path = INSTALL_DIR / (token + ".png")
    path.write_bytes(png)
    return path


def cleanup_installs(conn):
    ttl = parse_int(setting(conn, "install_ttl_hours", "24"), 24) * 3600
    cutoff = now_ts() - ttl
    rows = conn.execute("SELECT token, ipa_path, icon_path FROM installs WHERE created_at < ?", (cutoff,)).fetchall()
    for row in rows:
        for field in ("ipa_path", "icon_path"):
            try:
                if row[field] and Path(row[field]).exists():
                    Path(row[field]).unlink()
            except Exception:
                pass
        conn.execute("DELETE FROM installs WHERE token=?", (row["token"],))
    if rows:
        conn.commit()


class Handler(BaseHTTPRequestHandler):
    server_version = "YixiangServer/2.0"
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stdout.write("[%s] %s\n" % (datetime.now().strftime("%H:%M:%S"), fmt % args))

    # ---------- response helpers ----------
    def send_json(self, payload, status=200, extra_headers=None):
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        if extra_headers:
            for k, v in extra_headers.items():
                self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)

    def send_bytes(self, data, content_type="application/octet-stream", status=200, filename=None, extra_headers=None):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        if filename:
            self.send_header("Content-Disposition", 'attachment; filename="%s"' % filename)
        if extra_headers:
            for k, v in extra_headers.items():
                self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)

    def redirect(self, location, status=302):
        self.send_response(status)
        self.send_header("Location", location)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def read_json(self):
        length = int(self.headers.get("Content-Length", "0") or 0)
        if length <= 0:
            return {}
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except Exception:
            return {}

    def read_form(self):
        length = int(self.headers.get("Content-Length", "0") or 0)
        if length <= 0:
            return {}
        raw = self.rfile.read(length).decode("utf-8", "replace")
        return {k: v[0] for k, v in urllib.parse.parse_qs(raw, keep_blank_values=True).items()}

    def cookie_value(self, name):
        raw = self.headers.get("Cookie", "")
        for part in raw.split(";"):
            if "=" in part:
                k, v = part.strip().split("=", 1)
                if k == name:
                    return v
        return ""

    def current_admin(self, conn):
        token = self.cookie_value("yixiang_admin")
        if not token:
            return None
        row = conn.execute(
            "SELECT u.* FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token=? AND s.expires_at>? AND u.role='admin'",
            (token, now_ts()),
        ).fetchone()
        return dict(row) if row else None

    def require_admin(self, conn):
        admin = self.current_admin(conn)
        if not admin:
            self.redirect("/admin/login")
            return None
        return admin

    def client_device(self):
        return self.headers.get("X-Device-ID", "").strip()

    # ---------- GET ----------
    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = {k: v[0] for k, v in urllib.parse.parse_qs(parsed.query, keep_blank_values=True).items()}
        conn = db()
        try:
            cleanup_installs(conn)
            if path == "/api/health":
                self.send_json({"ok": True, "version": SERVER_VERSION, "time": now_ts()})
            elif path == "/api/client/config":
                user = auth_user(self, conn)
                self.send_json(build_config(conn, user, self.client_device()))
            elif path == "/api/auth/me":
                user = auth_user(self, conn)
                if not user:
                    self.send_json({"ok": False, "message": "未登录"}, 401)
                else:
                    self.send_json({"ok": True, "user": user_json(user)})
            elif path == "/api/sources":
                user = auth_user(self, conn)
                rows = conn.execute("SELECT * FROM sources WHERE enabled=1 ORDER BY sort,id").fetchall()
                self.send_json({"ok": True, "sources": [source_json(conn, r, user, self.client_device()) for r in rows]})
            elif path.startswith("/api/install/") and path.endswith("/manifest.plist"):
                token = path.split("/")[3]
                row = conn.execute("SELECT * FROM installs WHERE token=?", (token,)).fetchone()
                if not row:
                    self.send_json({"ok": False, "message": "安装包不存在或已过期"}, 404); return
                data = make_manifest(token, row["app_name"], row["bundle_id"], row["version"])
                self.send_bytes(data, "text/xml; charset=utf-8")
            elif path.startswith("/api/install/") and path.endswith("/app.ipa"):
                token = path.split("/")[3]
                row = conn.execute("SELECT * FROM installs WHERE token=?", (token,)).fetchone()
                if not row or not Path(row["ipa_path"]).exists():
                    self.send_json({"ok": False, "message": "安装包不存在或已过期"}, 404); return
                data = Path(row["ipa_path"]).read_bytes()
                self.send_bytes(data, "application/octet-stream", filename="app.ipa")
            elif path.startswith("/api/install/") and path.endswith("/icon.png"):
                token = path.split("/")[3]
                row = conn.execute("SELECT * FROM installs WHERE token=?", (token,)).fetchone()
                icon = Path(row["icon_path"]) if row and row["icon_path"] else None
                if icon and icon.exists():
                    self.send_bytes(icon.read_bytes(), "image/png")
                else:
                    self.send_bytes(b"", "image/png", 404)
            elif path.startswith("/api/install/") and path.endswith("/install"):
                token = path.split("/")[3]
                row = conn.execute("SELECT * FROM installs WHERE token=?", (token,)).fetchone()
                if not row:
                    self.send_html("<h1>安装包不存在或已过期</h1>", 404); return
                page = install_page(row)
                self.send_html(page)
            elif path == "/api/udid/profile":
                device = query.get("device", "")
                self.send_bytes(udid_profile(device), "application/x-apple-aspen-config", filename="yixiang-udid.mobileconfig")
            elif path == "/api/udid/status":
                device = self.client_device() or query.get("device", "")
                row = conn.execute("SELECT * FROM devices WHERE device_id=? ORDER BY id DESC LIMIT 1", (device,)).fetchone()
                self.send_json({"ok": True, "udid": row["udid"] if row and row["udid"] else "", "deviceId": device})
            elif path == "/apple-app-site-association":
                self.send_json({
                    "applinks": {
                        "apps": [],
                        "details": [{"appID": "TEAMID.com.yixiangsign.app", "paths": ["/deeplink/*", "/install/*"]}]
                    }
                })
            elif path == "/admin/login":
                self.send_html(admin_login_page())
            elif path == "/admin":
                if self.require_admin(conn):
                    self.send_html(admin_dashboard(conn))
            elif path == "/admin/users":
                if self.require_admin(conn):
                    self.send_html(admin_users(conn))
            elif path == "/admin/sources":
                if self.require_admin(conn):
                    self.send_html(admin_sources(conn))
            elif path == "/admin/cards":
                if self.require_admin(conn):
                    self.send_html(admin_cards(conn))
            elif path == "/admin/settings":
                if self.require_admin(conn):
                    self.send_html(admin_settings(conn))
            elif path == "/admin/installs":
                if self.require_admin(conn):
                    self.send_html(admin_installs(conn))
            elif path == "/admin/logout":
                conn.execute("DELETE FROM sessions WHERE token=?", (self.cookie_value("yixiang_admin"),))
                conn.commit()
                self.redirect("/admin/login")
            elif path == "/":
                self.send_html("<html><body style='font-family:-apple-system;background:#f7f5ff;color:#1e1b2e;padding:40px'><h1>艺祥签服务端</h1><p>服务运行正常。</p><p><a href='/admin'>管理后台</a></p></body></html>")
            else:
                self.send_json({"ok": False, "message": "Not found"}, 404)
        except Exception as exc:
            traceback.print_exc()
            try:
                self.send_json({"ok": False, "message": "服务器错误: %s" % exc}, 500)
            except Exception:
                pass
        finally:
            conn.close()

    # ---------- POST ----------
    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        conn = db()
        try:
            if path == "/api/auth/register":
                self.handle_register(conn)
            elif path == "/api/auth/login":
                self.handle_login(conn)
            elif path == "/api/cards/redeem":
                self.handle_redeem(conn)
            elif path == "/api/device/register":
                self.handle_device(conn)
            elif path == "/api/install/upload":
                self.handle_upload(conn)
            elif path == "/api/udid/receive":
                self.handle_udid_receive(conn)
            elif path == "/admin/login":
                self.handle_admin_login(conn)
            elif path == "/admin/source/save":
                if self.require_admin(conn): self.handle_source_save(conn)
            elif path == "/admin/source/toggle":
                if self.require_admin(conn): self.handle_source_toggle(conn)
            elif path == "/admin/card/generate":
                if self.require_admin(conn): self.handle_card_generate(conn)
            elif path == "/admin/user/update":
                if self.require_admin(conn): self.handle_user_update(conn)
            elif path == "/admin/settings/save":
                if self.require_admin(conn): self.handle_settings_save(conn)
            else:
                self.send_json({"ok": False, "message": "Not found"}, 404)
        except Exception as exc:
            traceback.print_exc()
            try:
                self.send_json({"ok": False, "message": "服务器错误: %s" % exc}, 500)
            except Exception:
                pass
        finally:
            conn.close()

    def handle_register(self, conn):
        body = self.read_json()
        username = str(body.get("username", "")).strip()
        password = str(body.get("password", ""))
        if not re.match(r"^[a-zA-Z0-9_\u4e00-\u9fa5]{3,32}$", username):
            self.send_json({"ok": False, "message": "用户名需 3-32 位，字母/数字/下划线/中文"}, 400); return
        if len(password) < 6:
            self.send_json({"ok": False, "message": "密码至少 6 位"}, 400); return
        if not setting_bool(conn, "registration_enabled"):
            self.send_json({"ok": False, "message": "当前已关闭注册，请联系管理员"}, 403); return
        salt = secrets.token_hex(16)
        days = parse_int(setting(conn, "default_user_days", "30"), 30)
        expires = now_ts() + days * 86400 if days > 0 else None
        try:
            cur = conn.execute(
                "INSERT INTO users (username,password_hash,salt,role,status,expires_at,created_at) VALUES (?,?,?,?,?,?,?)",
                (username, hash_password(password, salt), salt, "user", "active", expires, now_ts()),
            )
            conn.commit()
        except sqlite3.IntegrityError:
            self.send_json({"ok": False, "message": "用户名已存在"}, 409); return
        user = dict(conn.execute("SELECT * FROM users WHERE id=?", (cur.lastrowid,)).fetchone())
        token = issue_token(conn, user["id"])
        conn.commit()
        log(conn, "register", username)
        self.send_json({"ok": True, "token": token, "user": user_json(user), "message": "注册成功"})

    def handle_login(self, conn):
        body = self.read_json()
        username = str(body.get("username", "")).strip()
        password = str(body.get("password", ""))
        row = conn.execute("SELECT * FROM users WHERE username=?", (username,)).fetchone()
        if not row or not verify_password(password, row["salt"], row["password_hash"]):
            self.send_json({"ok": False, "message": "用户名或密码错误"}, 401); return
        if row["status"] != "active":
            self.send_json({"ok": False, "message": "账号已被禁用"}, 403); return
        conn.execute("UPDATE users SET last_login=? WHERE id=?", (now_ts(), row["id"]))
        token = issue_token(conn, row["id"])
        conn.commit()
        user = dict(row)
        user["last_login"] = now_ts()
        self.send_json({"ok": True, "token": token, "user": user_json(user), "message": "登录成功"})

    def handle_device(self, conn):
        user = auth_user(self, conn)
        if not user:
            self.send_json({"ok": False, "message": "请先登录"}, 401); return
        body = self.read_json()
        device_id = str(body.get("deviceId") or self.client_device() or "").strip()
        if not device_id:
            self.send_json({"ok": False, "message": "缺少设备标识"}, 400); return
        existing = conn.execute("SELECT * FROM devices WHERE user_id=? AND device_id=?", (user["id"], device_id)).fetchone()
        if existing:
            conn.execute("UPDATE devices SET name=?,model=?,ios=?,last_seen=? WHERE id=?", (body.get("name"), body.get("model"), body.get("ios"), now_ts(), existing["id"]))
        else:
            conn.execute("INSERT INTO devices (user_id,device_id,udid,name,model,ios,created_at,last_seen) VALUES (?,?,?,?,?,?,?,?)",
                         (user["id"], device_id, body.get("udid"), body.get("name"), body.get("model"), body.get("ios"), now_ts(), now_ts()))
        conn.commit()
        self.send_json({"ok": True, "message": "设备已登记"})

    def handle_redeem(self, conn):
        user = auth_user(self, conn)
        if not user:
            self.send_json({"ok": False, "message": "请先登录后再兑换卡密"}, 401); return
        body = self.read_json()
        code = str(body.get("code", "")).strip().upper()
        device_id = str(body.get("deviceId") or self.client_device() or "")
        card = conn.execute("SELECT * FROM cards WHERE code=?", (code,)).fetchone()
        if not card:
            self.send_json({"ok": False, "message": "卡密不存在"}, 404); return
        if card["status"] != "active":
            self.send_json({"ok": False, "message": "卡密已停用"}, 403); return
        existing = conn.execute(
            "SELECT * FROM redemptions WHERE card_id=? AND user_id=? AND device_id=? ORDER BY expires_at DESC LIMIT 1",
            (card["id"], user["id"], device_id),
        ).fetchone()
        if existing and existing["expires_at"] > now_ts():
            self.send_json({"ok": True, "sourceId": str(card["source_id"]), "expiresAt": existing["expires_at"], "message": "该设备已使用此卡密，无需重复兑换"})
            return
        count = conn.execute("SELECT COUNT(*) c FROM redemptions WHERE card_id=? AND user_id=?", (card["id"], user["id"])).fetchone()["c"]
        if card["max_devices"] and count >= card["max_devices"]:
            self.send_json({"ok": False, "message": "该卡密最多绑定 %d 台设备" % card["max_devices"]}, 403); return
        expires_at = now_ts() + max(1, card["days"]) * 86400
        conn.execute(
            "INSERT INTO redemptions (card_id,user_id,device_id,source_id,expires_at,created_at) VALUES (?,?,?,?,?,?)",
            (card["id"], user["id"], device_id, card["source_id"], expires_at, now_ts()),
        )
        conn.execute("UPDATE cards SET used_count=used_count+1 WHERE id=?", (card["id"],))
        conn.commit()
        log(conn, "redeem", "user=%s card=%s" % (user["username"], code))
        source = conn.execute("SELECT * FROM sources WHERE id=?", (card["source_id"],)).fetchone()
        self.send_json({"ok": True, "sourceId": str(card["source_id"]), "expiresAt": expires_at, "message": "解锁成功" + ("：%s" % source["name"] if source else "")})

    def handle_upload(self, conn):
        user = auth_user(self, conn)
        if setting_bool(conn, "require_login_install") and not user:
            self.send_json({"ok": False, "message": "请先登录后再安装"}, 401); return
        if user and user.get("expires_at") and user["expires_at"] < now_ts():
            self.send_json({"ok": False, "message": "账号授权已到期"}, 403); return
        lock = time_window(conn)
        if lock["active"]:
            self.send_json({"ok": False, "message": lock["reason"]}, 403); return
        if not setting_bool(conn, "allow_install"):
            self.send_json({"ok": False, "message": "服务端已关闭安装分发"}, 403); return
        length = int(self.headers.get("Content-Length", "0") or 0)
        if length <= 0:
            self.send_json({"ok": False, "message": "空安装包"}, 400); return
        if length > 800 * 1024 * 1024:
            self.send_json({"ok": False, "message": "安装包超过 800MB 限制"}, 413); return
        token = secrets.token_urlsafe(20)
        ipa_path = INSTALL_DIR / (token + ".ipa")
        app_name = self.headers.get("X-App-Name", "App")
        try:
            app_name = urllib.parse.unquote(app_name)
        except Exception:
            pass
        bundle_id = self.headers.get("X-Bundle-ID", "com.yixiang.unknown")
        version = self.headers.get("X-App-Version", "1.0")
        with open(ipa_path, "wb") as fh:
            remaining = length
            while remaining > 0:
                chunk = self.rfile.read(min(1024 * 1024, remaining))
                if not chunk:
                    break
                fh.write(chunk)
                remaining -= len(chunk)
        if ipa_path.stat().st_size == 0:
            if ipa_path.exists(): ipa_path.unlink()
            self.send_json({"ok": False, "message": "上传失败"}, 500); return
        icon_path = extract_icon(ipa_path, token)
        ttl = parse_int(setting(conn, "install_ttl_hours", "24"), 24) * 3600
        conn.execute(
            "INSERT INTO installs (token,user_id,device_id,app_name,bundle_id,version,ipa_path,icon_path,size,created_at,expires_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
            (token, user["id"] if user else None, self.client_device(), app_name, bundle_id, version, str(ipa_path), str(icon_path), ipa_path.stat().st_size, now_ts(), now_ts() + ttl),
        )
        conn.commit()
        log(conn, "install_upload", "%s %s %.1fMB" % (app_name, bundle_id, length / 1048576.0))
        self.send_json({
            "ok": True,
            "manifestURL": BASE_URL + "/api/install/" + token + "/manifest.plist",
            "pageURL": BASE_URL + "/api/install/" + token + "/install",
            "installToken": token,
            "message": "上传成功",
        })

    def handle_udid_receive(self, conn):
        # iOS posts a signed plist (application/pkcs7-signature) to Profile Service URL
        length = int(self.headers.get("Content-Length", "0") or 0)
        raw = self.rfile.read(length) if length else b""
        udid = ""
        device_id = ""
        model = ""
        ios = ""
        try:
            data = plistlib.loads(raw)
            payload = data.get("Payload", data) if isinstance(data, dict) else {}
            udid = payload.get("UDID", "") or data.get("UDID", "")
            device_id = payload.get("DEVICE_ID", "") or data.get("DEVICE_ID", "") or ""
            model = payload.get("PRODUCT", "") or ""
            ios = payload.get("VERSION", "") or ""
        except Exception:
            text = raw.decode("utf-8", "replace")
            m = re.search(r"<key>UDID</key>\s*<string>([^<]+)</string>", text)
            if m: udid = m.group(1)
        device = self.client_device() or device_id
        if device:
            row = conn.execute("SELECT * FROM devices WHERE device_id=? ORDER BY id DESC LIMIT 1", (device,)).fetchone()
            if row:
                conn.execute("UPDATE devices SET udid=?, model=COALESCE(NULLIF(?,''), model), ios=COALESCE(NULLIF(?,''), ios), last_seen=? WHERE id=?", (udid, model, ios, now_ts(), row["id"]))
            else:
                conn.execute("INSERT INTO devices (device_id,udid,model,ios,created_at,last_seen) VALUES (?,?,?,?,?,?)", (device, udid, model, ios, now_ts(), now_ts()))
            conn.commit()
        log(conn, "udid", "%s %s" % (device, udid))
        self.send_html("<html><body style='font-family:-apple-system;padding:40px;text-align:center'><h2>UDID 已登记</h2><p>%s</p><p>请返回艺祥签 App 查询。</p></body></html>" % esc(udid))

    # ---------- admin handlers ----------
    def handle_admin_login(self, conn):
        form = self.read_form()
        username = form.get("username", "").strip()
        password = form.get("password", "")
        row = conn.execute("SELECT * FROM users WHERE username=? AND role='admin'", (username,)).fetchone()
        if not row or not verify_password(password, row["salt"], row["password_hash"]):
            self.send_html(admin_login_page("用户名或密码错误"), 401); return
        token = issue_token(conn, row["id"])
        conn.commit()
        self.send_response(302)
        self.send_header("Location", "/admin")
        self.send_header("Set-Cookie", "yixiang_admin=%s; Path=/; HttpOnly; Max-Age=2592000; SameSite=Lax" % token)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def handle_source_save(self, conn):
        form = self.read_form()
        sid = parse_int(form.get("id"))
        name = form.get("name", "").strip()
        url = form.get("url", "").strip()
        if not name or not url:
            self.send_html("<p>名称和地址不能为空</p>", 400); return
        fields = (
            name, url, form.get("icon_url", "").strip(), form.get("description", "").strip(),
            1 if form.get("requires_card") == "1" else 0, form.get("price", "").strip(),
            parse_dt_local(form.get("time_start", "")), parse_dt_local(form.get("time_end", "")),
            1 if form.get("enabled", "1") == "1" else 0, parse_int(form.get("sort"), 0) or 0,
        )
        if sid:
            conn.execute("UPDATE sources SET name=?,url=?,icon_url=?,description=?,requires_card=?,price=?,time_start=?,time_end=?,enabled=?,sort=? WHERE id=?", fields + (sid,))
        else:
            conn.execute("INSERT INTO sources (name,url,icon_url,description,requires_card,price,time_start,time_end,enabled,sort,created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)", fields + (now_ts(),))
        conn.commit()
        self.redirect("/admin/sources")

    def handle_source_toggle(self, conn):
        form = self.read_form()
        sid = parse_int(form.get("id"))
        if sid:
            row = conn.execute("SELECT enabled FROM sources WHERE id=?", (sid,)).fetchone()
            if row:
                conn.execute("UPDATE sources SET enabled=? WHERE id=?", (0 if row["enabled"] else 1, sid))
                conn.commit()
        self.redirect("/admin/sources")

    def handle_card_generate(self, conn):
        form = self.read_form()
        source_id = parse_int(form.get("source_id"))
        days = parse_int(form.get("days"), 30) or 30
        max_devices = parse_int(form.get("max_devices"), 1) or 1
        count = min(parse_int(form.get("count"), 5) or 5, 100)
        codes = []
        for _ in range(count):
            code = "YX-" + "".join(random.choice(string.ascii_uppercase + string.digits) for _ in range(4)) + "-" + "".join(random.choice(string.ascii_uppercase + string.digits) for _ in range(4))
            try:
                conn.execute("INSERT INTO cards (code,source_id,days,max_devices,used_count,status,created_at) VALUES (?,?,?,?,0,'active',?)", (code, source_id, days, max_devices, now_ts()))
                codes.append(code)
            except sqlite3.IntegrityError:
                continue
        conn.commit()
        log(conn, "card_generate", "%d for source %s" % (len(codes), source_id))
        self.send_html(admin_cards(conn, generated=codes))

    def handle_user_update(self, conn):
        form = self.read_form()
        uid = parse_int(form.get("id"))
        if uid:
            action = form.get("action")
            if action == "status":
                status = "disabled" if form.get("status") == "disabled" else "active"
                conn.execute("UPDATE users SET status=? WHERE id=?", (status, uid))
            elif action == "expire":
                expires = parse_dt_local(form.get("expires", ""))
                conn.execute("UPDATE users SET expires_at=? WHERE id=?", (expires, uid))
            elif action == "role":
                role = "admin" if form.get("role") == "admin" else "user"
                conn.execute("UPDATE users SET role=? WHERE id=?", (role, uid))
            conn.commit()
        self.redirect("/admin/users")

    def handle_settings_save(self, conn):
        form = self.read_form()
        keys = [
            "brand_name", "brand_subtitle", "announcement", "support_url", "client_version",
            "client_min_version", "client_download_url", "global_lock_reason", "install_ttl_hours",
            "default_user_days", "theme_primary", "theme_secondary", "theme_accent",
        ]
        for key in keys:
            if key in form:
                set_setting(conn, key, form.get(key, "").strip())
        for key in ["force_update", "allow_sign", "allow_install", "allow_store", "allow_tools", "registration_enabled", "require_login_install"]:
            set_setting(conn, key, "1" if form.get(key) == "1" else "0")
        set_setting(conn, "global_lock_start", str(parse_dt_local(form.get("global_lock_start", "")) or ""))
        set_setting(conn, "global_lock_end", str(parse_dt_local(form.get("global_lock_end", "")) or ""))
        conn.commit()
        self.redirect("/admin/settings")

    def send_html(self, content, status=200, headers=None):
        if not content.startswith("<!DOCTYPE"):
            content = "<!DOCTYPE html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>艺祥签</title>%s</head><body>%s</body></html>" % (ADMIN_CSS, content)
        data = content.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        if headers:
            for k, v in headers.items(): self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)


ADMIN_CSS = """
<style>
:root{--p:#7c4dff;--v:#a855f7;--pink:#f472b6;--bg:#f7f5ff;--text:#1e1b2e;--muted:#8b87a3;--card:#fff;--line:#ece7fb}
*{box-sizing:border-box}body{margin:0;background:var(--bg);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:var(--text)}
a{color:var(--p);text-decoration:none}.wrap{max-width:1180px;margin:0 auto;padding:24px}
.hero{background:linear-gradient(120deg,#6d5bff,#a855f7,#f472b6);color:#fff;border-radius:24px;padding:26px 28px;margin-bottom:20px}
.hero h1{margin:0 0 4px;font-size:26px}.hero p{margin:0;opacity:.8;font-size:13px}
.nav{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:18px}.nav a{background:#fff;border:1px solid var(--line);padding:9px 14px;border-radius:12px;font-size:13px;color:var(--text)}
.nav a:hover{border-color:#c9bdf5;color:var(--p)}
.card{background:#fff;border:1px solid var(--line);border-radius:18px;padding:18px;margin-bottom:16px;box-shadow:0 8px 26px rgba(90,60,180,.05)}
h2{font-size:18px;margin:0 0 12px}h3{font-size:14px;margin:0 0 10px;color:#5b5474}
table{width:100%;border-collapse:collapse;font-size:13px}th,td{padding:10px 8px;border-bottom:1px solid #f1eefb;text-align:left;vertical-align:top}
th{color:#6f6888;font-weight:600;font-size:12px}td.mono{font-family:ui-monospace,Menlo,monospace;font-size:11px;color:#5b5474}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px}
.stat{background:linear-gradient(135deg,#fff,#faf8ff);border:1px solid var(--line);border-radius:16px;padding:16px}
.stat b{display:block;font-size:26px;color:var(--p);margin-bottom:3px}.stat span{font-size:12px;color:var(--muted)}
label{display:block;font-size:12px;color:#6f6888;margin:9px 0 5px}
input,select,textarea{width:100%;padding:10px 11px;border:1px solid #e3ddf4;border-radius:10px;font:inherit;font-size:13px;background:#fbfaff;color:var(--text)}
input[type=checkbox]{width:auto;margin-right:6px}
button,.btn{display:inline-block;border:0;background:linear-gradient(120deg,#7c4dff,#a855f7);color:#fff;padding:10px 16px;border-radius:11px;font-size:13px;font-weight:600;cursor:pointer}
.btn.soft{background:#f0ebff;color:#6d4bd0}.btn.danger{background:#fee9e9;color:#d83a3a}
.two{display:grid;grid-template-columns:1fr 1fr;gap:12px}@media(max-width:700px){.two{grid-template-columns:1fr}}
.tag{display:inline-block;padding:3px 8px;border-radius:999px;font-size:10px;background:#eee8ff;color:#6d4bd0}
.tag.green{background:#e5f7ee;color:#147a4f}.tag.red{background:#fee9e9;color:#c73030}.tag.orange{background:#fff1da;color:#a86300}
.muted{color:var(--muted);font-size:12px}.row{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
.login{max-width:380px;margin:9vh auto;background:#fff;border:1px solid var(--line);border-radius:24px;padding:30px;box-shadow:0 20px 60px rgba(80,50,180,.1)}
.login h1{font-size:24px;margin:0 0 4px}.login p{color:var(--muted);font-size:12px;margin:0 0 18px}
footer{color:var(--muted);font-size:11px;text-align:center;padding:20px}
</style>
"""


def admin_nav(active=""):
    items = [("/admin", "仪表盘"), ("/admin/users", "用户"), ("/admin/sources", "软件源"), ("/admin/cards", "卡密"), ("/admin/settings", "设置"), ("/admin/installs", "安装包"), ("/admin/logout", "退出")]
    return "<div class='nav'>" + "".join("<a href='%s'%s>%s</a>" % (u, " style='background:#efe9ff;color:#6d4bd0'" if u == active else "", esc(t)) for u, t in items) + "</div>"


def admin_login_page(error=""):
    return """<!DOCTYPE html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>艺祥签管理后台</title>%s</head><body>
<div class='login'><h1>艺祥签</h1><p>服务端管理后台 · 用户 / 软件源 / 卡密 / 时间锁</p>
%s<form method='post' action='/admin/login'><label>管理员账号</label><input name='username' value='admin' autocomplete='username'><label>密码</label><input type='password' name='password' autocomplete='current-password'><button style='width:100%%;margin-top:16px'>登录后台</button></form>
<p style='margin-top:18px'>默认账号 admin，首次部署请立即修改密码。</p></div></body></html>""" % (ADMIN_CSS, ("<p style='color:#d83a3a'>%s</p>" % esc(error)) if error else "")


def admin_dashboard(conn):
    stats = {
        "users": conn.execute("SELECT COUNT(*) c FROM users WHERE role='user'").fetchone()["c"],
        "devices": conn.execute("SELECT COUNT(*) c FROM devices").fetchone()["c"],
        "sources": conn.execute("SELECT COUNT(*) c FROM sources WHERE enabled=1").fetchone()["c"],
        "cards": conn.execute("SELECT COUNT(*) c FROM cards").fetchone()["c"],
        "installs": conn.execute("SELECT COUNT(*) c FROM installs").fetchone()["c"],
    }
    lock = time_window(conn)
    recent = conn.execute("SELECT * FROM users ORDER BY id DESC LIMIT 8").fetchall()
    rows = "".join("<tr><td>%s</td><td>%s</td><td><span class='tag %s'>%s</span></td><td>%s</td></tr>" % (
        esc(u["username"]), ("管理员" if u["role"] == "admin" else "用户"),
        "green" if u["status"] == "active" else "red", esc(u["status"]), fmt_time(u["expires_at"] or 0)) for u in recent)
    return """<!DOCTYPE html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>仪表盘 · 艺祥签</title>%s</head><body><div class='wrap'>
<div class='hero'><h1>艺祥签服务端</h1><p>版本 %s · 用户注册、软件源、卡密与时间锁统一管理</p></div>
%s
<div class='card'><h2>运行概览</h2><div class='grid'>
<div class='stat'><b>%d</b><span>注册用户</span></div><div class='stat'><b>%d</b><span>登记设备</span></div><div class='stat'><b>%d</b><span>启用软件源</span></div><div class='stat'><b>%d</b><span>卡密总数</span></div><div class='stat'><b>%d</b><span>临时安装包</span></div>
</div><p class='muted' style='margin-top:14px'>全局时间锁：%s</p></div>
<div class='card'><h2>最近注册</h2><table><tr><th>用户名</th><th>角色</th><th>状态</th><th>授权到期</th></tr>%s</table><p style='margin-top:12px'><a class='btn soft' href='/admin/users'>管理用户</a></p></div>
<footer>艺祥签 · Python + SQLite 服务端</footer></div></body></html>""" % (ADMIN_CSS, SERVER_VERSION, admin_nav("/admin"), stats["users"], stats["devices"], stats["sources"], stats["cards"], stats["installs"],
    ("已开启：%s" % esc(lock["reason"])) if lock["active"] else "未开启", rows)


def admin_users(conn):
    users = conn.execute("SELECT * FROM users ORDER BY id DESC").fetchall()
    rows = ""
    for u in users:
        status = "active" if u["status"] == "active" else "disabled"
        rows += """<tr><td><b>%s</b><br><span class='muted'>ID %d · %s</span></td>
<td>%s</td><td><span class='tag %s'>%s</span></td><td>%s</td><td>
<form method='post' action='/admin/user/update' style='display:flex;gap:6px;flex-wrap:wrap'>
<input type='hidden' name='id' value='%d'><input type='hidden' name='action' value='status'><input type='hidden' name='status' value='%s'><button class='btn soft'>%s</button></form>
<form method='post' action='/admin/user/update' style='display:flex;gap:6px;margin-top:6px'><input type='hidden' name='id' value='%d'><input type='hidden' name='action' value='expire'><input type='datetime-local' name='expires' value='%s' style='width:190px;padding:6px 8px'><button class='btn soft'>改期</button></form>
</td></tr>""" % (esc(u["username"]), u["id"], fmt_time(u["created_at"]), "管理员" if u["role"] == "admin" else "用户",
        "green" if status == "active" else "red", status, fmt_time(u["expires_at"] or 0),
        u["id"], "disabled" if status == "active" else "active", "禁用" if status == "active" else "启用", u["id"], dt_local(u["expires_at"]))
    return """<!DOCTYPE html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>用户 · 艺祥签</title>%s</head><body><div class='wrap'>
<div class='hero'><h1>用户管理</h1><p>注册用户、设备与授权到期时间</p></div>%s
<div class='card'><h2>全部用户（%d）</h2><table><tr><th>用户</th><th>角色</th><th>状态</th><th>授权到期</th><th>操作</th></tr>%s</table></div>
<footer>修改授权时间后，客户端下次同步配置即刻生效</footer></div></body></html>""" % (ADMIN_CSS, admin_nav("/admin/users"), len(users), rows)


def admin_sources(conn):
    sources = conn.execute("SELECT * FROM sources ORDER BY sort,id").fetchall()
    rows = ""
    for s in sources:
        rows += """<tr><td><b>%s</b><br><span class='mono'>%s</span></td><td>%s</td><td>%s</td><td>%s</td><td><span class='tag %s'>%s</span></td><td>
<form method='post' action='/admin/source/toggle'><input type='hidden' name='id' value='%d'><button class='btn soft'>%s</button></form></td></tr>""" % (
            esc(s["name"]), esc(s["url"]), "需要卡密" if s["requires_card"] else "免费", esc(s["price"] or "—"),
            ("%s ~ %s" % (fmt_time(s["time_start"]), fmt_time(s["time_end"]))) if (s["time_start"] or s["time_end"]) else "不限时",
            "green" if s["enabled"] else "red", "启用中" if s["enabled"] else "已停用", s["id"], "停用" if s["enabled"] else "启用")
    return """<!DOCTYPE html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>软件源 · 艺祥签</title>%s</head><body><div class='wrap'>
<div class='hero'><h1>软件源管理</h1><p>服务端控制客户端默认软件源，支持卡密与时间窗口</p></div>%s
<div class='card'><h2>新增 / 编辑软件源</h2><form method='post' action='/admin/source/save'><div class='two'>
<div><label>源名称</label><input name='name' placeholder='例如：精选源'></div><div><label>源地址（AltStore JSON）</label><input name='url' placeholder='https://...'></div>
<div><label>图标地址（可选）</label><input name='icon_url'></div><div><label>解锁价格文字（可选）</label><input name='price' placeholder='例如 ¥9.9 / 30天'></div>
<div><label>开放开始（可选）</label><input type='datetime-local' name='time_start'></div><div><label>开放结束（可选）</label><input type='datetime-local' name='time_end'></div>
</div><label>描述</label><textarea name='description' rows='2'></textarea>
<div class='row' style='margin-top:10px'><label style='margin:0'><input type='checkbox' name='requires_card' value='1'> 需要卡密解锁</label><label style='margin:0'><input type='checkbox' name='enabled' value='1' checked> 启用</label><label style='margin:0'>排序 <input name='sort' value='0' style='width:70px;display:inline-block'></label></div>
<input type='hidden' name='id' value=''><button style='margin-top:14px'>保存软件源</button></form></div>
<div class='card'><h2>现有软件源（%d）</h2><table><tr><th>名称 / 地址</th><th>解锁</th><th>价格</th><th>开放时间</th><th>状态</th><th>操作</th></tr>%s</table></div>
<footer>客户端启动时会拉取 /api/client/config，默认源由这里控制</footer></div></body></html>""" % (ADMIN_CSS, admin_nav("/admin/sources"), len(sources), rows)


def admin_cards(conn, generated=None):
    cards = conn.execute("SELECT c.*, s.name source_name FROM cards c LEFT JOIN sources s ON s.id=c.source_id ORDER BY c.id DESC LIMIT 80").fetchall()
    sources = conn.execute("SELECT * FROM sources ORDER BY name").fetchall()
    options = "".join("<option value='%d'>%s</option>" % (s["id"], esc(s["name"])) for s in sources)
    rows = "".join("<tr><td class='mono'>%s</td><td>%s</td><td>%d 天</td><td>%d 台</td><td>%d</td><td><span class='tag %s'>%s</span></td></tr>" % (
        esc(c["code"]), esc(c["source_name"] or "—"), c["days"], c["max_devices"], c["used_count"],
        "green" if c["status"] == "active" else "red", esc(c["status"])) for c in cards)
    generated_html = ""
    if generated:
        generated_html = "<div class='card'><h2>新生成的卡密</h2><p class='mono'>%s</p></div>" % "<br>".join(esc(x) for x in generated)
    return """<!DOCTYPE html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>卡密 · 艺祥签</title>%s</head><body><div class='wrap'>
<div class='hero'><h1>卡密管理</h1><p>按软件源生成解锁卡，绑定用户与设备</p></div>%s%s
<div class='card'><h2>批量生成</h2><form method='post' action='/admin/card/generate'><div class='two'>
<div><label>绑定软件源</label><select name='source_id'>%s</select></div><div><label>有效天数</label><input name='days' type='number' value='30'></div>
<div><label>最多绑定设备</label><input name='max_devices' type='number' value='1'></div><div><label>生成数量</label><input name='count' type='number' value='5' max='100'></div>
</div><button style='margin-top:14px'>生成卡密</button></form></div>
<div class='card'><h2>最近卡密</h2><table><tr><th>卡密</th><th>软件源</th><th>有效</th><th>设备上限</th><th>已兑换</th><th>状态</th></tr>%s</table></div>
<footer>卡密在客户端“软件源解锁”页面输入</footer></div></body></html>""" % (ADMIN_CSS, admin_nav("/admin/cards"), generated_html, options, rows)


def admin_settings(conn):
    s = {row["key"]: row["value"] for row in conn.execute("SELECT * FROM settings").fetchall()}
    def checked(key): return "checked" if s.get(key) == "1" else ""
    return """<!DOCTYPE html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>设置 · 艺祥签</title>%s</head><body><div class='wrap'>
<div class='hero'><h1>服务端设置</h1><p>品牌、功能开关、全局时间锁与注册策略</p></div>%s
<form method='post' action='/admin/settings/save'>
<div class='card'><h2>品牌与公告</h2><div class='two'>
<div><label>品牌名</label><input name='brand_name' value='%s'></div><div><label>副标题</label><input name='brand_subtitle' value='%s'></div>
<div><label>客服 / 官网地址</label><input name='support_url' value='%s'></div><div><label>公告</label><input name='announcement' value='%s'></div>
</div></div>
<div class='card'><h2>客户端功能</h2><div class='grid'>
<label><input type='checkbox' name='allow_sign' value='1' %s> 允许签名</label><label><input type='checkbox' name='allow_install' value='1' %s> 允许安装分发</label>
<label><input type='checkbox' name='allow_store' value='1' %s> 允许软件源商店</label><label><input type='checkbox' name='allow_tools' value='1' %s> 允许工具页</label>
<label><input type='checkbox' name='registration_enabled' value='1' %s> 开放注册</label><label><input type='checkbox' name='require_login_install' value='1' %s> 安装必须登录</label>
<label><input type='checkbox' name='force_update' value='1' %s> 强制更新</label></div>
<div class='two' style='margin-top:12px'><div><label>最低客户端版本</label><input name='client_min_version' value='%s'></div><div><label>最新客户端版本</label><input name='client_version' value='%s'></div>
<div><label>新版下载地址</label><input name='client_download_url' value='%s'></div><div><label>新用户默认授权天数（0=不限）</label><input name='default_user_days' value='%s'></div></div></div>
<div class='card'><h2>全局时间锁</h2><p class='muted'>在开始到结束之间 App 可用；留空表示不开启。客户端和服务端都会校验。</p><div class='two'>
<div><label>开始</label><input type='datetime-local' name='global_lock_start' value='%s'></div><div><label>结束</label><input type='datetime-local' name='global_lock_end' value='%s'></div>
<div><label>锁定时提示</label><input name='global_lock_reason' value='%s'></div><div><label>安装包保留小时</label><input name='install_ttl_hours' value='%s'></div></div></div>
<div class='card'><h2>视觉</h2><div class='grid'><div><label>主色</label><input name='theme_primary' value='%s'></div><div><label>辅色</label><input name='theme_secondary' value='%s'></div><div><label>强调色</label><input name='theme_accent' value='%s'></div></div></div>
<button>保存全部设置</button></form><footer>设置保存后，客户端刷新配置即可生效</footer></div></body></html>""" % (
        ADMIN_CSS, admin_nav("/admin/settings"), esc(s.get("brand_name", "")), esc(s.get("brand_subtitle", "")), esc(s.get("support_url", "")), esc(s.get("announcement", "")),
        checked("allow_sign"), checked("allow_install"), checked("allow_store"), checked("allow_tools"), checked("registration_enabled"), checked("require_login_install"), checked("force_update"),
        esc(s.get("client_min_version", "")), esc(s.get("client_version", "")), esc(s.get("client_download_url", "")), esc(s.get("default_user_days", "")),
        dt_local(parse_int(s.get("global_lock_start"), 0)), dt_local(parse_int(s.get("global_lock_end"), 0)), esc(s.get("global_lock_reason", "")), esc(s.get("install_ttl_hours", "")),
        esc(s.get("theme_primary", "")), esc(s.get("theme_secondary", "")), esc(s.get("theme_accent", "")),
    )


def admin_installs(conn):
    rows = conn.execute("SELECT * FROM installs ORDER BY created_at DESC LIMIT 80").fetchall()
    trs = "".join("<tr><td>%s</td><td>%s</td><td class='mono'>%s</td><td>%s</td><td>%.1f MB</td><td>%s</td></tr>" % (
        esc(r["app_name"]), esc(r["bundle_id"]), esc(r["token"]), esc(r["version"]), (r["size"] or 0) / 1048576.0, fmt_time(r["created_at"])) for r in rows)
    return """<!DOCTYPE html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>安装包 · 艺祥签</title>%s</head><body><div class='wrap'>
<div class='hero'><h1>安装包分发</h1><p>已签名 IPA 上传后的临时安装记录</p></div>%s<div class='card'><h2>最近安装包</h2><table><tr><th>应用</th><th>Bundle ID</th><th>Token</th><th>版本</th><th>大小</th><th>上传时间</th></tr>%s</table></div>
<footer>超过保留时间的安装包会自动清理</footer></div></body></html>""" % (ADMIN_CSS, admin_nav("/admin/installs"), trs)


def install_page(row):
    token = row["token"]
    return """<!DOCTYPE html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>安装 %s</title>
<style>body{font-family:-apple-system;background:#f7f5ff;color:#1e1b2e;text-align:center;padding:50px 20px}.card{max-width:420px;margin:auto;background:#fff;border-radius:24px;padding:30px;box-shadow:0 18px 50px rgba(80,50,180,.1)}h1{font-size:22px}button{background:linear-gradient(120deg,#7c4dff,#a855f7);border:0;color:#fff;padding:14px 26px;border-radius:14px;font-size:16px;font-weight:600;margin-top:10px}</style></head><body>
<div class='card'><h1>%s</h1><p>%s · %s</p><a href='itms-services://?action=download-manifest&url=%s/api/install/%s/manifest.plist'><button>安装到 iPhone / iPad</button></a><p style='color:#8b87a3;font-size:12px;margin-top:18px'>请使用 Safari 打开本页。安装包为临时分发，过期后需重新上传。</p></div></body></html>""" % (
        esc(row["app_name"]), esc(row["app_name"]), esc(row["bundle_id"]), BASE_URL, token)


def udid_profile(device):
    payload = {
        "PayloadContent": {
            "URL": BASE_URL + "/api/udid/receive?device=" + urllib.parse.quote(device),
            "DeviceAttributes": ["UDID", "DEVICE_NAME", "PRODUCT", "VERSION", "IMEI", "SERIAL"],
            "PayloadDescription": "艺祥签设备 UDID 登记",
            "PayloadDisplayName": "艺祥签 UDID",
            "PayloadIdentifier": "com.yixiangsign.udid",
            "PayloadOrganization": "Yixiang",
            "PayloadType": "Profile Service",
            "PayloadUUID": secrets.token_hex(16).upper(),
            "PayloadVersion": 1,
        },
        "PayloadDescription": "安装后登记设备 UDID",
        "PayloadDisplayName": "艺祥签 UDID 登记",
        "PayloadIdentifier": "com.yixiangsign.udid.profile",
        "PayloadOrganization": "Yixiang",
        "PayloadRemovalDisallowed": False,
        "PayloadType": "Configuration",
        "PayloadUUID": secrets.token_hex(16).upper(),
        "PayloadVersion": 1,
    }
    return plistlib.dumps(payload, fmt=plistlib.FMT_XML)


def main():
    init_db()
    address = os.environ.get("YIXIANG_HOST", "127.0.0.1")
    server = ThreadingHTTPServer((address, PORT), Handler)
    print("Yixiang server listening on %s:%d, data=%s" % (address, PORT, DATA))
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
