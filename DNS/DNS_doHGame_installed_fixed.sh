#!/bin/bash
# Unbound DNS Manager (Debian/Ubuntu) - menu driven, multi-port.
# Edit this file with vi:   vi DNS_doHGame_installed_fixed.sh
#
# Usage:
#   sudo bash DNS_doHGame_installed_fixed.sh            -> interactive menu
#   sudo bash DNS_doHGame_installed_fixed.sh install    -> jump straight to full install
#   sudo bash DNS_doHGame_installed_fixed.sh status     -> show status and exit
#   sudo bash DNS_doHGame_installed_fixed.sh doh        -> install the DoH key server (nginx + Let's Encrypt)
#   sudo bash DNS_doHGame_installed_fixed.sh keys       -> open the key panel (create / remove / list keys)
#
# Non-interactive (skips the prompts):
#   DNS_PORTS="53,5300" ALLOWED_CLIENTS="203.0.113.0/24" sudo -E bash DNS_doHGame_installed_fixed.sh install
#
# Choices are saved in /etc/unbound/gamedns.settings and reused by the menu.
# DoH key server: per-customer URLs  https://<domain>:<port>/dns-query/<key>  (see menu option 7 and 8).
#
# NOTE: phones and consoles can only use plain DNS on port 53. Custom ports work for
# clients that let you set a port (dig -p, dnsmasq, some routers/apps).
set -euo pipefail

UNBOUND_CONF_DIR="/etc/unbound/unbound.conf.d"
UNBOUND_CONF_FILE="$UNBOUND_CONF_DIR/gamedns.conf"
SETTINGS_FILE="/etc/unbound/gamedns.settings"
ROOT_KEY="/var/lib/unbound/root.key"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || pwd)"

# Values from the environment (used instead of prompting when set)
ENV_PORTS="${DNS_PORTS:-}"
ENV_CLIENTS="${ALLOWED_CLIENTS:-}"

# Saved/working settings
PORTS=""
ALLOWED_CLIENTS=""
IP_RATELIMIT="${IP_RATELIMIT:-200}"
OLD_PORTS=""

# DoH key server settings (saved in the settings file)
DOH_ENABLED="0"
DOH_DOMAIN=""
DOH_EMAIL=""
DOH_PORT=""
ADMIN_PORT=""
ADMIN_ALLOW=""
OLD_DOH_PORT=""
OLD_ADMIN_PORT=""
OLD_ADMIN_ALLOW=""

GAMEDNS_DIR="/opt/gamedns"
GAMEDNS_PY="$GAMEDNS_DIR/gamedns_doh.py"
DOH_ENV="/etc/gamedns/doh.env"
DOH_DATA="/var/lib/gamedns"
DOH_SERVICE="gamedns-doh"
DOH_NGINX_CONF="/etc/nginx/conf.d/gamedns-doh.conf"
DOH_BACKEND_PORT=8053
ADMIN_BACKEND_PORT=8054

# -------------------------
# Helper functions
# -------------------------

# Usage: log "message"   -> prints a green [+] status line
log() { echo -e "\e[32m[+] $1\e[0m"; }

# Usage: warn "message"  -> prints a yellow [!] warning, does not exit
warn() { echo -e "\e[33m[!] $1\e[0m"; }

# Usage: error_exit "message" -> prints a red [!] error and exits with status 1
error_exit() { echo -e "\e[31m[!] $1\e[0m"; exit 1; }

# Usage: run_as_root   -> aborts unless the script is executed as root
run_as_root() { [[ $EUID -eq 0 ]] || error_exit "Run as root (sudo)."; }

# Usage: check_os   -> aborts unless apt-get is available (Debian/Ubuntu)
check_os() { command -v apt-get >/dev/null 2>&1 || error_exit "This script supports Debian/Ubuntu only."; }

# Usage: has_port <port>   -> returns 0 if <port> is in the current PORTS list
has_port() { [[ " $PORTS " == *" $1 "* ]]; }

# Usage: old_has_port <port>   -> returns 0 if <port> was in the previously saved PORTS list
old_has_port() { [[ " $OLD_PORTS " == *" $1 "* ]]; }

# Usage: detect_ssh_port   -> prints the SSH port (SSH_PORT env, sshd config, or 22)
detect_ssh_port() {
    local p="${SSH_PORT:-}"
    [[ -n "$p" ]] || p="$(sshd -T 2>/dev/null | awk '/^port /{print $2; exit}')"
    echo "${p:-22}"
}

# Usage: normalize_ports "53, 5300 5300"   -> prints "53 5300" (commas -> spaces, duplicates removed)
normalize_ports() {
    echo "$1" | tr ',' ' ' | xargs -n1 2>/dev/null | awk '!seen[$0]++' | xargs
}

# -------------------------
# Settings persistence
# -------------------------

