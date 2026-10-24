#!/usr/bin/env bash
#
# outline-health.sh - Health check (and optional repair) for an Outline VPN server
#
# Supported platforms (systemd-based Linux with Docker Engine):
#   Ubuntu 20.04+, Debian 11+, AlmaLinux / Rocky Linux / CentOS Stream / RHEL 8+,
#   Fedora, Arch Linux (and derivatives that report one of these in ID_LIKE).
# Not supported (detected, explained, exit code 3):
#   FreeBSD, Windows - the Outline server (shadowbox) is a Linux container image.
#
# Usage:
#   sudo ./outline-health.sh                  # check only, nothing is changed
#   sudo ./outline-health.sh --fix-all        # check and try to fix every problem found
#   sudo ./outline-health.sh --install-deps   # also install missing helper tools
#   curl -fsSL <SCRIPT_URL> | sudo bash -s -- --fix-all    # run without saving the file
#
# Exit codes: 0 = healthy, 1 = unresolved problem, 2 = bad arguments,
#             3 = unsupported platform.
#
# Edit with:  vi outline-health.sh

set -u
export LC_ALL=C   # stable, English tool output so the parsing below is reliable

SCRIPT_VERSION="2.0.0"

# ---------- Configuration (override via environment) ----------
OUTLINE_DIR="${OUTLINE_DIR:-/opt/outline}"
STATE_DIR="${STATE_DIR:-$OUTLINE_DIR/persisted-state}"
CONTAINERS=("shadowbox" "watchtower")
DISK_WARN_PCT="${DISK_WARN_PCT:-90}"
MEM_WARN_PCT="${MEM_WARN_PCT:-90}"
API_TIMEOUT="${API_TIMEOUT:-10}"
WT_API_VERSION="${WT_API_VERSION:-}"   # empty = auto-detect from the Docker daemon
SCRIPT_URL="${SCRIPT_URL:-https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/outline-health.sh}"
OUTLINE_INSTALLER_URL="${OUTLINE_INSTALLER_URL:-https://raw.githubusercontent.com/Jigsaw-Code/outline-apps/master/server_manager/install_scripts/install_server.sh}"
# Several endpoints so one blocked/filtered site does not cause a false failure.
CHECK_URLS="${CHECK_URLS:-https://www.google.com https://www.cloudflare.com https://github.com}"
CHECK_HOSTS="${CHECK_HOSTS:-www.google.com www.cloudflare.com github.com}"

# ---------- State ----------
FIX_ALL=0
INSTALL_DEPS=0
USE_COLOR=1
ISSUES=0     # problems found
UNFIXED=0    # problems still present after (optional) fixing

OS_ID="unknown"      # os-release ID, e.g. ubuntu, debian, almalinux, rocky, centos, arch
OS_VER=""            # os-release VERSION_ID, e.g. 24.04, 12, 9.0
OS_NAME="unknown"
OS_FAMILY="unknown"  # debian | rhel | arch | linux-other | freebsd | windows | unknown
PKG_MGR=""           # apt-get | dnf | yum | pacman | ""
API_URL=""; API_PORT=""; KEY_PORT=""

C_OK=""; C_BAD=""; C_WARN=""; C_OFF=""

# ---------- Output helpers ----------

# Usage: setup_colors -> enables ANSI colours when stdout is a terminal and
#   neither --no-color nor the NO_COLOR environment variable was given
setup_colors() {
  if [[ -t 1 && -z "${NO_COLOR:-}" && $USE_COLOR -eq 1 ]]; then
    C_OK=$'\e[32m'; C_BAD=$'\e[31m'; C_WARN=$'\e[33m'; C_OFF=$'\e[0m'
  fi
}

# Usage: log_ok "message"  -> prints a green [ OK ] line
log_ok()   { echo "${C_OK}[ OK ]${C_OFF} $*"; }

# Usage: log_warn "message" -> prints a yellow [WARN] line
log_warn() { echo "${C_WARN}[WARN]${C_OFF} $*"; }

# Usage: log_bad "message"  -> prints a red [FAIL] line and counts it as an issue
log_bad()  { echo "${C_BAD}[FAIL]${C_OFF} $*"; ISSUES=$((ISSUES + 1)); }

# Usage: log_info "message" -> prints an indented informational line
log_info() { echo "       $*"; }

# Usage: section "Title" -> prints a section header
section()  { echo; echo "== $* =="; }

