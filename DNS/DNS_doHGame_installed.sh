#!/usr/bin/env bash
set -euo pipefail

# Fixed email
EMAIL="test@gmail.com"

# Ask for domain
read -rp "Enter your domain name (e.g., dns.example.com): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
  echo "Domain cannot be empty!"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo)."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "[*] Updating system..."
apt-get update -y
apt-get upgrade -y

echo "[*] Installing dependencies..."
apt-get install -y curl wget unzip ufw jq sqlite3 ca-certificates gnupg lsb-release \
  nginx unbound certbot python3-certbot-nginx

# Node.js 18
if ! command -v node >/dev/null 2>&1; then
  echo "[*] Installing Node.js 18..."
  curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
  apt-get install -y nodejs build-essential
fi

# Create directories
install -d -o root -g root -m 755 /opt/gamedns
install -d -o www-data -g www-data -m 750 /opt/gamedns/auth
install -d -o root -g root -m 755 /opt/gamedns/bin
install -d -o root -g root -m 755 /var/log/gamedns

#############################################
# UNBOUND CONFIG
#############################################
echo "[*] Configuring Unbound..."
cat >/etc/unbound/unbound.conf.d/gamedns.conf <<'UNBOUND'
server:
  verbosity: 0
  num-threads: 2
  interface: 127.0.0.1
  port: 53
  do-ip4: yes
  do-ip6: no
  do-udp: yes
  do-tcp: yes
  prefetch: yes
  prefetch-key: yes
  cache-min-ttl: 60
  cache-max-ttl: 86400
  so-reuseport: yes
  harden-dnssec-stripped: yes
  rrset-cache-size: 256m
  msg-cache-size: 128m
  outgoing-num-tcp: 64
  incoming-num-tcp: 64
  unwanted-reply-threshold: 10000
  hide-identity: yes
  hide-version: yes

include: "/etc/unbound/root.hints"
UNBOUND

curl -sS https://www.internic.net/domain/named.root -o /etc/unbound/root.hints
chown unbound:unbound /etc/unbound/root.hints || true
systemctl enable unbound
systemctl restart unbound

#############################################
# DOH SERVER (m13253/dns-over-https)
#############################################
echo "[*] Installing DoH server..."
DOH_VER="2.2.5"
cd /opt/gamedns/bin
if [[ ! -f doh-server ]]; then
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64) ASSET="linux-amd64";;
    aarch64|arm64) ASSET="linux-arm64";;
    *) echo "Unsupported arch: $ARCH"; exit 1;;
  esac
  wget -q https://github.com/m13253/dns-over-https/releases/download/v${DOH_VER}/doh-server-v${DOH_VER}-${ASSET}.tar.gz
  tar xzf doh-server-v${DOH_VER}-${ASSET}.tar.gz
  mv doh-server-v${DOH_VER}-${ASSET}/doh-server .
  chmod +x doh-server
  rm -rf doh-server-v${DOH_VER}-${ASSET}*
fi

cat >/etc/systemd/system/doh-server.service <<'SERVICE'
[Unit]
Description=DNS-over-HTTPS Server
After=network-online.target unbound.service
Wants=network-online.target

[Service]
User=www-data
Group=www-data
ExecStart=/opt/gamedns/bin/doh-server -udp 127.0.0.1:5353 -tcp 127.0.0.1:5353 -dns 127.0.0.1:53 -path /dns-query -http 127.0.0.1:8053
Restart=on-failure
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
WorkingDirectory=/opt/gamedns

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable doh-server
systemctl restart doh-server

#############################################
# NODE.JS AUTH SERVICE
#############################################
echo "[*] Creating auth service..."
cat >/opt/gamedns/auth/package.json <<'PKG'
{
  "name": "gamedns-auth",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "main": "server.js",
  "dependencies": {
    "better-sqlite3": "^11.5.0",
    "express": "^4.19.2",
    "morgan": "^1.10.0",
    "nanoid": "^5.0.7"
  }
}
PKG

cat >/opt/gamedns/auth/server.js <<'JS'
import express from "express";
import morgan from "morgan";
import Database from "better-sqlite3";
import crypto from "crypto";
import { nanoid } from "nanoid";

const PORT = process.env.AUTH_PORT || 8787;
const BIND = process.env.AUTH_BIND || "127.0.0.1";
const DB_PATH = process.env.DB_PATH || "/opt/gamedns/auth/keys.db";
const LOCK_BY = process.env.LOCK_BY || "ip_ua"; // ip or ip_ua

const app = express();
app.use(express.json());
app.use(morgan("combined"));

const db = new Database(DB_PATH);
db.pragma("journal_mode = WAL");
db.exec(`
CREATE TABLE IF NOT EXISTS keys (
  key TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL,
  expires_at INTEGER,
  bound_ip TEXT,
  bound_ua_hash TEXT,
  active INTEGER NOT NULL DEFAULT 1,
  note TEXT
);
`);

function uaHash(ua) {
  return crypto.createHash("sha256").update(ua || "").digest("hex").slice(0, 16);
}