# Usage: load_settings   -> loads PORTS / ALLOWED_CLIENTS / IP_RATELIMIT from the settings file
load_settings() {
    if [[ -f "$SETTINGS_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$SETTINGS_FILE"
    fi
    IP_RATELIMIT="${IP_RATELIMIT:-200}"
}

# Usage: save_settings   -> writes the current settings so the menu remembers them
save_settings() {
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    cat > "$SETTINGS_FILE" <<EOF
PORTS="$PORTS"
ALLOWED_CLIENTS="$ALLOWED_CLIENTS"
IP_RATELIMIT="$IP_RATELIMIT"
DOH_ENABLED="$DOH_ENABLED"
DOH_DOMAIN="$DOH_DOMAIN"
DOH_EMAIL="$DOH_EMAIL"
DOH_PORT="$DOH_PORT"
ADMIN_PORT="$ADMIN_PORT"
ADMIN_ALLOW="$ADMIN_ALLOW"
EOF
    chmod 644 "$SETTINGS_FILE"
}

# -------------------------
# Prompts
# -------------------------

# Usage: validate_ports   -> every port must be 1-65535 and must not clash with SSH
validate_ports() {
    local p ssh
    ssh="$(detect_ssh_port)"
    [[ -n "$PORTS" ]] || error_exit "At least one port is required."
    for p in $PORTS; do
        [[ "$p" =~ ^[0-9]+$ ]] && (( p >= 1 && p <= 65535 )) || error_exit "Invalid port: $p"
        [[ "$p" != "$ssh" ]] || error_exit "Port $p is your SSH port - choose another."
    done
}

# Usage: prompt_ports   -> asks whether to use port 53 and/or custom port(s)
prompt_ports() {
    if [[ -n "$ENV_PORTS" ]]; then
        PORTS="$(normalize_ports "$ENV_PORTS")"
    else
        echo
        echo "Current ports: ${PORTS:-none}"
        local a53 custom new=""
        read -rp "Listen on standard DNS port 53? [Y/n]: " a53
        [[ "$a53" =~ ^[Nn] ]] || new="53"
        read -rp "Custom port(s), comma-separated (blank for none): " custom
        PORTS="$(normalize_ports "$new $custom")"
    fi
    validate_ports
    log "Ports selected: $PORTS"
}

# Usage: prompt_access   -> asks whether everyone or only specific IPs/CIDRs may query
prompt_access() {
    if [[ -n "$ENV_CLIENTS" ]]; then
        ALLOWED_CLIENTS="$(echo "$ENV_CLIENTS" | tr ',' ' ' | xargs)"
    else
        echo
        echo "Who may use this DNS server? (current: ${ALLOWED_CLIENTS:-not set})"
        echo "  1) Everyone (open resolver, rate-limited - can be abused for DDoS amplification)"
        echo "  2) Only specific IPs / CIDR ranges (recommended)"
        echo "  3) Nobody from outside - DoH keys only (plain DNS answers this server itself only)"
        local c list
        read -rp "Choose [1/2/3]: " c
        if [[ "$c" == "2" ]]; then
            read -rp "IPs/CIDRs, space or comma separated (e.g. 203.0.113.0/24 198.51.100.7): " list
            ALLOWED_CLIENTS="$(echo "$list" | tr ',' ' ' | xargs)"
            warn "Add the IP you will test from - other addresses get REFUSED."
        elif [[ "$c" == "3" ]]; then
            ALLOWED_CLIENTS="127.0.0.1/32"
        else
            ALLOWED_CLIENTS="0.0.0.0/0"
        fi
    fi
    [[ -n "$ALLOWED_CLIENTS" ]] || error_exit "Access list cannot be empty."
    local a
    for a in $ALLOWED_CLIENTS; do
        [[ "$a" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}(/[0-9]{1,2})?$ ]] || error_exit "Invalid IP/CIDR: $a"
    done
    log "Access: $ALLOWED_CLIENTS"
}

# -------------------------
# Install / configure steps
# -------------------------

# Usage: install_dependencies   -> installs unbound and the tools this script uses
install_dependencies() {
    log "Installing dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y unbound unbound-anchor dnsutils ca-certificates iproute2 ufw \
        || error_exit "Failed to install required packages"
}

# Usage: check_ports_free   -> frees port 53 from systemd-resolved if needed, then makes sure
# no other service holds any selected port
check_ports_free() {
    local p holder
    if has_port 53 && systemctl is-active --quiet systemd-resolved; then
        log "Disabling systemd-resolved stub listener (it holds port 53)..."
        mkdir -p /etc/systemd/resolved.conf.d
        printf '[Resolve]\nDNSStubListener=no\n' > /etc/systemd/resolved.conf.d/nostub.conf
        systemctl restart systemd-resolved
    fi
    for p in $PORTS; do
        holder="$(ss -tulnpH | awk -v p="$p" '{n=split($5,a,":"); if (a[n]==p) print}' | grep -v unbound || true)"
        if [[ -n "$holder" ]]; then
            echo "$holder"
            error_exit "Port $p is in use by another service. Stop it or choose a different port."
        fi
    done
}

# Usage: setup_dnssec   -> creates/refreshes /var/lib/unbound/root.key
# (unbound-anchor exits 1 when it just updated the key, so the exit code alone is not an error)
setup_dnssec() {
    log "Setting up DNSSEC root trust anchor..."
    mkdir -p /var/lib/unbound
    unbound-anchor -a "$ROOT_KEY" -v || true
    [[ -s "$ROOT_KEY" ]] || error_exit "DNSSEC root key missing or empty at $ROOT_KEY"
    chown -R unbound:unbound /var/lib/unbound
    chmod 644 "$ROOT_KEY"
}

# Usage: configure_unbound   -> writes $UNBOUND_CONF_FILE with one interface line per port
configure_unbound() {
    log "Writing Unbound configuration to $UNBOUND_CONF_FILE"
    mkdir -p "$UNBOUND_CONF_DIR"
    [[ -f "$UNBOUND_CONF_FILE" ]] && cp "$UNBOUND_CONF_FILE" "${UNBOUND_CONF_FILE}.bak.$(date +%s)"

    # Only declare our own trust anchor if the distro has not already done so
    local anchor_line=""
    if ! grep -rqs "auto-trust-anchor-file" /etc/unbound/unbound.conf /etc/unbound/unbound.conf.d/ \
        --exclude="$(basename "$UNBOUND_CONF_FILE")"; then
        anchor_line="auto-trust-anchor-file: \"$ROOT_KEY\""
    fi

    local ifaces="" p
    for p in $PORTS; do ifaces+="    interface: 0.0.0.0@$p"$'\n'; done

    # DoH users all reach Unbound from 127.0.0.1, so the per-IP limit would throttle them together.
    # With DoH enabled the limit is raised and the proxy enforces a per-key limit instead.
    local rl="$IP_RATELIMIT"
    if [[ "$DOH_ENABLED" == "1" ]] && (( rl < 20000 )); then rl=20000; fi

    local acl="    access-control: 127.0.0.0/8 allow" c
    for c in $ALLOWED_CLIENTS; do acl+=$'\n'"    access-control: $c allow"; done

    cat > "$UNBOUND_CONF_FILE" <<EOF
server:
    # Network (one line per port)
    verbosity: 1
    use-syslog: yes
$ifaces    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes

    # Access control (default refuse, then allow)
    access-control: 0.0.0.0/0 refuse
$acl

    # Abuse / amplification protection
    ip-ratelimit: $rl
    ratelimit: 1000
    deny-any: yes
    minimal-responses: yes

    # Performance
    num-threads: 2
    so-reuseport: yes
    msg-cache-size: 128m
    rrset-cache-size: 256m
    outgoing-range: 4096
    incoming-num-tcp: 100
    outgoing-num-tcp: 100
    cache-min-ttl: 60
    cache-max-ttl: 86400
    prefetch: yes
    prefetch-key: yes

    # Privacy / hardening
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-referral-path: yes
    qname-minimisation: yes
    aggressive-nsec: yes
    use-caps-for-id: yes
    unwanted-reply-threshold: 10000000

    # DNSSEC
    $anchor_line
    trust-anchor-signaling: yes

    # DNS rebinding protection
    private-address: 10.0.0.0/8
    private-address: 172.16.0.0/12
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16

# Upstream forwarders
forward-zone:
    name: "."
    forward-addr: 1.1.1.1
    forward-addr: 1.0.0.1
    forward-addr: 8.8.8.8
    forward-addr: 8.8.4.4
EOF
    chmod 644 "$UNBOUND_CONF_FILE"
}

# Usage: validate_and_restart   -> checks config, enables and (re)starts Unbound
validate_and_restart() {
    log "Validating Unbound configuration..."
    unbound-checkconf || error_exit "Unbound configuration failed validation!"
    systemctl enable unbound >/dev/null 2>&1 || true
    systemctl restart unbound || { systemctl status unbound --no-pager -l || true; error_exit "Unbound failed to start"; }
    sleep 2
    systemctl is-active --quiet unbound || error_exit "Unbound is not running"
}

# Usage: point_host_to_local   -> if port 53 is served, makes this server resolve through Unbound;
# if port 53 was dropped, gives the host a working resolver again
point_host_to_local() {
    if has_port 53; then
        [[ -L /etc/resolv.conf ]] && rm -f /etc/resolv.conf
        printf 'nameserver 127.0.0.1\noptions edns0\n' > /etc/resolv.conf
    elif old_has_port 53; then
        log "Port 53 removed - restoring host resolver..."
        rm -f /etc/systemd/resolved.conf.d/nostub.conf
        if systemctl list-unit-files systemd-resolved.service >/dev/null 2>&1 && \
           systemctl restart systemd-resolved 2>/dev/null && [[ -e /run/systemd/resolve/stub-resolv.conf ]]; then
            ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
        else
            printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > /etc/resolv.conf
        fi
    else
        log "Host /etc/resolv.conf untouched (it cannot specify a custom port)."
    fi
}

# Usage: verify_dns   -> for every port: checks the listener, resolution and DNSSEC
verify_dns() {
    local p
    for p in $PORTS; do
        log "Verifying port $p ..."
        ss -tulnp | grep ":${p} " | grep -q unbound || error_exit "Unbound is not listening on port $p"
        dig @127.0.0.1 -p "$p" google.com +short +time=3 +tries=2 | grep -q . \
            || error_exit "Resolution via 127.0.0.1:$p failed"
        if dig @127.0.0.1 -p "$p" cloudflare.com +dnssec +time=3 | grep -q "flags:.* ad"; then
            log "  port $p: resolution + DNSSEC OK"
        else
            warn "  port $p: resolves, but DNSSEC 'ad' flag not seen"
        fi
    done
}

# Usage: configure_firewall   -> allows SSH + every DNS port (+ DoH/admin/80 when DoH is on); removes stale rules
configure_firewall() {
    local ssh p
    ssh="$(detect_ssh_port)"
    log "Configuring ufw (SSH $ssh, DNS: $PORTS)..."
    ufw allow "${ssh}/tcp" >/dev/null
    for p in $OLD_PORTS; do
        if ! has_port "$p"; then
            ufw delete allow "${p}/udp" >/dev/null 2>&1 || true
            ufw delete allow "${p}/tcp" >/dev/null 2>&1 || true
        fi
    done
    for p in $PORTS; do
        ufw allow "${p}/udp" >/dev/null
        ufw allow "${p}/tcp" >/dev/null
    done
    if [[ "$DOH_ENABLED" == "1" ]]; then
        # drop rules for DoH/admin ports or admin restriction that changed
        if [[ -n "$OLD_DOH_PORT" && "$OLD_DOH_PORT" != "$DOH_PORT" ]]; then
            ufw delete allow "${OLD_DOH_PORT}/tcp" >/dev/null 2>&1 || true
        fi
        if [[ -n "$OLD_ADMIN_PORT" && ( "$OLD_ADMIN_PORT" != "$ADMIN_PORT" || "$OLD_ADMIN_ALLOW" != "$ADMIN_ALLOW" ) ]]; then
            if [[ -n "$OLD_ADMIN_ALLOW" ]]; then
                ufw delete allow from "$OLD_ADMIN_ALLOW" to any port "$OLD_ADMIN_PORT" proto tcp >/dev/null 2>&1 || true
            else
                ufw delete allow "${OLD_ADMIN_PORT}/tcp" >/dev/null 2>&1 || true
            fi
        fi
        ufw allow 80/tcp >/dev/null                 # Let's Encrypt renewals
        ufw allow "${DOH_PORT}/tcp" >/dev/null
        if [[ -n "$ADMIN_ALLOW" ]]; then
            ufw allow from "$ADMIN_ALLOW" to any port "$ADMIN_PORT" proto tcp >/dev/null
        else
            ufw allow "${ADMIN_PORT}/tcp" >/dev/null
        fi
    fi
    ufw --force enable >/dev/null
}

# Usage: apply_config   -> applies current PORTS/ALLOWED_CLIENTS (free ports, DNSSEC, config, restart, verify)
apply_config() {
    check_ports_free
    setup_dnssec
    configure_unbound
    validate_and_restart
    point_host_to_local
    sync_doh_upstream
    verify_dns
    configure_firewall
    save_settings
    log "Applied. Ports: $PORTS | Access: $ALLOWED_CLIENTS"
    if [[ "$ALLOWED_CLIENTS" == *"0.0.0.0/0"* ]]; then
        warn "Resolver is OPEN to the internet (rate-limited to ${IP_RATELIMIT} qps per IP)."
    fi
    if has_port 53 && [[ "$PORTS" != "53" ]]; then
        log "Test:  dig @<server-ip> google.com   and   dig @<server-ip> -p <custom> google.com"
    fi
}

# -------------------------
# DoH + key server
# -------------------------

# Usage: write_doh_service_code   -> writes the Python key server (embedded below) to $GAMEDNS_PY
write_doh_service_code() {
    mkdir -p "$GAMEDNS_DIR"
    cat > "$GAMEDNS_PY" <<'PYEOF'
#!/usr/bin/env python3
"""
gamedns_doh.py - key-authenticated DNS-over-HTTPS proxy, admin API and key CLI.
Python standard library only. Edit with:  vi gamedns_doh.py

Usage:
  gamedns_doh.py serve                                   run the DoH proxy + admin API
  gamedns_doh.py create [--telegram-id ID] [--days N] [--note TEXT]
  gamedns_doh.py remove KEY
  gamedns_doh.py list
  gamedns_doh.py purge                                   delete expired keys
  gamedns_doh.py info                                    show URL format / settings

Config comes from the environment or from /etc/gamedns/doh.env:
  GAMEDNS_KEYS_FILE      key database (JSON)                 default /var/lib/gamedns/keys.json
  GAMEDNS_UPSTREAM_HOST  Unbound address                     default 127.0.0.1
  GAMEDNS_UPSTREAM_PORT  Unbound port                        default 53
  GAMEDNS_DOH_LISTEN     DoH backend (behind nginx)          default 127.0.0.1:8053
  GAMEDNS_ADMIN_LISTEN   admin API backend (behind nginx)    default 127.0.0.1:8054
  GAMEDNS_ADMIN_TOKEN    bearer token for the admin API      (required for serve)
  GAMEDNS_KEY_RATE       max queries/second per key          default 100
  GAMEDNS_PUBLIC_BASE    e.g. https://dns.example.com:443/dns-query/

Client URL:  <PUBLIC_BASE><key>
"""
import argparse
import base64
import contextlib
import datetime
import fcntl
import hmac
import json
import os
import re
import secrets
import socket
import struct
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

ENV_FILE = os.environ.get("GAMEDNS_ENV", "/etc/gamedns/doh.env")
KEY_RE = re.compile(r"^[A-Za-z0-9_-]{22}$")
DOH_PATH_RE = re.compile(r"^/dns-query/([A-Za-z0-9_-]{22})/?$")
MAX_BODY = 65535


# Usage: load_env(path)   -> loads KEY=VALUE lines into os.environ without overriding real env vars
def load_env(path=ENV_FILE):
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))
    except FileNotFoundError:
        pass