# Usage: usage -> prints the help text
usage() {
  cat <<EOF
outline-health.sh $SCRIPT_VERSION - health check (and optional repair) for an Outline VPN server

Usage:
  sudo ./outline-health.sh [options]

Options:
  --fix-all        check and try to fix every problem found
  --install-deps   install missing helper tools (curl, ss) with the system package manager
  --no-color       disable coloured output (the NO_COLOR variable is honoured too)
  --version        print the script version
  -h, --help       show this help

Exit codes: 0 healthy, 1 unresolved problem, 2 bad arguments, 3 unsupported platform.
Supported: Ubuntu, Debian, AlmaLinux, Rocky Linux, CentOS Stream, RHEL, Fedora, Arch Linux.
EOF
}

# ---------- Fix helper ----------

# Usage: try_fix "description" command [args...]
#   Runs the command only when --fix-all was given; otherwise prints a hint.
#   Returns 0 if the fix ran and succeeded, 1 otherwise.
try_fix() {
  local desc="$1"; shift
  if [[ $FIX_ALL -ne 1 ]]; then
    log_info "fix available (use --fix-all): $desc"
    return 1
  fi
  log_info "fixing: $desc"
  if "$@" >/dev/null 2>&1; then
    log_info "fixed: $desc"
    return 0
  fi
  log_info "fix FAILED: $desc"
  return 1
}

# Usage: mark_unfixed -> call when a problem remains after the fix attempt
mark_unfixed() { UNFIXED=$((UNFIXED + 1)); }

# ---------- Utility ----------

# Usage: have <command> -> returns 0 if the command exists
have() { command -v "$1" >/dev/null 2>&1; }

# Usage: rerun_hint [flags...] -> prints a command line that re-runs this script as root,
#   whether it was started from a saved file or piped from curl / process substitution
rerun_hint() {
  if [[ -f "$0" ]]; then echo "sudo bash $0 $*"
  else echo "curl -fsSL $SCRIPT_URL | sudo bash -s -- $*"; fi
}

# Usage: has_systemd -> returns 0 when systemd is the running init system
has_systemd() { have systemctl && [[ -d /run/systemd/system ]]; }

# Usage: svc_action <start|restart|stop> <service> -> manages a service via systemd or SysV `service`
svc_action() {
  if has_systemd; then systemctl "$1" "$2"
  elif have service; then service "$2" "$1"
  else return 1; fi
}

# Usage: docker_ok -> returns 0 if the Docker daemon answers (bounded so a hung daemon cannot block us)
docker_ok() {
  if have timeout; then timeout 15 docker info >/dev/null 2>&1
  else docker info >/dev/null 2>&1; fi
}

# Usage: os_release_get <KEY> -> prints a value from os-release (e.g. ID, VERSION_ID, ID_LIKE)
#   without sourcing the file, so it cannot clobber this script's own variables.
os_release_get() {
  local f="${OS_RELEASE_FILE:-/etc/os-release}"
  [[ -r "$f" ]] || return 1
  sed -n "s/^$1=//p" "$f" | head -n1 | tr -d '"'
}

# Usage: port_listening <tcp|udp> <port> -> returns 0 if something listens on it.
#   Uses `ss` when present, otherwise falls back to /proc/net so no extra package is needed.
port_listening() {
  local proto="$1" port="$2" flag="-ltn"
  [[ "$proto" == "udp" ]] && flag="-lun"
  if have ss; then
    ss $flag 2>/dev/null | awk 'NR>1{print $4}' | grep -Eq "[:.]${port}\$"
  else
    proc_port_listening "$proto" "$port"
  fi
}

# Usage: proc_port_listening <tcp|udp> <port> -> /proc/net based listener check (IPv4 and IPv6)
proc_port_listening() {
  local proto="$1" port="$2" hex state f
  hex=$(printf '%04X' "$port")
  if [[ "$proto" == "tcp" ]]; then state="0A"; else state="07"; fi   # LISTEN / unconnected UDP
  for f in "/proc/net/$proto" "/proc/net/${proto}6"; do
    [[ -r "$f" ]] || continue
    awk -v h=":$hex" -v s="$state" \
      'NR>1 && $2 ~ (h "$") && $4 == s {found=1} END{exit !found}' "$f" && return 0
  done
  return 1
}