function clientIP(req) {
  const xff = (req.headers["x-forwarded-for"] || "").split(",")[0].trim();
  return xff || req.socket.remoteAddress || "";
}

const stmtCreate = db.prepare(`INSERT INTO keys (key, created_at, expires_at, note) VALUES (?, ?, ?, ?);`);
const stmtGet = db.prepare(`SELECT * FROM keys WHERE key = ?;`);
const stmtBind = db.prepare(`UPDATE keys SET bound_ip = ?, bound_ua_hash = ? WHERE key = ?;`);

app.post("/keys", (req, res) => {
  const { expires_in_hours = 0, note = "" } = req.body || {};
  const key = nanoid(28);
  const now = Date.now();
  const expires_at = expires_in_hours > 0 ? now + expires_in_hours * 3600 * 1000 : null;
  stmtCreate.run(key, Math.floor(now / 1000), expires_at ? Math.floor(expires_at / 1000) : null, note);
  res.json({
    ok: true,
    key,
    url: `https://${process.env.DOMAIN}/dns-query?key=${key}`,
    expires_at
  });
});

app.get("/auth", (req, res) => {
  const key = (req.query.key || "").trim();
  if (!key) return res.status(401).send("missing key");

  const row = stmtGet.get(key);
  if (!row || row.active !== 1) return res.status(403).send("invalid key");

  const ip = clientIP(req);
  const agentHash = uaHash(req.headers["user-agent"] || "");

  if (!row.bound_ip && !row.bound_ua_hash) {
    const ua_to_bind = (LOCK_BY === "ip_ua") ? agentHash : null;
    stmtBind.run(ip, ua_to_bind, key);
  } else {
    if (row.bound_ip && row.bound_ip !== ip) return res.status(403).send("key locked to different IP");
    if (LOCK_BY === "ip_ua" && row.bound_ua_hash && row.bound_ua_hash !== agentHash) {
      return res.status(403).send("key locked to different device");
    }
  }

  return res.status(200).send("ok");
});

app.listen(PORT, BIND, () => {
  console.log(`Auth listening on http://${BIND}:${PORT}`);
});
JS

cat >/opt/gamedns/auth/.env <<ENV
DOMAIN=${DOMAIN}
AUTH_PORT=8787
AUTH_BIND=127.0.0.1
DB_PATH=/opt/gamedns/auth/keys.db
LOCK_BY=ip_ua
ENV

cd /opt/gamedns/auth
npm install --omit=dev

cat >/etc/systemd/system/gamedns-auth.service <<'SERVICE'
[Unit]
Description=GameDNS Auth (token gate for DoH)
After=network-online.target
Wants=network-online.target

[Service]
EnvironmentFile=/opt/gamedns/auth/.env
WorkingDirectory=/opt/gamedns/auth
ExecStart=/usr/bin/node server.js
Restart=on-failure
User=www-data
Group=www-data
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable gamedns-auth
systemctl restart gamedns-auth

#############################################
# NGINX CONFIG
#############################################
echo "[*] Configuring Nginx..."
cat >/etc/nginx/sites-available/gamedns.conf <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    location /.well-known/acme-challenge/ { root /var/www/html; }
    location / { return 301 https://\$host\$request_uri; }
}
NGINX

ln -sf /etc/nginx/sites-available/gamedns.conf /etc/nginx/sites-enabled/gamedns.conf
nginx -t && systemctl reload nginx

echo "[*] Obtaining Let's Encrypt certificate..."
certbot --nginx -d "${DOMAIN}" -m "${EMAIL}" --agree-tos --no-eff-email -n

cat >/etc/nginx/sites-available/gamedns_tls.conf <<NGINX
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.3;

    location = /__auth__ {
        internal;
        proxy_pass http://127.0.0.1:8787/auth$is_args$args;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header Host $host;
    }

    location = /dns-query {
        auth_request /__auth__;
        error_page 401 403 = @auth_error;
        proxy_pass http://127.0.0.1:8053/dns-query;
        proxy_set_header Host $host;
        proxy_http_version 1.1;
        proxy_buffering off;
    }

    location @auth_error {
        return 403 "Forbidden or invalid key\n";
    }

    location = /healthz { return 200 "ok\n"; }
}
NGINX

ln -sf /etc/nginx/sites-available/gamedns_tls.conf /etc/nginx/sites-enabled/gamedns_tls.conf
nginx -t && systemctl reload nginx

#############################################
# FIREWALL
#############################################
echo "[*] Configuring UFW..."
ufw allow 22/tcp || true
ufw allow 80/tcp || true
ufw allow 443/tcp || true
ufw --force enable

echo
echo "=============================="
echo " GameDNS is installed."
echo " DoH URL template:"
echo "   https://${DOMAIN}/dns-query?key=YOUR_TOKEN"
echo
echo "Create keys manually:"
echo "   curl -s -X POST http://127.0.0.1:8787/keys -H 'Content-Type: application/json' -d '{\"expires_in_hours\":72, \"note\":\"test\"}' | jq"
echo
echo "=============================="



# bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/DNS/DNS_doHGame_installed.sh)