# Usage: cfg("NAME", "default")   -> returns a config value from the environment
def cfg(name, default=""):
    return os.environ.get(name, default)


# Usage: iso(epoch)   -> "2026-01-31 12:00 UTC" style timestamp
def iso(epoch):
    return datetime.datetime.fromtimestamp(epoch, datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")


# -------------------------------------------------------------------------
# Key store (JSON file, safe for the service and the CLI to use at once)
# -------------------------------------------------------------------------
class KeyStore:
    # Usage: KeyStore(path)   -> key database backed by a JSON file
    def __init__(self, path):
        self.path = path
        self._cache = {}
        self._mtime = None
        self._cache_lock = threading.Lock()

    # Usage: with self._lock():   -> cross-process exclusive lock around read-modify-write
    @contextlib.contextmanager
    def _lock(self):
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        with open(self.path + ".lock", "a") as lf:
            fcntl.flock(lf, fcntl.LOCK_EX)
            try:
                yield
            finally:
                fcntl.flock(lf, fcntl.LOCK_UN)

    # Usage: self._read()   -> returns {"keys": {...}} (empty if the file does not exist)
    def _read(self):
        try:
            with open(self.path) as f:
                data = json.load(f)
        except FileNotFoundError:
            return {"keys": {}}
        data.setdefault("keys", {})
        return data

    # Usage: self._write(data)   -> atomic write with mode 600
    def _write(self, data):
        tmp = self.path + ".tmp"
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, indent=2)
        os.replace(tmp, self.path)

    # Usage: create(days, telegram_id, note)   -> (key, record); key is 22 URL-safe random chars
    def create(self, days, telegram_id=None, note=""):
        if not 1 <= days <= 3650:
            raise ValueError("days must be between 1 and 3650")
        now = int(time.time())
        key = secrets.token_urlsafe(16)
        rec = {"telegramId": telegram_id, "note": (note or "")[:100],
               "created": now, "expires": now + days * 86400}
        with self._lock():
            data = self._read()
            data["keys"][key] = rec
            self._write(data)
        return key, rec

    # Usage: remove(key)   -> True if the key existed and was deleted
    def remove(self, key):
        with self._lock():
            data = self._read()
            existed = data["keys"].pop(key, None) is not None
            if existed:
                self._write(data)
        return existed

    # Usage: list()   -> list of (key, record) sorted by expiry
    def list(self):
        with self._lock():
            data = self._read()
        return sorted(data["keys"].items(), key=lambda kv: kv[1]["expires"])

    # Usage: purge()   -> deletes expired keys, returns how many were removed
    def purge(self):
        now = time.time()
        with self._lock():
            data = self._read()
            dead = [k for k, r in data["keys"].items() if r["expires"] <= now]
            for k in dead:
                del data["keys"][k]
            if dead:
                self._write(data)
        return len(dead)

    # Usage: valid(key)   -> record if the key exists and has not expired, else None (cached by file mtime)
    def valid(self, key):
        if not KEY_RE.match(key):
            return None
        try:
            m = os.stat(self.path).st_mtime_ns
        except FileNotFoundError:
            return None
        with self._cache_lock:
            if m != self._mtime:
                self._cache = self._read().get("keys", {})
                self._mtime = m
            rec = self._cache.get(key)
        if rec and rec["expires"] > time.time():
            return rec
        return None