# Usage: json_get <file> <key> -> prints a top-level JSON value (uses jq if present)
json_get() {
  local file="$1" key="$2"
  [[ -r "$file" ]] || return 1
  if have jq; then
    jq -r --arg k "$key" '.[$k] // empty' "$file" 2>/dev/null
  else
    grep -Eo "\"$key\"[[:space:]]*:[[:space:]]*\"?[^\",}]*" "$file" \
      | head -n1 | sed -E 's/.*:[[:space:]]*"?//'
  fi
}

# ---------- Platform detection ----------

# Usage: detect_os -> fills OS_ID, OS_VER, OS_NAME, OS_FAMILY and PKG_MGR
detect_os() {
  local kernel like
  kernel=$(uname -s 2>/dev/null || echo unknown)
  case "$kernel" in
    Linux) ;;
    FreeBSD)
      OS_FAMILY="freebsd"; OS_ID="freebsd"; OS_VER=$(uname -r 2>/dev/null)
      OS_NAME="FreeBSD $OS_VER"; return 0 ;;
    MINGW*|MSYS*|CYGWIN*|Windows*)
      OS_FAMILY="windows"; OS_ID="windows"; OS_NAME="Windows ($kernel)"; return 0 ;;
    *)
      OS_FAMILY="unknown"; OS_ID="$kernel"; OS_NAME="$kernel"; return 0 ;;
  esac

  OS_ID=$(os_release_get ID); OS_ID="${OS_ID:-linux}"
  OS_VER=$(os_release_get VERSION_ID)
  like=$(os_release_get ID_LIKE)
  OS_NAME=$(os_release_get PRETTY_NAME); OS_NAME="${OS_NAME:-$OS_ID $OS_VER}"

  case " $OS_ID $like " in
    *" ubuntu "*|*" debian "*)                                               OS_FAMILY="debian" ;;
    *" rhel "*|*" centos "*|*" fedora "*|*" almalinux "*|*" rocky "*)        OS_FAMILY="rhel" ;;
    *" arch "*|*" archlinux "*)                                              OS_FAMILY="arch" ;;
    *)                                                                       OS_FAMILY="linux-other" ;;
  esac

  if   have apt-get; then PKG_MGR="apt-get"
  elif have dnf;     then PKG_MGR="dnf"
  elif have yum;     then PKG_MGR="yum"
  elif have pacman;  then PKG_MGR="pacman"
  fi
}

# Usage: platform_gate -> exits with code 3 on platforms that cannot run Outline,
#   warns (but continues) on unrecognised Linux distributions and old releases
platform_gate() {
  case "$OS_FAMILY" in
    freebsd)
      log_bad "unsupported platform: $OS_NAME"
      log_info "Outline's server (shadowbox) ships as a Linux container image and"
      log_info "FreeBSD has no supported Docker Engine to run it."
      log_info "Run Outline on a Linux host (Ubuntu, Debian, Alma, Rocky, CentOS Stream, Arch)."
      exit 3 ;;
    windows)
      log_bad "unsupported platform: $OS_NAME"
      log_info "Outline's server (shadowbox) is a Linux container image; Docker on"
      log_info "Windows Server runs Windows containers by default, so this is not a"
      log_info "supported way to host Outline. Use a Linux host or a Linux VM instead."
      exit 3 ;;
    unknown)
      log_bad "unsupported platform: $OS_NAME (a Linux host is required)"
      exit 3 ;;
    linux-other)
      log_warn "unrecognised Linux distribution '$OS_ID'; checks run, but package install hints are limited" ;;
  esac

  local major min=""
  major="${OS_VER%%.*}"
  case "$OS_ID" in
    ubuntu) min=20 ;;
    debian) min=11 ;;
    almalinux|rocky|centos|rhel) min=8 ;;
  esac
  if [[ -n "$min" && "$major" =~ ^[0-9]+$ && "$major" -lt "$min" ]]; then
    log_warn "$OS_NAME is older than the supported baseline ($OS_ID $min+); results may be unreliable"
  fi
  if [[ -r /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    log_warn "WSL detected: systemd, firewall and port checks may not reflect a real server"
  fi
}

# ---------- Package helpers ----------

# Usage: pkg_for <command> -> prints the distro package that provides the command
pkg_for() {
  case "$1:$OS_FAMILY" in
    ss:rhel) echo "iproute" ;;
    ss:*)    echo "iproute2" ;;
    *)       echo "$1" ;;
  esac
}

