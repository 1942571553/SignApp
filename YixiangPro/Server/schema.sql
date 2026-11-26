CREATE TABLE cards (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT UNIQUE NOT NULL,
  source_id INTEGER NOT NULL,
  days INTEGER NOT NULL DEFAULT 30,
  max_devices INTEGER NOT NULL DEFAULT 1,
  used_count INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  created_at INTEGER NOT NULL
);

CREATE TABLE devices (
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

CREATE TABLE installs (
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

CREATE TABLE logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  level TEXT,
  action TEXT,
  detail TEXT,
  created_at INTEGER NOT NULL
);

CREATE TABLE redemptions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  card_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  device_id TEXT,
  source_id INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE sessions (
  token TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);

CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT
);

CREATE TABLE sources (
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

CREATE TABLE sqlite_sequence(name,seq);

CREATE TABLE users (
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