# -------------------------------------------------------------------------
# Per-key rate limiter (Unbound sees every DoH user as 127.0.0.1)
# -------------------------------------------------------------------------
class RateLimiter:
    # Usage: RateLimiter(rate)   -> token bucket, `rate` queries/second per key (0 disables)
    def __init__(self, rate):
        self.rate = rate
        self.buckets = {}
        self.lock = threading.Lock()

    # Usage: allow(key)   -> True if this key may send another query right now
    def allow(self, key):
        if self.rate <= 0:
            return True
        now = time.monotonic()
        with self.lock:
            tokens, last = self.buckets.get(key, (float(self.rate), now))
            tokens = min(float(self.rate), tokens + (now - last) * self.rate)
            if tokens < 1:
                self.buckets[key] = (tokens, now)
                return False
            self.buckets[key] = (tokens - 1, now)
            return True


# -------------------------------------------------------------------------
# Upstream DNS (Unbound)
# -------------------------------------------------------------------------
# Usage: recv_exact(sock, n)   -> reads exactly n bytes from a TCP socket
def recv_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise OSError("connection closed")
        buf += chunk
    return buf


# Usage: query_tcp(wire, host, port)   -> DNS reply over TCP (used when the UDP reply is truncated)
def query_tcp(wire, host, port):
    with socket.create_connection((host, port), timeout=4) as s:
        s.sendall(struct.pack("!H", len(wire)) + wire)
        (n,) = struct.unpack("!H", recv_exact(s, 2))
        return recv_exact(s, n)


# Usage: query_upstream(wire)   -> asks Unbound over UDP, falls back to TCP if the TC bit is set
def query_upstream(wire):
    host = cfg("GAMEDNS_UPSTREAM_HOST", "127.0.0.1")
    port = int(cfg("GAMEDNS_UPSTREAM_PORT", "53"))
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.settimeout(4)
        s.sendto(wire, (host, port))
        while True:
            resp, _ = s.recvfrom(65535)
            if resp[:2] == wire[:2]:
                break
    if len(resp) >= 4 and resp[2] & 0x02:
        resp = query_tcp(wire, host, port)
    return resp


# -------------------------------------------------------------------------
# HTTP handlers
# -------------------------------------------------------------------------
class BaseHandler(BaseHTTPRequestHandler):
    server_version = "gamedns"
    sys_version = ""

    # Usage: log_message(...)   -> disabled on purpose: request paths contain secret keys
    def log_message(self, *args):
        pass

    # Usage: self._send(code, body, content_type, extra_headers)   -> writes a complete response
    def _send(self, code, body=b"", ctype="text/plain", extra=None):
        if isinstance(body, str):
            body = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    # Usage: self._body()   -> request body bytes (None if the length is missing/invalid/too large)
    def _body(self):
        try:
            n = int(self.headers.get("Content-Length", ""))
        except ValueError:
            return None
        if n < 0 or n > MAX_BODY:
            return None
        return self.rfile.read(n)


class DohHandler(BaseHandler):
    # Usage: self._handle(method)   -> validates the key, rate-limits, forwards the DNS query to Unbound
    def _handle(self, method):
        u = urlsplit(self.path)
        m = DOH_PATH_RE.match(u.path)
        if not m:
            return self._send(404, "not found")
        key = m.group(1)
        if not STORE.valid(key):
            return self._send(403, "forbidden")
        if not LIMITER.allow(key):
            return self._send(429, "rate limited", extra={"Retry-After": "1"})

        if method == "GET":
            q = parse_qs(u.query).get("dns")
            if not q:
                return self._send(400, "missing dns parameter")
            try:
                wire = base64.urlsafe_b64decode(q[0] + "=" * (-len(q[0]) % 4))
            except Exception:
                return self._send(400, "bad base64")
        else:
            if not self.headers.get("Content-Type", "").startswith("application/dns-message"):
                return self._send(415, "content-type must be application/dns-message")
            wire = self._body()
            if wire is None:
                return self._send(400, "bad body")

        if len(wire) < 12:
            return self._send(400, "bad dns message")
        try:
            resp = query_upstream(wire)
        except (OSError, socket.timeout):
            return self._send(502, "upstream failure")
        self._send(200, resp, "application/dns-message")

    # Usage: (called by http.server for GET)
    def do_GET(self):
        self._handle("GET")

    # Usage: (called by http.server for POST)
    def do_POST(self):
        self._handle("POST")


class AdminHandler(BaseHandler):
    # Usage: self._auth()   -> True if the request carries the correct bearer token
    def _auth(self):
        token = cfg("GAMEDNS_ADMIN_TOKEN")
        h = self.headers.get("Authorization", "")
        return bool(token) and h.startswith("Bearer ") and hmac.compare_digest(
            h[7:].encode("utf-8", "replace"), token.encode())

    # Usage: self._json(code, obj)   -> JSON response
    def _json(self, code, obj):
        self._send(code, json.dumps(obj), "application/json")

    # Usage: self._payload()   -> parsed JSON body ({} if empty); None if invalid
    def _payload(self):
        raw = self._body()
        if raw is None:
            return None
        if not raw.strip():
            return {}
        try:
            data = json.loads(raw)
        except ValueError:
            return None
        return data if isinstance(data, dict) else None

    # Usage: (called by http.server) GET /list
    def do_GET(self):
        if not self._auth():
            return self._json(401, {"error": "unauthorized"})
        if urlsplit(self.path).path != "/list":
            return self._json(404, {"error": "not found"})
        now = time.time()
        self._json(200, {"keys": [
            {"key": k, "telegramId": r.get("telegramId"), "note": r.get("note", ""),
             "expires": iso(r["expires"]), "active": r["expires"] > now}
            for k, r in STORE.list()]})

    # Usage: (called by http.server) POST /create  /remove  /purge
    def do_POST(self):
        if not self._auth():
            return self._json(401, {"error": "unauthorized"})
        path = urlsplit(self.path).path
        data = self._payload()
        if data is None:
            return self._json(400, {"error": "invalid JSON body"})

        if path == "/create":
            try:
                days = int(data.get("days", 30))
                tg = data.get("telegramId")
                tg = int(tg) if tg not in (None, "") else None
                key, rec = STORE.create(days, tg, str(data.get("note", "")))
            except (ValueError, TypeError) as e:
                return self._json(400, {"error": str(e)})
            return self._json(200, {"key": key, "telegramId": tg, "expires": iso(rec["expires"]),
                                    "url": cfg("GAMEDNS_PUBLIC_BASE") + key})
        if path == "/remove":
            key = str(data.get("key", ""))
            if not KEY_RE.match(key):
                return self._json(400, {"error": "invalid key"})
            ok = STORE.remove(key)
            return self._json(200 if ok else 404, {"removed": ok})
        if path == "/purge":
            return self._json(200, {"purged": STORE.purge()})
        self._json(404, {"error": "not found"})


# -------------------------------------------------------------------------
# Commands
# -------------------------------------------------------------------------
STORE = None
LIMITER = None