# Usage: pkg_install <package...> -> installs packages non-interactively with the native manager
pkg_install() {
  case "$PKG_MGR" in
    apt-get) apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" ;;
    dnf)     dnf install -y "$@" ;;
    yum)     yum install -y "$@" ;;
    pacman)  pacman -S --noconfirm --needed "$@" ;;
    *)       return 1 ;;
  esac
}

# Usage: pkg_install_hint <package> -> prints the manual install command for this distro
pkg_install_hint() {
  case "$PKG_MGR" in
    apt-get) echo "sudo apt-get install -y $1" ;;
    dnf)     echo "sudo dnf install -y $1" ;;
    yum)     echo "sudo yum install -y $1" ;;
    pacman)  echo "sudo pacman -S --needed $1" ;;
    *)       echo "install '$1' with your package manager" ;;
  esac
}

# Usage: docker_install_hint -> prints how to get Docker Engine on this distro
docker_install_hint() {
  if [[ "$OS_FAMILY" == "arch" ]]; then
    echo "sudo pacman -S docker && sudo systemctl enable --now docker"
  else
    echo "curl -fsSL https://get.docker.com | sudo sh   (or re-run the Outline installer, which installs Docker)"
  fi
}

# Usage: ensure_tool <command> [required=1] -> reports a tool, installs it when allowed
#   (--install-deps or --fix-all), otherwise prints the exact install command.
#   Returns 0 when the tool is available afterwards.
ensure_tool() {
  local cmd="$1" required="${2:-1}" pkg
  if have "$cmd"; then log_ok "$cmd found"; return 0; fi
  pkg=$(pkg_for "$cmd")
  if [[ "$required" -eq 1 ]]; then log_bad "$cmd not installed"
  else log_warn "$cmd not installed (optional, using a built-in fallback)"; fi
  if [[ $INSTALL_DEPS -eq 1 || $FIX_ALL -eq 1 ]]; then
    log_info "installing package '$pkg' via ${PKG_MGR:-no package manager}"
    if pkg_install "$pkg" >/dev/null 2>&1 && have "$cmd"; then
      log_ok "$cmd installed"; return 0
    fi
    log_info "install FAILED for '$pkg'"
  else
    log_info "fix: $(pkg_install_hint "$pkg")   (or re-run with --install-deps)"
  fi
  [[ "$required" -eq 1 ]] && mark_unfixed
  return 1
}

# ---------- Checks ----------

# Usage: check_prereqs -> verifies root, core tools and a real Docker Engine (not the Podman shim)
check_prereqs() {
  section "Prerequisites"
  log_info "platform: $OS_NAME [family: $OS_FAMILY, package manager: ${PKG_MGR:-none}]"
  if [[ $EUID -ne 0 ]]; then
    log_bad "not running as root"
    log_info "run: $(rerun_hint "$([[ $FIX_ALL -eq 1 ]] && echo --fix-all)")"
    mark_unfixed
    exit 1
  fi
  log_ok "running as root"

  local c
  for c in awk sed grep df; do ensure_tool "$c" 1 || true; done
  ensure_tool curl 1 || true
  ensure_tool ss 0 || true

  if ! have docker; then
    log_bad "docker not installed"
    log_info "install: $(docker_install_hint)"
    mark_unfixed
    echo "docker is required, aborting."; exit 1
  fi
  log_ok "docker found"

  # On RHEL-family systems 'docker' may be the podman-docker shim, which Outline does not support
  if { docker --version 2>&1; } | grep -qi podman; then
    log_bad "'docker' is a Podman emulation layer; Outline needs Docker Engine"
    log_info "install Docker Engine (docker-ce): $(docker_install_hint)"
    mark_unfixed
  fi
}

# Usage: check_docker_daemon -> checks the Docker service is running and enabled at boot
check_docker_daemon() {
  section "Docker daemon"
  if docker_ok; then
    log_ok "docker daemon is responding"
  else
    log_bad "docker daemon is not responding"
    if try_fix "start docker" svc_action start docker && sleep 3 && docker_ok; then
      log_ok "docker daemon now running"
    else
      mark_unfixed
      return 1
    fi
  fi
  if has_systemd; then
    if systemctl is-enabled docker >/dev/null 2>&1; then
      log_ok "docker enabled at boot"
    else
      log_bad "docker not enabled at boot"
      try_fix "enable docker at boot" systemctl enable docker || mark_unfixed
    fi
  else
    log_info "systemd not detected; skipping boot-enable check"
  fi
}

