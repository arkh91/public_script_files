# GameDNS – Unbound DNS Manager with DoH Key Server

A menu-driven installer and manager for a DNSSEC-validating recursive DNS server
([Unbound](https://nlnetlabs.nl/projects/unbound/about/)) on Debian/Ubuntu, with an optional
**DNS-over-HTTPS (DoH) server that hands out per-customer keys** (create / remove / list, with expiry).

| File | Purpose |
|---|---|
| `DNS_doHGame_installed_fixed.sh` | The manager: install, ports, access control, DoH key server, key panel, status |
| `DNS_Security_Check_fixed.sh` | Security / health check for one or more ports (cron-friendly, exit code 1 on failure) |
| `Test_DNS_fixed.sh` | Latency benchmark: your server vs Cloudflare vs Google on gaming domains |

---

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [The menu](#the-menu)
- [Ports (53 and/or custom)](#ports-53-andor-custom)
- [Access control](#access-control)
- [DoH key server](#doh-key-server)
- [Admin API](#admin-api)
- [Check and benchmark scripts](#check-and-benchmark-scripts)
- [Files and paths](#files-and-paths)
- [Security notes](#security-notes)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)
- [Status and limitations](#status-and-limitations)

---

## Features

- **Unbound** recursive resolver with DNSSEC validation, caching, prefetching and hardening.
- **Multiple ports at once** – standard port 53 *and* any custom ports, chosen interactively.
- **Access control** – open (rate-limited), restricted to your IPs/CIDRs, or DoH-only.
- **DoH key server** – customers get a URL like `https://dns.example.com/dns-query/<key>`; keys expire, can be revoked, and are rate-limited per key.
- **Admin API + key panel** – create/remove/list keys from a Telegram bot (HTTP API) or locally from the menu.
- **HTTPS automatically** – nginx front end with a Let's Encrypt certificate that renews itself.
- **Firewall handled** – `ufw` rules are added for the ports you choose and removed when you stop using them; your SSH port is always allowed.
- **Port-conflict helper** – if a port is taken, the script shows which service holds it and offers to stop it.
- **Honest checks** – the check script reports real PASS/FAIL and a proper exit code.

## Requirements

- Debian or Ubuntu with `apt`, `systemd` and root access (`sudo`).
- For the DoH key server only:
  - A **domain name whose A record points at this server** (before you install).
  - **Port 80 free** and reachable from the internet (Let's Encrypt validation and renewals).
  - A free HTTPS port for DoH (default 443) and one for the admin API (default 11112).

Packages (`unbound`, `dnsutils`, `ufw`, and for DoH `nginx`, `certbot`, `python3`, `curl`, `openssl`) are installed by the script.
Node.js is **not** needed – the key server is a small Python program using only the standard library.

## Quick start

```bash
# 1. Get the three scripts into one folder (the menu's check/benchmark options look there)
chmod +x *.sh

# 2. Run the manager
sudo bash DNS_doHGame_installed_fixed.sh
```

Choose **1) Install / full setup**. You will be asked:

1. Listen on standard port 53? `[Y/n]`
2. Custom port(s), comma-separated (blank for none)
3. Who may query: everyone / only specific IPs / DoH keys only
4. *Set up the DoH key server now?* `[y/N]` – if yes: domain, email, DoH port, admin port, admin IP restriction

Your answers are saved in `/etc/unbound/gamedns.settings` and reused by the menu.

**Command-line shortcuts**

```bash
sudo bash DNS_doHGame_installed_fixed.sh            # menu
sudo bash DNS_doHGame_installed_fixed.sh install    # straight to full install
sudo bash DNS_doHGame_installed_fixed.sh doh        # install / reconfigure the DoH key server
sudo bash DNS_doHGame_installed_fixed.sh keys       # open the key panel
sudo bash DNS_doHGame_installed_fixed.sh status     # show status and exit
```

**Non-interactive install** (skips the port and access prompts):

```bash
DNS_PORTS="53,5300" ALLOWED_CLIENTS="203.0.113.0/24" \
  sudo -E bash DNS_doHGame_installed_fixed.sh install
```

Optional environment variables: `DNS_PORTS`, `ALLOWED_CLIENTS`, `IP_RATELIMIT` (default 200), `SSH_PORT` (auto-detected).

To edit any script with vi: `vi DNS_doHGame_installed_fixed.sh`

## The menu

```
=========== Unbound DNS Manager ===========
  1) Install / full setup
  2) Change listening ports (53 and/or custom)
  3) Change who may query (access control)
  4) Show status
  5) Run security check
  6) Run speed test
  7) Install / reconfigure DoH key server (nginx + Let's Encrypt)
  8) Key panel (create / remove / list keys)
  0) Exit
```

If an action fails you are returned to the menu; nothing closes the script.
Options 5 and 6 need `DNS_Security_Check_fixed.sh` and `Test_DNS_fixed.sh` in the same folder as the manager (or the current folder).

## Ports (53 and/or custom)

Unbound gets one `interface: 0.0.0.0@<port>` line per port you choose, over both UDP and TCP.

- **Port 53 included:** the script disables the `systemd-resolved` stub listener (it otherwise holds port 53) and points the server's own `/etc/resolv.conf` at Unbound.
- **Custom ports only:** `systemd-resolved` and `/etc/resolv.conf` are left alone (resolv.conf cannot name a port).
- **Dropping port 53 later:** the script restores the host's resolver so the server does not lose name resolution.
- Your SSH port is refused as a DNS port; a port already held by another service is refused.

> **Client compatibility:** phones, consoles and most routers can only use plain DNS on **port 53**.
> A custom port works only with clients that let you set one (`dig -p`, dnsmasq, some apps).
> For everything else use port 53 or the DoH URLs below. Android's built-in *Private DNS* uses DoT, which this project does not provide.

## Access control

Menu option 3 (also asked during install):

| Choice | Effect |
|---|---|
| **1) Everyone** | Open resolver, rate-limited. Convenient, but open resolvers can be abused for DDoS amplification and may get the server suspended by your host. |
| **2) Only specific IPs / CIDRs** | Recommended for plain DNS. Include the IP you test from, or you will get `REFUSED`. |
| **3) Nobody from outside** | Plain DNS answers only the server itself. With the DoH key server on, keys become the only way in. |

The Unbound config always ends up default-deny (`access-control: 0.0.0.0/0 refuse`) followed by the allowed ranges.
Abuse protection: `ip-ratelimit` (default 200 queries/s per IP), `ratelimit: 1000`, `deny-any`, minimal responses.

## DoH key server

Enable it with menu option 7 (or answer `y` at the end of the full install).

```
Client ──HTTPS──▶ nginx (TLS, HTTP/2) ──▶ gamedns_doh.py (checks key, rate-limits) ──▶ Unbound
                     │
Telegram bot ─HTTPS─▶ nginx ─────────────▶ Admin API (bearer token)
```

- **Customer URL:** `https://<domain>[:<port>]/dns-query/<key>` (the port is omitted when it is 443).
- Keys are 22 random URL-safe characters (128 bits), stored with expiry, optional Telegram ID and a note in `/var/lib/gamedns/keys.json` (no database).
- An unknown, expired, malformed or removed key gets `403`. Over the limit (100 queries/s per key) gets `429`.
- The service runs as an unprivileged `gamedns` user, sandboxed by systemd, listening only on `127.0.0.1`; nginx is the only public entry.
- nginx access logging is **off** because request URLs contain keys.
- The install ends with a self-test: it creates a temporary key, resolves a real query through Unbound, and deletes the key.

### Key panel (menu option 8)

```
1) Create key       – Telegram ID (optional), days (1–3650), note
2) Remove key
3) List keys        – shows active / EXPIRED
4) Remove expired keys
5) Show server info + API examples + token
6) Rotate admin token
```

Keys changed in the panel or via the API take effect immediately, with no restart.

### Testing a key

```bash
# curl's built-in DoH support
curl --doh-url https://dns.example.com/dns-query/<key> https://example.com -I

# raw DoH GET (query for example.com A)
curl -s "https://dns.example.com/dns-query/<key>?dns=AAABAAABAAAAAAAAB2V4YW1wbGUDY29tAAABAAE" | xxd | head
```

Firefox, Chrome, Intra and iOS DoH profiles can use the URL directly.

## Admin API

Base URL: `https://<domain>:<admin-port>` – every request needs `Authorization: Bearer <token>`.
The token is generated at install and shown by key panel option 5 (rotate it with option 6).

| Method | Path | Body | Result |
|---|---|---|---|
| `POST` | `/create` | `{"telegramId": 123456789, "days": 30, "note": "optional"}` | `{"key", "telegramId", "expires", "url"}` |
| `POST` | `/remove` | `{"key": "<key>"}` | `{"removed": true}` (404 if unknown) |
| `GET` | `/list` | – | all keys with expiry and `active` flag |
| `POST` | `/purge` | – | removes expired keys, returns the count |

```bash
curl -X POST https://dns.example.com:11112/create \
  -H "Authorization: Bearer <token>" -H "Content-Type: application/json" \
  -d '{"telegramId": 123456789, "days": 30}'

curl -X POST https://dns.example.com:11112/remove \
  -H "Authorization: Bearer <token>" -H "Content-Type: application/json" \
  -d '{"key": "<key>"}'

curl https://dns.example.com:11112/list -H "Authorization: Bearer <token>"
```

Restrict the admin port to your bot server's IP when the installer asks – the token then is not the only protection.

## Check and benchmark scripts

**Security / health check** – tests, per port: UDP and TCP reachability, hidden `version.bind`/`id.server`, resolution of normal and gaming domains, DNSSEC (valid zone returns the `ad` flag, `dnssec-failed.org` must return `SERVFAIL`), a 400-query burst for rate limiting, open-resolver notice, and cold/cached latency.

```bash
./DNS_Security_Check_fixed.sh <server-ip> 53,5300
DNS_SERVER=203.0.113.5 DNS_PORT=53,5300 ./DNS_Security_Check_fixed.sh

# weekly, non-interactive (exit code 1 on any failure)
0 4 * * 1  /root/DNS_Security_Check_fixed.sh 203.0.113.5 53,5300 >> /var/log/dns_check.log 2>&1
```

Test against `127.0.0.1` from the server itself (always allowed). A restricted server will answer `REFUSED` to other addresses, which is correct.

**Benchmark:**

```bash
./Test_DNS_fixed.sh <server-ip> [port]
```

Prints a per-domain table (your server cold/warm, Cloudflare, Google) and averages, ignoring failed queries.

## Files and paths

| Path | What |
|---|---|
| `/etc/unbound/unbound.conf.d/gamedns.conf` | Generated Unbound config (backups: `gamedns.conf.bak.<timestamp>`) |
| `/etc/unbound/gamedns.settings` | Saved ports, access list, DoH settings |
| `/var/lib/unbound/root.key` | DNSSEC trust anchor |
| `/opt/gamedns/gamedns_doh.py` | DoH proxy + admin API + key CLI (written by the manager) |
| `/etc/gamedns/doh.env` | Key-server config and admin token (mode 640, `root:gamedns`) |
| `/var/lib/gamedns/keys.json` | Key database (mode 600) |
| `/etc/nginx/conf.d/gamedns-doh.conf` | nginx TLS front end |
| `/etc/systemd/system/gamedns-doh.service` | Key-server service |
| `/etc/letsencrypt/renewal-hooks/deploy/gamedns-reload.sh` | Reloads nginx after certificate renewal |

Useful commands:

```bash
journalctl -u unbound -f            # DNS server log
journalctl -u gamedns-doh -f        # key server log
unbound-checkconf                   # validate the Unbound config
ss -tulnp | grep -E 'unbound|nginx' # what is listening
sudo ufw status verbose             # firewall rules
```

## Security notes

- **Keep the bearer token secret** – it gates `/create` and `/remove`. Rotate it from the key panel.
- **Keys are bearer credentials in a URL.** Anyone with the URL can use the key until it expires or is removed. Use short expiries for trials.
- **Don't leave plain DNS open** if the DoH keys are meant to gate access – use access option 3 (or option 2 with your own IPs).
- With DoH on, Unbound's per-IP rate limit is raised to 20000 because every DoH user reaches it from `127.0.0.1`; the per-key limit in the proxy takes over for DoH traffic.
- Rate limits and hardening reduce, but do not remove, the risk of running a public resolver.
- Error logs of nginx can still contain request URLs in rare failure cases; treat server logs as sensitive.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Port N is already in use` | The script shows the process and offers to stop the service (or pick another port). nginx sharing a port is allowed. |
| Unbound won't start on 53 | Something else holds it – run `ss -tulnp \| grep ':53 '`. On Ubuntu it is normally `systemd-resolved` (the script handles it). |
| `REFUSED` from `dig` | Your IP isn't in the access list. Menu option 3, or test from `127.0.0.1`. |
| Certificate request failed | The domain's A record doesn't point here, or port 80 isn't reachable from the internet (check provider firewall too). |
| DoH returns `403` | Key is wrong, expired or removed – check with key panel option 3. |
| DoH returns `429` | That key exceeded 100 queries/s. |
| DoH returns `502` | The key server can't reach Unbound – check `systemctl status unbound` and the upstream port in `/etc/gamedns/doh.env`. |
| Phone/console can't use the custom port | Those devices only support port 53 (see [Ports](#ports-53-andor-custom)). |
| Locked out after enabling ufw | The script always allows the detected SSH port; if you use a non-standard port set `SSH_PORT=<port>`. |

## Uninstall

There is no uninstall menu entry yet. Manually:

```bash
# DoH key server (this DELETES all keys)
sudo systemctl disable --now gamedns-doh
sudo rm -f /etc/systemd/system/gamedns-doh.service /etc/nginx/conf.d/gamedns-doh.conf
sudo rm -rf /opt/gamedns /etc/gamedns /var/lib/gamedns
sudo userdel gamedns
sudo systemctl daemon-reload && sudo systemctl reload nginx

# Unbound settings from this project
sudo rm -f /etc/unbound/unbound.conf.d/gamedns.conf /etc/unbound/gamedns.settings
sudo systemctl restart unbound        # or: sudo apt remove unbound

# If port 53 was used: give systemd-resolved its stub listener back
sudo rm -f /etc/systemd/resolved.conf.d/nostub.conf
sudo systemctl restart systemd-resolved
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Firewall: review and delete the rules you no longer need
sudo ufw status numbered
```

## Status and limitations

- The Python key server (`gamedns_doh.py`) was tested end-to-end against a mock DNS upstream: key create/remove/list/purge, DoH GET and POST, unknown/expired/removed keys, admin API authentication, per-key rate limiting, live reload of the key file, and UDP→TCP fallback.
- The prompts, port checks, generated Unbound and nginx configuration, and the key panel were tested with simulated input.
- **Not yet verified on a real server:** package installation, Let's Encrypt issuance, nginx/systemd startup, and `ufw` changes. Try it on a fresh VPS before production use.
- IPv4 only (`do-ip6: no`).
- DoH only; **no DoT (port 853)**, so Android Private DNS is not supported.
- The port-conflict helper covers the DoH, admin and port 80 checks; the plain-DNS port checks still report an error without offering to stop the blocking service.
- No uninstall command yet (see above).