# Usage: split_addr("127.0.0.1:8053")   -> ("127.0.0.1", 8053)
def split_addr(s):
    host, port = s.rsplit(":", 1)
    return host, int(port)


# Usage: serve()   -> runs the admin API in a thread and the DoH proxy in the main thread
def serve():
    if not cfg("GAMEDNS_ADMIN_TOKEN"):
        sys.exit("GAMEDNS_ADMIN_TOKEN is not set - refusing to start")
    ThreadingHTTPServer.request_queue_size = 128
    admin = ThreadingHTTPServer(split_addr(cfg("GAMEDNS_ADMIN_LISTEN", "127.0.0.1:8054")), AdminHandler)
    doh = ThreadingHTTPServer(split_addr(cfg("GAMEDNS_DOH_LISTEN", "127.0.0.1:8053")), DohHandler)
    admin.daemon_threads = doh.daemon_threads = True
    threading.Thread(target=admin.serve_forever, daemon=True).start()
    print("gamedns: DoH backend %s, admin backend %s, upstream %s:%s" % (
        cfg("GAMEDNS_DOH_LISTEN", "127.0.0.1:8053"), cfg("GAMEDNS_ADMIN_LISTEN", "127.0.0.1:8054"),
        cfg("GAMEDNS_UPSTREAM_HOST", "127.0.0.1"), cfg("GAMEDNS_UPSTREAM_PORT", "53")), flush=True)
    doh.serve_forever()


# Usage: main()   -> parses the CLI and dispatches
def main():
    global STORE, LIMITER
    load_env()
    STORE = KeyStore(cfg("GAMEDNS_KEYS_FILE", "/var/lib/gamedns/keys.json"))
    LIMITER = RateLimiter(int(cfg("GAMEDNS_KEY_RATE", "100")))

    ap = argparse.ArgumentParser(description="gamedns key server")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("serve")
    c = sub.add_parser("create")
    c.add_argument("--telegram-id", type=int, default=None)
    c.add_argument("--days", type=int, default=30)
    c.add_argument("--note", default="")
    r = sub.add_parser("remove")
    r.add_argument("key")
    sub.add_parser("list")
    sub.add_parser("purge")
    sub.add_parser("info")
    a = ap.parse_args()

    if a.cmd == "serve":
        serve()
    elif a.cmd == "create":
        try:
            key, rec = STORE.create(a.days, a.telegram_id, a.note)
        except ValueError as e:
            sys.exit("error: %s" % e)
        print("Key:      %s" % key)
        print("Expires:  %s" % iso(rec["expires"]))
        print("URL:      %s%s" % (cfg("GAMEDNS_PUBLIC_BASE"), key))
    elif a.cmd == "remove":
        if not KEY_RE.match(a.key):
            sys.exit("error: invalid key format")
        if STORE.remove(a.key):
            print("Removed.")
        else:
            sys.exit("error: key not found")
    elif a.cmd == "list":
        rows = STORE.list()
        if not rows:
            print("(no keys)")
        now = time.time()
        for k, rec in rows:
            print("%s  %-10s  %-8s  expires %s  %s" % (
                k, rec.get("telegramId") or "-", "active" if rec["expires"] > now else "EXPIRED",
                iso(rec["expires"]), rec.get("note", "")))
    elif a.cmd == "purge":
        print("Removed %d expired key(s)." % STORE.purge())
    elif a.cmd == "info":
        print("Key file:     %s" % STORE.path)
        print("Client URL:   %s<key>" % cfg("GAMEDNS_PUBLIC_BASE", "(not set)"))
        print("Upstream:     %s:%s" % (cfg("GAMEDNS_UPSTREAM_HOST", "127.0.0.1"), cfg("GAMEDNS_UPSTREAM_PORT", "53")))
        print("Per-key rate: %s qps" % cfg("GAMEDNS_KEY_RATE", "100"))


if __name__ == "__main__":
    main()
PYEOF
    chmod 755 "$GAMEDNS_PY"
}

# Usage: get_env_value NAME   -> prints NAME's value from the DoH env file (empty if missing)
get_env_value() { grep -E "^$1=" "$DOH_ENV" 2>/dev/null | head -1 | cut -d= -f2- || true; }

# Usage: port_holder <port>   -> prints the TCP listener line for <port> (empty if the port is free)
port_holder() { ss -tlnpH | awk -v p="$1" '{n=split($4,a,":"); if (a[n]==p) print}'; }

# Usage: port_owner_info <port>   -> prints "process|pid|unit" of the first non-nginx listener on <port>
port_owner_info() {
    local line proc pid unit=""
    line="$(port_holder "$1" | grep -v nginx | head -1 || true)"
    proc="$(sed -n 's/.*users:(("\([^"]*\)",pid=\([0-9]*\).*/\1/p' <<<"$line")"
    pid="$(sed -n 's/.*users:(("\([^"]*\)",pid=\([0-9]*\).*/\2/p' <<<"$line")"
    [[ -z "$pid" ]] || unit="$(ps -o unit= -p "$pid" 2>/dev/null | xargs || true)"
    echo "${proc}|${pid}|${unit}"
}

# Usage: ensure_port_free <port> "<label>" [allow-change: 1|0]
# Checks whether <port> is in use (nginx is ignored - it is shared safely). If something else holds it,
# shows which process and asks you to stop it (it can stop the service for you), re-checking each time.
# Returns 0 when the port is free, 1 if you chose to pick a different port; exits if you abort.
ensure_port_free() {
    local port="$1" label="$2" allow_change="${3:-1}" holder info proc pid unit c yn
    while true; do
        holder="$(port_holder "$port" | grep -v nginx || true)"
        [[ -z "$holder" ]] && return 0

        info="$(port_owner_info "$port")"
        IFS='|' read -r proc pid unit <<<"$info"
        echo
        warn "Port $port ($label) is already in use:"
        echo "    $holder"
        echo "    Process: ${proc:-unknown}   PID: ${pid:-?}   Service: ${unit:--}"
        [[ -t 0 ]] || error_exit "Port $port is busy and there is no terminal to ask - stop the service and re-run."
        echo "  1) Stop that service now"
        echo "  2) I will stop it myself - re-check when I press Enter"
        [[ "$allow_change" == "1" ]] && echo "  3) Use a different port"
        echo "  4) Abort"
        read -rp "Choose: " c
        case "$c" in
            1)
                if [[ "$unit" != *.service ]]; then
                    warn "Cannot tell which service owns it (unit: ${unit:--}). Stop it manually (option 2)."
                elif [[ "$unit" =~ ^(ssh|sshd|systemd-.*|unbound|dbus|cron)\.service$ ]]; then
                    warn "Refusing to stop $unit - it is needed by this server."
                else
                    read -rp "Stop $unit? Websites or apps using it will go offline. [y/N]: " yn
                    if [[ "$yn" =~ ^[Yy] ]]; then
                        systemctl stop "$unit" || warn "Could not stop $unit."
                        read -rp "Also disable $unit so it does not start again on boot? [y/N]: " yn
                        if [[ "$yn" =~ ^[Yy] ]]; then systemctl disable "$unit" >/dev/null 2>&1 || true; fi
                        sleep 1
                    fi
                fi
                ;;
            2) read -rp "Stop it now, then press Enter to re-check... " _ ;;
            3) if [[ "$allow_change" == "1" ]]; then return 1; else warn "This port cannot be changed."; fi ;;
            4) error_exit "Aborted: port $port is in use." ;;
            *) warn "Invalid choice." ;;
        esac
    done
}