# Usage: api_too_old <container> -> returns 0 if its recent logs show the
#   "client version ... is too old" Docker API error (old watchtower image vs new Docker)
api_too_old() { docker logs --tail 20 "$1" 2>&1 | grep -q "is too old"; }

# Usage: detect_api_version -> prints the Docker API version to force on watchtower.
#   Order: $WT_API_VERSION override > daemon's minimum supported API (always accepted)
#   > version quoted in watchtower's error log > daemon's current API version.
detect_api_version() {
  local v="${WT_API_VERSION:-}"
  [[ -z "$v" ]] && v=$(docker version -f '{{.Server.MinAPIVersion}}' 2>/dev/null)
  [[ -z "$v" ]] && v=$(docker logs --tail 20 watchtower 2>&1 \
        | grep -o 'Minimum supported API version is [0-9.]*' | head -n1 | grep -o '[0-9.]*$')
  [[ -z "$v" ]] && v=$(docker version -f '{{.Server.APIVersion}}' 2>/dev/null)
  echo "$v"
}

# Usage: recreate_watchtower -> removes and re-adds the watchtower container with the
#   same image, command, mounts and log driver, plus -e DOCKER_API_VERSION=<detected>.
#   The old container config is saved to /root/watchtower-inspect-backup.json first.
recreate_watchtower() {
  local image logdrv b l apiv
  local -a binds=() cmd=() args=()
  apiv=$(detect_api_version)
  [[ -z "$apiv" ]] && { echo "cannot detect Docker API version" >&2; return 1; }
  image=$(docker inspect -f '{{.Config.Image}}' watchtower) || return 1
  logdrv=$(docker inspect -f '{{.HostConfig.LogConfig.Type}}' watchtower)
  docker inspect watchtower > /root/watchtower-inspect-backup.json 2>/dev/null

  # while-read instead of mapfile: works on bash 3.2+ as well as bash 5
  while IFS= read -r b; do [[ -n "$b" ]] && binds+=("$b"); done \
    < <(docker inspect -f '{{range .HostConfig.Binds}}{{println .}}{{end}}' watchtower)
  while IFS= read -r b; do [[ -n "$b" ]] && cmd+=("$b"); done \
    < <(docker inspect -f '{{range .Config.Cmd}}{{println .}}{{end}}' watchtower)
  [[ ${#binds[@]} -eq 0 ]] && binds=("/var/run/docker.sock:/var/run/docker.sock")
  [[ ${#cmd[@]} -eq 0 ]] && cmd=(--cleanup --label-enable --interval 3600)

  # Keep Outline's opt-in label if the old container had it
  l=$(docker inspect -f '{{index .Config.Labels "com.centurylinklabs.watchtower.enable"}}' watchtower 2>/dev/null)
  [[ -n "$l" ]] && args+=(--label "com.centurylinklabs.watchtower.enable=$l")
  for b in "${binds[@]}"; do args+=(-v "$b"); done
  [[ -n "$logdrv" ]] && args+=(--log-driver "$logdrv")

  docker rm -f watchtower || return 1
  docker run -d --name watchtower --restart always \
    -e "DOCKER_API_VERSION=$apiv" ${args[@]+"${args[@]}"} "$image" "${cmd[@]}"
}

# Usage: check_container <name> -> checks existence, running state, restart policy, crash loops
check_container() {
  local name="$1" state policy restarts
  if ! docker inspect "$name" >/dev/null 2>&1; then
    log_bad "container '$name' does not exist"
    log_info "re-run the Outline installer to recreate it:"
    log_info "sudo bash -c \"\$(curl -fsSL $OUTLINE_INSTALLER_URL)\""
    mark_unfixed
    return 1
  fi

  state=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null)
  if [[ "$state" == "running" ]] && ! api_too_old "$name"; then
    log_ok "container '$name' is running ($(docker inspect -f '{{.State.StartedAt}}' "$name" | cut -c1-19) UTC)"
  else
    log_bad "container '$name' is '$state'"
    if [[ "$name" == "watchtower" ]] && api_too_old "$name"; then
      # A plain restart can never fix this: the container must be recreated
      log_info "cause: watchtower's Docker API client is too old for this Docker engine"
      if try_fix "recreate watchtower with DOCKER_API_VERSION=$(detect_api_version)" recreate_watchtower; then
        sleep 15
        if [[ "$(docker inspect -f '{{.State.Status}}' watchtower 2>/dev/null)" == "running" ]] && ! api_too_old watchtower; then
          log_ok "watchtower recreated and stays up"
        else
          log_bad "watchtower still failing after recreate"
          docker logs --tail 8 watchtower 2>&1 | sed 's/^/         | /'
          mark_unfixed
        fi
      else
        mark_unfixed
      fi
    elif try_fix "start/restart $name" docker restart "$name"; then
      # A restart can "succeed" and the container still crash again, so wait and re-check
      sleep 15
      if [[ "$(docker inspect -f '{{.State.Status}}' "$name")" == "running" ]]; then
        log_ok "container '$name' stayed up after restart"
      else
        log_bad "container '$name' crashed again right after restart"
        log_info "last log lines (docker logs $name):"
        docker logs --tail 8 "$name" 2>&1 | sed 's/^/         | /'
        mark_unfixed
      fi
    else
      log_info "last log lines (docker logs $name):"
      docker logs --tail 8 "$name" 2>&1 | sed 's/^/         | /'
      mark_unfixed
    fi
  fi

  policy=$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' "$name" 2>/dev/null)
  if [[ "$policy" == "always" || "$policy" == "unless-stopped" ]]; then
    log_ok "'$name' restart policy: $policy"
  else
    log_bad "'$name' restart policy is '${policy:-none}' (should be always)"
    try_fix "set restart policy=always on $name" docker update --restart=always "$name" || mark_unfixed
  fi

  restarts=$(docker inspect -f '{{.RestartCount}}' "$name" 2>/dev/null || echo 0)
  if [[ "${restarts:-0}" -gt 5 ]]; then
    log_warn "'$name' restarted $restarts times (possible crash loop, check: docker logs $name)"
  fi
}

# Usage: check_containers -> runs check_container for every expected container
check_containers() {
  section "Docker containers"
  local c
  for c in "${CONTAINERS[@]}"; do check_container "$c" || true; done
}

# Usage: load_config -> reads API URL / ports from Outline's files into globals
load_config() {
  API_URL=""; API_PORT=""; KEY_PORT=""
  local access="$OUTLINE_DIR/access.txt"
  if [[ -r "$access" ]]; then
    API_URL=$(grep -E '^apiUrl:' "$access" | head -n1 | sed 's/^apiUrl://')
    API_PORT=$(echo "$API_URL" | sed -E 's#https?://[^:/]+:([0-9]+).*#\1#')
  fi
  KEY_PORT=$(json_get "$STATE_DIR/shadowbox_server_config.json" portForNewAccessKeys)
}

# Usage: check_config -> verifies Outline files exist and ports could be detected
check_config() {
  section "Outline configuration"
  if [[ -d "$OUTLINE_DIR" ]]; then log_ok "install dir $OUTLINE_DIR"
  else log_bad "install dir $OUTLINE_DIR missing"; mark_unfixed; fi

  if [[ -r "$OUTLINE_DIR/access.txt" ]]; then log_ok "access.txt present"
  else log_bad "access.txt missing/unreadable"; mark_unfixed; fi

  if [[ -r "$STATE_DIR/shadowbox_server_config.json" ]]; then log_ok "shadowbox_server_config.json present"
  else log_bad "shadowbox_server_config.json missing"; mark_unfixed; fi

  load_config
  if [[ -n "$API_PORT" ]]; then log_info "management API port: $API_PORT (tcp)"; else log_warn "could not detect API port"; fi
  if [[ -n "$KEY_PORT" ]]; then log_info "access key port:     $KEY_PORT (tcp+udp)"; else log_warn "could not detect access key port"; fi
}

# Usage: check_ports -> confirms API (tcp) and access-key (tcp+udp) ports are listening
check_ports() {
  section "Listening ports"
  if [[ -n "$API_PORT" ]]; then
    if port_listening tcp "$API_PORT"; then log_ok "API port $API_PORT/tcp listening"
    else
      log_bad "API port $API_PORT/tcp NOT listening"
      if try_fix "restart shadowbox" docker restart shadowbox; then
        sleep 5
        port_listening tcp "$API_PORT" || mark_unfixed
      else mark_unfixed; fi
    fi
  fi
  if [[ -n "$KEY_PORT" ]]; then
    local p
    for p in tcp udp; do
      if port_listening "$p" "$KEY_PORT"; then log_ok "key port $KEY_PORT/$p listening"
      else
        # Outline only opens the key port once at least one access key exists
        log_warn "key port $KEY_PORT/$p not listening (normal if no access keys exist yet)"
      fi
    done
  fi
}

# Usage: ufw_active -> returns 0 if ufw is installed and enabled (Ubuntu/Debian default tool)
ufw_active() { have ufw && ufw status 2>/dev/null | grep -q "Status: active"; }

# Usage: firewalld_active -> returns 0 if firewalld is running (RHEL-family default tool)
firewalld_active() { have firewall-cmd && firewall-cmd --state >/dev/null 2>&1; }

# Usage: fw_port_open <port> <tcp|udp> -> 0 if the local firewall allows it (or no firewall active)
fw_port_open() {
  local port="$1" proto="$2"
  if ufw_active; then
    ufw status | grep -Eq "^${port}(/${proto})?[[:space:]].*ALLOW"
    return $?
  fi
  if firewalld_active; then
    firewall-cmd --query-port="${port}/${proto}" >/dev/null 2>&1
    return $?
  fi
  return 0
}

# Usage: open_fw_port <port> <tcp|udp> -> opens the port with ufw or firewalld
open_fw_port() {
  local port="$1" proto="$2"
  if ufw_active; then
    ufw allow "${port}/${proto}"
  elif firewalld_active; then
    firewall-cmd --permanent --add-port="${port}/${proto}" && firewall-cmd --reload
  fi
}

# Usage: check_firewall -> verifies local firewall (ufw/firewalld) allows Outline ports
check_firewall() {
  section "Local firewall"
  if   ufw_active;       then log_info "firewall: ufw (active)"
  elif firewalld_active; then log_info "firewall: firewalld (running)"
  else log_info "no active ufw/firewalld; if you use raw nftables/iptables, verify the ports manually"
  fi
  local entry port proto
  for entry in "${API_PORT:-}:tcp" "${KEY_PORT:-}:tcp" "${KEY_PORT:-}:udp"; do
    port="${entry%%:*}"; proto="${entry##*:}"
    [[ -z "$port" ]] && continue
    if fw_port_open "$port" "$proto"; then
      log_ok "$port/$proto allowed"
    else
      log_bad "$port/$proto blocked by firewall"
      try_fix "open $port/$proto" open_fw_port "$port" "$proto" || mark_unfixed
    fi
  done
  log_info "note: cloud-provider firewalls/security groups must be checked in your provider's panel"
}

# Usage: check_api -> calls the Outline management API (GET /server) and validates the reply
check_api() {
  section "Management API"
  if [[ -z "$API_URL" ]]; then log_warn "no API URL known, skipping"; return; fi
  local out
  out=$(curl -sk --max-time "$API_TIMEOUT" "$API_URL/server" 2>/dev/null)
  if echo "$out" | grep -q '"serverId"'; then
    log_ok "API answered (server: $(echo "$out" | grep -o '"name":"[^"]*"' | head -n1))"
  else
    log_bad "API did not return a valid response"
    if try_fix "restart shadowbox" docker restart shadowbox; then
      sleep 8
      curl -sk --max-time "$API_TIMEOUT" "$API_URL/server" | grep -q '"serverId"' || mark_unfixed
    else mark_unfixed; fi
  fi
}

# Usage: check_network -> verifies outbound HTTPS and DNS from the host (passes if ANY
#   endpoint in $CHECK_URLS / $CHECK_HOSTS works, so one blocked site is not a false alarm)
check_network() {
  section "Network"
  local u h ok=0
  for u in $CHECK_URLS; do
    if curl -s --max-time 8 -o /dev/null "$u"; then ok=1; break; fi
  done
  if [[ $ok -eq 1 ]]; then log_ok "outbound HTTPS works"
  else log_bad "outbound HTTPS failed for all of: $CHECK_URLS"; mark_unfixed; fi

  ok=0
  for h in $CHECK_HOSTS; do
    if getent hosts "$h" >/dev/null 2>&1; then ok=1; break; fi
  done
  if [[ $ok -eq 1 ]]; then log_ok "DNS resolution works"
  else log_bad "DNS resolution failed for all of: $CHECK_HOSTS"; mark_unfixed; fi
}

# Usage: ntp_synced -> returns 0 if the clock is synchronised, 1 if not, 2 if it cannot be determined
ntp_synced() {
  local v=""
  if have timedatectl; then
    v=$(timedatectl show -p NTPSynchronized --value 2>/dev/null)
    [[ -z "$v" ]] && v=$(timedatectl 2>/dev/null | awk -F': ' '/System clock synchronized|NTP synchronized/{print $2; exit}')
    [[ -n "$v" ]] && { [[ "$v" == "yes" ]]; return; }
  fi
  if have chronyc; then
    chronyc tracking 2>/dev/null | grep -q 'Leap status.*Normal'
    return
  fi
  return 2
}

# Usage: check_resources -> checks disk, memory and time-sync status
check_resources() {
  section "System resources"
  local disk mem rc
  disk=$(df -P / | awk 'NR==2{gsub("%","",$5); print $5}')
  if [[ "$disk" -ge "$DISK_WARN_PCT" ]]; then
    log_bad "disk usage ${disk}%"
    try_fix "prune unused docker data" docker system prune -f || mark_unfixed
  else log_ok "disk usage ${disk}%"; fi

  # /proc/meminfo is present on every Linux (no dependency on procps' `free`)
  mem=$(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{if (t>0 && a!="") printf "%d", (t-a)*100/t}' /proc/meminfo 2>/dev/null)
  if [[ -z "$mem" ]]; then log_warn "memory usage could not be determined"
  elif [[ "$mem" -ge "$MEM_WARN_PCT" ]]; then log_warn "memory usage ${mem}%"
  else log_ok "memory usage ${mem}%"; fi

  ntp_synced; rc=$?
  if [[ $rc -eq 0 ]]; then
    log_ok "clock synchronized (NTP)"
  elif [[ $rc -eq 1 ]]; then
    log_bad "clock not NTP-synchronized (can break shadowsocks clients)"
    try_fix "enable NTP" timedatectl set-ntp true || mark_unfixed
  else
    log_warn "could not determine time-sync status (no timedatectl/chronyc)"
  fi
}

# Usage: check_logs -> scans the last 100 shadowbox log lines for errors
check_logs() {
  section "Recent shadowbox logs"
  docker inspect shadowbox >/dev/null 2>&1 || { log_warn "no shadowbox container"; return; }
  local errs
  errs=$(docker logs --tail 100 shadowbox 2>&1 | grep -Eic 'error|fatal|panic')
  if [[ "$errs" -gt 0 ]]; then log_warn "$errs error-like lines in last 100 log lines (docker logs shadowbox)"
  else log_ok "no errors in recent logs"; fi
}

# ---------- Main ----------

# Usage: main [--fix-all] [--install-deps] [--no-color] [--version] [--help]
#   Parses arguments, detects the platform and runs every check in order.
main() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --fix-all)      FIX_ALL=1 ;;
      --install-deps) INSTALL_DEPS=1 ;;
      --no-color)     USE_COLOR=0 ;;
      --version)      echo "outline-health.sh $SCRIPT_VERSION"; exit 0 ;;
      -h|--help)      usage; exit 0 ;;
      *) echo "Unknown argument: $arg"; usage; exit 2 ;;
    esac
  done
  setup_colors
  detect_os

  echo "Outline VPN health check $SCRIPT_VERSION - $(date '+%F %T %Z')  (fix mode: $([[ $FIX_ALL -eq 1 ]] && echo ON || echo off))"

  platform_gate
  check_prereqs
  check_docker_daemon || true
  check_containers
  check_config
  check_ports
  check_firewall
  check_api
  check_network
  check_resources
  check_logs

  section "Summary"
  echo "problems found: $ISSUES, still unresolved: $UNFIXED"
  if [[ $UNFIXED -gt 0 ]]; then
    echo "${C_BAD}Outline is NOT fully healthy.${C_OFF}"
    [[ $FIX_ALL -ne 1 && $ISSUES -gt 0 ]] && echo "Try: $(rerun_hint --fix-all)"
    exit 1
  fi
  echo "${C_OK}Outline looks healthy.${C_OFF}"
  exit 0
}

# Set OUTLINE_HEALTH_SOURCE_ONLY=1 to source this file (e.g. for tests) without running it.
# main stays the very last statement so `curl ... | bash` always parses the whole script first.
[[ -n "${OUTLINE_HEALTH_SOURCE_ONLY:-}" ]] || main "$@"