# Usage: ask_free_port <VAR_NAME> "<label>" <default> [port-to-avoid]
# Asks for a port, validates it (range, reserved, plain-DNS clash), then runs ensure_port_free on it;
# asks again if you choose a different port. The result is stored in the variable named <VAR_NAME>.
ask_free_port() {
    local -n _result="$1"
    local label="$2" dflt="$3" avoid="${4:-}" v p
    while true; do
        read -rp "$label port [$dflt]: " v
        p="${v:-$dflt}"
        if ! [[ "$p" =~ ^[0-9]+$ ]] || (( p < 1 || p > 65535 )); then warn "Invalid port: $p"; continue; fi
        if [[ "$p" == "80" || "$p" == "$(detect_ssh_port)" || "$p" == "$DOH_BACKEND_PORT" || "$p" == "$ADMIN_BACKEND_PORT" ]]; then
            warn "Port $p is reserved (80 / SSH / internal backend)."; continue
        fi
        if has_port "$p"; then warn "Port $p is already used for plain DNS."; continue; fi
        if [[ -n "$avoid" && "$p" == "$avoid" ]]; then warn "That port is already used for the other service."; continue; fi
        if ensure_port_free "$p" "$label"; then
            _result="$p"
            return 0
        fi
    done
}

# Usage: keys_cli <args>   -> runs the key CLI as the service user so file ownership stays correct
keys_cli() { runuser -u gamedns -- python3 "$GAMEDNS_PY" "$@"; }

# Usage: require_doh   -> aborts unless the DoH key server has been installed
require_doh() {
    [[ "$DOH_ENABLED" == "1" && -f "$GAMEDNS_PY" ]] || error_exit "DoH key server is not installed - use menu option 7."
}

# Usage: prompt_doh_settings   -> asks for domain, email, DoH port, admin port and admin IP restriction
prompt_doh_settings() {
    echo
    echo "--- DoH key server settings ---"
    local v
    read -rp "Domain name (its A record must point to this server) [${DOH_DOMAIN}]: " v
    DOH_DOMAIN="${v:-$DOH_DOMAIN}"
    [[ "$DOH_DOMAIN" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ && "$DOH_DOMAIN" == *.* ]] || error_exit "Invalid domain: $DOH_DOMAIN"
    read -rp "Email for Let's Encrypt [${DOH_EMAIL}]: " v
    DOH_EMAIL="${v:-$DOH_EMAIL}"
    [[ "$DOH_EMAIL" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]] || error_exit "Invalid email: $DOH_EMAIL"
    ask_free_port DOH_PORT "DoH HTTPS" "${DOH_PORT:-443}"
    ask_free_port ADMIN_PORT "Admin API HTTPS" "${ADMIN_PORT:-11112}" "$DOH_PORT"
    read -rp "Admin API allowed only from this IP/CIDR (type 'any' for anywhere) [${ADMIN_ALLOW:-any}]: " v
    v="${v:-${ADMIN_ALLOW:-any}}"
    if [[ "$v" == "any" ]]; then ADMIN_ALLOW=""; else ADMIN_ALLOW="$v"; fi

    if [[ -n "$ADMIN_ALLOW" ]]; then
        [[ "$ADMIN_ALLOW" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}(/[0-9]{1,2})?$ ]] || error_exit "Invalid admin IP/CIDR: $ADMIN_ALLOW"
    else
        warn "Admin API will be reachable from anywhere (protected by the bearer token only)."
    fi
}

# Usage: check_domain_dns   -> warns if the domain's A record does not point at this server
check_domain_dns() {
    local resolved mine
    resolved="$(dig +short A "$DOH_DOMAIN" @1.1.1.1 +time=3 +tries=1 2>/dev/null | tail -1 || true)"
    mine="$(curl -4fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)"
    if [[ -z "$resolved" ]]; then
        warn "$DOH_DOMAIN has no A record yet - the Let's Encrypt request will fail until it points here."
    elif [[ -n "$mine" && "$resolved" != "$mine" ]]; then
        warn "$DOH_DOMAIN resolves to $resolved but this server's public IP looks like $mine."
    else
        log "DNS record OK ($DOH_DOMAIN -> $resolved)"
    fi
}

# Usage: install_doh_packages   -> installs nginx, certbot, python3, curl, openssl
install_doh_packages() {
    log "Installing DoH packages..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y nginx certbot python3 curl openssl || error_exit "Failed to install DoH packages"
}

# Usage: setup_doh_user   -> creates the unprivileged 'gamedns' user and data directory
setup_doh_user() {
    id gamedns >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin gamedns
    mkdir -p "$DOH_DATA" /etc/gamedns
    chown gamedns:gamedns "$DOH_DATA"
    chmod 750 "$DOH_DATA"
}

# Usage: write_doh_env   -> writes /etc/gamedns/doh.env (keeps the existing admin token if there is one)
write_doh_env() {
    local token upstream_port hostport
    token="$(get_env_value GAMEDNS_ADMIN_TOKEN)"
    [[ -n "$token" ]] || token="$(openssl rand -hex 32)"
    upstream_port="53"
    has_port 53 || upstream_port="${PORTS%% *}"
    hostport="$DOH_DOMAIN"
    [[ "$DOH_PORT" == "443" ]] || hostport+=":$DOH_PORT"
    cat > "$DOH_ENV" <<EOF
GAMEDNS_KEYS_FILE=$DOH_DATA/keys.json
GAMEDNS_UPSTREAM_HOST=127.0.0.1
GAMEDNS_UPSTREAM_PORT=$upstream_port
GAMEDNS_DOH_LISTEN=127.0.0.1:$DOH_BACKEND_PORT
GAMEDNS_ADMIN_LISTEN=127.0.0.1:$ADMIN_BACKEND_PORT
GAMEDNS_ADMIN_TOKEN=$token
GAMEDNS_KEY_RATE=100
GAMEDNS_PUBLIC_BASE=https://$hostport/dns-query/
EOF
    chown root:gamedns "$DOH_ENV"
    chmod 640 "$DOH_ENV"
}

# Usage: sync_doh_upstream   -> after a DNS port change, points the DoH proxy at a port Unbound still serves
sync_doh_upstream() {
    [[ "$DOH_ENABLED" == "1" && -f "$DOH_ENV" ]] || return 0
    local up="53"
    has_port 53 || up="${PORTS%% *}"
    sed -i "s|^GAMEDNS_UPSTREAM_PORT=.*|GAMEDNS_UPSTREAM_PORT=$up|" "$DOH_ENV"
    systemctl restart "$DOH_SERVICE" 2>/dev/null || true
}

# Usage: obtain_certificate   -> Let's Encrypt certificate via certbot standalone (needs port 80), plus renewal hook
obtain_certificate() {
    local live="/etc/letsencrypt/live/$DOH_DOMAIN"
    mkdir -p /etc/letsencrypt/renewal-hooks/deploy
    printf '#!/bin/sh\nsystemctl reload nginx\n' > /etc/letsencrypt/renewal-hooks/deploy/gamedns-reload.sh
    chmod 755 /etc/letsencrypt/renewal-hooks/deploy/gamedns-reload.sh
    if [[ -s "$live/fullchain.pem" ]]; then
        log "Certificate for $DOH_DOMAIN already present."
        return 0
    fi
    rm -f /etc/nginx/sites-enabled/default /etc/nginx/conf.d/default.conf
    systemctl stop nginx 2>/dev/null || true
    ensure_port_free 80 "Let's Encrypt validation" 0 || error_exit "Port 80 must be free for Let's Encrypt."
    log "Requesting Let's Encrypt certificate for $DOH_DOMAIN ..."
    certbot certonly --standalone -d "$DOH_DOMAIN" -m "$DOH_EMAIL" --agree-tos --no-eff-email --non-interactive \
        || error_exit "Certificate request failed (check the A record and that port 80 is reachable from the internet)."
}

# Usage: write_nginx_conf   -> nginx TLS front end: DoH on $DOH_PORT and admin API on $ADMIN_PORT
write_nginx_conf() {
    local ver h2_listen="" h2_dir=""
    ver="$(nginx -v 2>&1 | sed -n 's|.*/\([0-9.]*\).*|\1|p')"
    if [[ "$(printf '%s\n1.25.1\n' "$ver" | sort -V | head -1)" == "1.25.1" ]]; then
        h2_dir="    http2 on;"
    else
        h2_listen=" http2"
    fi
    cat > "$DOH_NGINX_CONF" <<EOF
# Managed by DNS manager - regenerated on reconfigure.
# access_log is off on purpose: DoH request paths contain the secret key.
server {
    listen ${DOH_PORT} ssl${h2_listen};
${h2_dir}
    server_name ${DOH_DOMAIN};
    ssl_certificate     /etc/letsencrypt/live/${DOH_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOH_DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_cache shared:gamedns_doh:10m;
    access_log off;

    location /dns-query/ {
        proxy_pass http://127.0.0.1:${DOH_BACKEND_PORT};
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host \$host;
        proxy_read_timeout 6s;
        client_max_body_size 8k;
    }
    location / { return 404; }
}

server {
    listen ${ADMIN_PORT} ssl;
    server_name ${DOH_DOMAIN};
    ssl_certificate     /etc/letsencrypt/live/${DOH_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOH_DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    access_log off;

    location / {
        proxy_pass http://127.0.0.1:${ADMIN_BACKEND_PORT};
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host \$host;
        proxy_read_timeout 10s;
        client_max_body_size 8k;
    }
}
EOF
    nginx -t || error_exit "nginx configuration test failed"
    systemctl enable nginx >/dev/null 2>&1 || true
    systemctl restart nginx || error_exit "nginx failed to start"
}

# Usage: write_systemd_unit   -> installs and starts the unprivileged, sandboxed gamedns-doh service
write_systemd_unit() {
    cat > "/etc/systemd/system/${DOH_SERVICE}.service" <<EOF
[Unit]
Description=GameDNS DoH key server
After=network.target unbound.service

[Service]
User=gamedns
Group=gamedns
EnvironmentFile=$DOH_ENV
ExecStart=$(command -v python3) $GAMEDNS_PY serve
Restart=always
RestartSec=2
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=$DOH_DATA

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "$DOH_SERVICE" >/dev/null 2>&1
    systemctl restart "$DOH_SERVICE"
}

# Usage: verify_doh   -> end-to-end test: unknown key = 403, admin API = 200, temp key resolves a real query
verify_doh() {
    log "Verifying DoH server..."
    sleep 2
    systemctl is-active --quiet "$DOH_SERVICE" || { journalctl -u "$DOH_SERVICE" -n 20 --no-pager || true; error_exit "DoH service is not running"; }
    local token code key out
    token="$(get_env_value GAMEDNS_ADMIN_TOKEN)"
    code="$(curl -s -o /dev/null -w '%{http_code}' --resolve "$DOH_DOMAIN:$DOH_PORT:127.0.0.1" \
        "https://$DOH_DOMAIN:$DOH_PORT/dns-query/AAAAAAAAAAAAAAAAAAAAAA" || true)"
    [[ "$code" == "403" ]] || error_exit "DoH endpoint should reject unknown keys with 403 (got: $code)"
    code="$(curl -s -o /dev/null -w '%{http_code}' --resolve "$DOH_DOMAIN:$ADMIN_PORT:127.0.0.1" \
        -H "Authorization: Bearer $token" "https://$DOH_DOMAIN:$ADMIN_PORT/list" || true)"
    [[ "$code" == "200" ]] || error_exit "Admin API check failed (got: $code)"

    key="$(keys_cli create --days 1 --note self-test | awk '/^Key:/{print $2}')"
    [[ -n "$key" ]] || error_exit "Could not create a self-test key"
    out="$(mktemp)"
    code="$(curl -s -o "$out" -w '%{http_code}' --resolve "$DOH_DOMAIN:$DOH_PORT:127.0.0.1" \
        "https://$DOH_DOMAIN:$DOH_PORT/dns-query/$key?dns=AAABAAABAAAAAAAAB2V4YW1wbGUDY29tAAABAAE" || true)"
    keys_cli remove "$key" >/dev/null || true
    if [[ "$code" == "200" && -s "$out" ]]; then
        log "DoH end-to-end test passed (real query answered through Unbound)."
    else
        rm -f "$out"
        error_exit "DoH end-to-end test failed (HTTP $code). Check: journalctl -u $DOH_SERVICE"
    fi
    rm -f "$out"
}

# Usage: print_doh_summary   -> connection details, API examples and security notes
print_doh_summary() {
    local token base admin
    token="$(get_env_value GAMEDNS_ADMIN_TOKEN)"
    base="$(get_env_value GAMEDNS_PUBLIC_BASE)"
    admin="https://$DOH_DOMAIN:$ADMIN_PORT"
    cat <<EOF

═══════════════════════════════════════════════════════════════════════════════
GAMEDNS DoH SERVER
═══════════════════════════════════════════════════════════════════════════════

Domain:          $DOH_DOMAIN
DoH port:        $DOH_PORT   (customer URL: ${base}<key>)
Admin API port:  $ADMIN_PORT   (allowed from: ${ADMIN_ALLOW:-anywhere})
Bearer token:    $token

Create a key:
curl -X POST $admin/create \\
  -H "Authorization: Bearer $token" -H "Content-Type: application/json" \\
  -d '{"telegramId": 123456789, "days": 30}'

Remove a key:
curl -X POST $admin/remove \\
  -H "Authorization: Bearer $token" -H "Content-Type: application/json" \\
  -d '{"key": "<key>"}'

List keys:
curl $admin/list -H "Authorization: Bearer $token"

Manage keys locally: menu option 8 (Key panel)
Logs:  journalctl -u $DOH_SERVICE -f      (nginx access logging is OFF: URLs contain keys)

Security notes:
- Keep the bearer token secret - it gates /create and /remove.
- Keys live in $DOH_DATA/keys.json (no database); the service runs as user 'gamedns', not root.
- HTTPS certificates renew automatically (certbot.timer); nginx is reloaded by a deploy hook.
- Each key is limited to 100 queries/second by the proxy.
═══════════════════════════════════════════════════════════════════════════════
EOF
    if [[ "$ALLOWED_CLIENTS" == *"0.0.0.0/0"* ]]; then
        warn "Plain DNS on port(s) $PORTS is still open to everyone. To make keys the only way in, use menu option 3 -> 'DoH only'."
    fi
}

# Usage: rotate_admin_token   -> generates a new admin API token and restarts the service
rotate_admin_token() {
    local new
    new="$(openssl rand -hex 32)"
    sed -i "s|^GAMEDNS_ADMIN_TOKEN=.*|GAMEDNS_ADMIN_TOKEN=$new|" "$DOH_ENV"
    systemctl restart "$DOH_SERVICE"
    log "New admin token: $new"
}

# Usage: do_install_doh   -> full DoH install/reconfigure (prompts, packages, certificate, nginx, service, self-test)
do_install_doh() {
    check_os
    command -v unbound >/dev/null || error_exit "Install Unbound first (menu option 1)."
    [[ -n "$PORTS" ]] || error_exit "No DNS ports configured - run option 1 first."
    OLD_DOH_PORT="$DOH_PORT"; OLD_ADMIN_PORT="$ADMIN_PORT"; OLD_ADMIN_ALLOW="$ADMIN_ALLOW"
    prompt_doh_settings
    DOH_ENABLED="1"
    check_domain_dns
    install_doh_packages
    setup_doh_user
    apply_config              # Unbound rate limit + firewall (DoH ports, port 80) + saves settings
    write_doh_service_code
    write_doh_env
    obtain_certificate
    write_nginx_conf
    write_systemd_unit
    verify_doh
    print_doh_summary
}

# Usage: key_panel   -> interactive key management panel (create / remove / list / purge / info / rotate token)
key_panel() {
    require_doh
    local c tg days note key
    local -a args
    while true; do
        echo
        echo "================= Key panel ================="
        echo "  Server: https://$DOH_DOMAIN:$DOH_PORT   Service: $(systemctl is-active "$DOH_SERVICE" 2>/dev/null || true)"
        echo "---------------------------------------------"
        echo "  1) Create key"
        echo "  2) Remove key"
        echo "  3) List keys"
        echo "  4) Remove expired keys"
        echo "  5) Show server info + API examples + token"
        echo "  6) Rotate admin token"
        echo "  0) Back"
        read -rp "Choose: " c
        case "$c" in
            1)
                read -rp "Telegram ID (blank = none): " tg
                if [[ -n "$tg" && ! "$tg" =~ ^[0-9]+$ ]]; then warn "Telegram ID must be numeric."; continue; fi
                read -rp "Days valid [30]: " days
                days="${days:-30}"
                if ! [[ "$days" =~ ^[0-9]+$ ]] || (( days < 1 || days > 3650 )); then warn "Days must be 1-3650."; continue; fi
                read -rp "Note (optional): " note
                args=(create --days "$days")
                [[ -z "$tg" ]] || args+=(--telegram-id "$tg")
                [[ -z "$note" ]] || args+=(--note "$note")
                keys_cli "${args[@]}" || warn "Create failed."
                ;;
            2)
                keys_cli list || true
                read -rp "Key to remove: " key
                keys_cli remove "$key" || warn "Remove failed."
                ;;
            3) keys_cli list || true ;;
            4) keys_cli purge || true ;;
            5) print_doh_summary ;;
            6) rotate_admin_token ;;
            0) return 0 ;;
            *) warn "Invalid choice." ;;
        esac
    done
}


# -------------------------
# Menu actions
# -------------------------

# Usage: do_install   -> dependencies + ports prompt + access prompt + apply,
# then offers the DoH key server (asks for domain + email, like the original script did)
do_install() {
    check_os
    install_dependencies
    prompt_ports
    prompt_access
    apply_config
    if [[ -t 0 ]]; then
        local ans
        echo
        read -rp "Set up the DoH key server now? (asks for domain + email) [y/N]: " ans
        if [[ "$ans" =~ ^[Yy] ]]; then
            do_install_doh
        else
            log "Skipped. You can add it any time with menu option 7."
        fi
    fi
}

# Usage: do_change_ports   -> asks for new ports and re-applies (keeps access list)
do_change_ports() {
    command -v unbound >/dev/null || error_exit "Unbound is not installed - choose Install first."
    prompt_ports
    [[ -n "$ALLOWED_CLIENTS" ]] || prompt_access
    apply_config
}

# Usage: do_change_access   -> asks who may query and re-applies (keeps ports)
do_change_access() {
    command -v unbound >/dev/null || error_exit "Unbound is not installed - choose Install first."
    [[ -n "$PORTS" ]] || prompt_ports
    prompt_access
    apply_config
}

# Usage: show_status   -> service state, saved settings, listeners and firewall rules
show_status() {
    echo "=== Unbound status ==="
    echo "Service:  $(systemctl is-active unbound 2>/dev/null || echo not-installed)"
    echo "Ports:    ${PORTS:-not configured}"
    echo "Access:   ${ALLOWED_CLIENTS:-not configured}"
    echo "Rate lim: ${IP_RATELIMIT} qps/IP"
    if [[ "$DOH_ENABLED" == "1" ]]; then
        echo "DoH:      https://$DOH_DOMAIN:$DOH_PORT  service: $(systemctl is-active "$DOH_SERVICE" 2>/dev/null || true)  admin port: $ADMIN_PORT (from ${ADMIN_ALLOW:-anywhere})"
    else
        echo "DoH:      not installed"
    fi
    echo "--- listeners ---"
    ss -tulnp 2>/dev/null | grep unbound || echo "(none)"
    echo "--- config check ---"
    unbound-checkconf 2>&1 | tail -1 || true
    echo "--- firewall ---"
    ufw status 2>/dev/null | grep -E "Status|ALLOW" || echo "(ufw inactive)"
}

# Usage: find_script <filename>   -> prints the path of a sibling script (script dir or cwd), or nothing
find_script() {
    local d
    for d in "$SCRIPT_DIR" "$PWD"; do
        [[ -f "$d/$1" ]] && { echo "$d/$1"; return 0; }
    done
    return 0
}

# Usage: run_check   -> runs DNS_Security_Check_fixed.sh against 127.0.0.1 (or an IP you type)
run_check() {
    local s target
    s="$(find_script DNS_Security_Check_fixed.sh)"
    [[ -n "$s" ]] || error_exit "DNS_Security_Check_fixed.sh not found next to this script or in $PWD."
    read -rp "Server IP to test [127.0.0.1]: " target
    bash "$s" "${target:-127.0.0.1}" "$(echo "${PORTS:-53}" | tr ' ' ',')" || true
}

# Usage: run_speedtest   -> runs Test_DNS_fixed.sh for one chosen port
run_speedtest() {
    local s target port
    s="$(find_script Test_DNS_fixed.sh)"
    [[ -n "$s" ]] || error_exit "Test_DNS_fixed.sh not found next to this script or in $PWD."
    read -rp "Server IP to test [127.0.0.1]: " target
    read -rp "Port to test (configured: ${PORTS:-53}) [${PORTS%% *}]: " port
    bash "$s" "${target:-127.0.0.1}" "${port:-${PORTS%% *}}" || true
}

# Usage: run_action <function>   -> runs a menu action in a subshell so a failure returns to the menu
# instead of closing the script (errexit is enabled inside, and settings are reloaded afterwards)
run_action() {
    local rc=0
    OLD_PORTS="$PORTS"
    set +e
    ( set -e; "$@" )
    rc=$?
    set -e
    (( rc == 0 )) || warn "Action failed (exit $rc)."
    load_settings
}

# Usage: menu   -> interactive main menu loop
menu() {
    local c
    while true; do
        echo
        echo "=========== Unbound DNS Manager ==========="
        echo "  Ports: ${PORTS:-not configured}   Access: ${ALLOWED_CLIENTS:-not configured}"
        echo "-------------------------------------------"
        echo "  1) Install / full setup"
        echo "  2) Change listening ports (53 and/or custom)"
        echo "  3) Change who may query (access control)"
        echo "  4) Show status"
        echo "  5) Run security check"
        echo "  6) Run speed test"
        echo "  7) Install / reconfigure DoH key server (nginx + Let's Encrypt)"
        echo "  8) Key panel (create / remove / list keys)"
        echo "  0) Exit"
        read -rp "Choose: " c
        case "$c" in
            1) run_action do_install ;;
            2) run_action do_change_ports ;;
            3) run_action do_change_access ;;
            4) run_action show_status ;;
            5) run_action run_check ;;
            6) run_action run_speedtest ;;
            7) run_action do_install_doh ;;
            8) run_action key_panel ;;
            0) exit 0 ;;
            *) warn "Invalid choice." ;;
        esac
    done
}

# -------------------------
# Main
# -------------------------

# Usage: main "$@"   -> checks root, loads saved settings, then runs menu or a direct command
main() {
    run_as_root
    load_settings
    OLD_PORTS="$PORTS"
    case "${1:-menu}" in
        install) do_install ;;
        status)  show_status ;;
        doh)     do_install_doh ;;
        keys)    key_panel ;;
        menu)    menu ;;
        *) error_exit "Unknown command: $1  (use: install | doh | keys | status | or no argument for the menu)" ;;
    esac
}

main "$@"

# Run directly from GitHub (menu will not find the test scripts unless they are in the current dir):
# bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/DNS/DNS_doHGame_installed.sh)
