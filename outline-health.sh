#!/usr/bin/env bash
#
# outline-health.sh - Health check (and optional repair) for an Outline VPN server
#
# Usage:
#   sudo ./outline-health.sh              # check only, nothing is changed
#   sudo ./outline-health.sh --fix-all    # check and try to fix every problem found
#   sudo ./outline-health.sh --help
#
# Exit code: 0 = healthy, 1 = at least one unresolved problem.
#
# Edit with:  vi outline-health.sh

set -u

# ---------- Configuration (override via environment) ----------
OUTLINE_DIR="${OUTLINE_DIR:-/opt/outline}"
STATE_DIR="${STATE_DIR:-$OUTLINE_DIR/persisted-state}"
CONTAINERS=("shadowbox" "watchtower")
DISK_WARN_PCT=90
MEM_WARN_PCT=90
API_TIMEOUT=10
WT_API_VERSION="${WT_API_VERSION:-}"   # empty = auto-detect from the Docker daemon

FIX_ALL=0
ISSUES=0     # problems found
UNFIXED=0    # problems still present after (optional) fixing

# ---------- Output helpers ----------
if [[ -t 1 ]]; then
  C_OK=$'\e[32m'; C_BAD=$'\e[31m'; C_WARN=$'\e[33m'; C_OFF=$'\e[0m'
else
  C_OK=""; C_BAD=""; C_WARN=""; C_OFF=""
fi

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

# Usage: usage  -> prints the help text (the header comment of this file)
usage() { sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//'; }

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

# Usage: port_listening <tcp|udp> <port> -> returns 0 if something listens on it
port_listening() {
  local proto="$1" port="$2" flag="-ltn"
  [[ "$proto" == "udp" ]] && flag="-lun"
  ss -H $flag 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}\$"
}

# Usage: json_get <file> <key> -> prints a top-level JSON value (uses jq if present)
json_get() {
  local file="$1" key="$2"
  [[ -r "$file" ]] || return 1
  if have jq; then
    jq -r --arg k "$key" '.[$k] // empty' "$file" 2>/dev/null
  else
    grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"\?[^\",}]*" "$file" \
      | head -n1 | sed -E 's/.*:[[:space:]]*"?//'
  fi
}

# ---------- Checks ----------

# Usage: check_prereqs -> verifies root, docker, ss, curl are available
check_prereqs() {
  section "Prerequisites"
  if [[ $EUID -ne 0 ]]; then
    log_bad "not running as root (use sudo)"; mark_unfixed
    exit 1
  fi
  log_ok "running as root"
  local c
  for c in docker ss curl; do
    if have "$c"; then log_ok "$c found"
    else log_bad "$c not installed"; mark_unfixed; fi
  done
  have docker || { echo "docker is required, aborting."; exit 1; }
}

# Usage: check_docker_daemon -> checks docker service is active and enabled at boot
check_docker_daemon() {
  section "Docker daemon"
  if docker info >/dev/null 2>&1; then
    log_ok "docker daemon is responding"
  else
    log_bad "docker daemon is not responding"
    if try_fix "start docker" systemctl start docker && sleep 3 && docker info >/dev/null 2>&1; then
      log_ok "docker daemon now running"
    else
      mark_unfixed
      return 1
    fi
  fi
  if have systemctl; then
    if systemctl is-enabled docker >/dev/null 2>&1; then
      log_ok "docker enabled at boot"
    else
      log_bad "docker not enabled at boot"
      try_fix "enable docker at boot" systemctl enable docker || mark_unfixed
    fi
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
#   same image, command, mounts and log driver, plus -e DOCKER_API_VERSION=$WT_API_VERSION.
#   The old container config is saved to /root/watchtower-inspect-backup.json first.
recreate_watchtower() {
  local image logdrv b l apiv
  local -a binds=() cmd=() args=()
  apiv=$(detect_api_version)
  [[ -z "$apiv" ]] && { echo "cannot detect Docker API version" >&2; return 1; }
  image=$(docker inspect -f '{{.Config.Image}}' watchtower) || return 1
  logdrv=$(docker inspect -f '{{.HostConfig.LogConfig.Type}}' watchtower)
  docker inspect watchtower > /root/watchtower-inspect-backup.json 2>/dev/null

  mapfile -t binds < <(docker inspect -f '{{range .HostConfig.Binds}}{{println .}}{{end}}' watchtower)
  mapfile -t cmd   < <(docker inspect -f '{{range .Config.Cmd}}{{println .}}{{end}}' watchtower)
  [[ ${#binds[@]} -eq 0 ]] && binds=("/var/run/docker.sock:/var/run/docker.sock")
  [[ ${#cmd[@]} -eq 0 || -z "${cmd[0]}" ]] && cmd=(--cleanup --label-enable --interval 3600)

  # Keep Outline's opt-in label if the old container had it
  l=$(docker inspect -f '{{index .Config.Labels "com.centurylinklabs.watchtower.enable"}}' watchtower 2>/dev/null)
  [[ -n "$l" ]] && args+=(--label "com.centurylinklabs.watchtower.enable=$l")
  for b in "${binds[@]}"; do [[ -n "$b" ]] && args+=(-v "$b"); done
  [[ -n "$logdrv" ]] && args+=(--log-driver "$logdrv")

  docker rm -f watchtower || return 1
  docker run -d --name watchtower --restart always \
    -e "DOCKER_API_VERSION=$apiv" "${args[@]}" "$image" "${cmd[@]}"
}

# Usage: check_container <name> -> checks existence, running state, restart policy
check_container() {
  local name="$1" state policy restarts
  if ! docker inspect "$name" >/dev/null 2>&1; then
    log_bad "container '$name' does not exist"
    log_info "re-run the Outline installer to recreate it:"
    log_info 'sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/Jigsaw-Code/outline-apps/master/server_manager/install_scripts/install_server.sh)"'
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
  for c in "${CONTAINERS[@]}"; do check_container "$c"; done
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
  [[ -n "$API_PORT" ]] && log_info "management API port: $API_PORT (tcp)" || log_warn "could not detect API port"
  [[ -n "$KEY_PORT" ]] && log_info "access key port:     $KEY_PORT (tcp+udp)" || log_warn "could not detect access key port"
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

# Usage: fw_port_open <port> <tcp|udp> -> 0 if the local firewall allows it (or no firewall active)
fw_port_open() {
  local port="$1" proto="$2"
  if have ufw && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw status | grep -Eq "^${port}(/${proto})?[[:space:]].*ALLOW"
    return $?
  fi
  if have firewall-cmd && firewall-cmd --state >/dev/null 2>&1; then
    firewall-cmd --query-port="${port}/${proto}" >/dev/null 2>&1
    return $?
  fi
  return 0
}

# Usage: open_fw_port <port> <tcp|udp> -> opens the port with ufw or firewalld
open_fw_port() {
  local port="$1" proto="$2"
  if have ufw && ufw status 2>/dev/null | grep -q "Status: active"; then
    ufw allow "${port}/${proto}"
  elif have firewall-cmd && firewall-cmd --state >/dev/null 2>&1; then
    firewall-cmd --permanent --add-port="${port}/${proto}" && firewall-cmd --reload
  fi
}

# Usage: check_firewall -> verifies local firewall (ufw/firewalld) allows Outline ports
check_firewall() {
  section "Local firewall"
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

# Usage: check_network -> verifies outbound connectivity and DNS from the host
check_network() {
  section "Network"
  if curl -s --max-time 8 -o /dev/null https://www.google.com; then log_ok "outbound HTTPS works"
  else log_bad "outbound HTTPS failed"; mark_unfixed; fi
  if getent hosts www.google.com >/dev/null 2>&1; then log_ok "DNS resolution works"
  else log_bad "DNS resolution failed"; mark_unfixed; fi
}

# Usage: check_resources -> checks disk, memory and time-sync status
check_resources() {
  section "System resources"
  local disk mem
  disk=$(df -P / | awk 'NR==2{gsub("%","",$5); print $5}')
  if [[ "$disk" -ge "$DISK_WARN_PCT" ]]; then
    log_bad "disk usage ${disk}%"
    try_fix "prune unused docker data" docker system prune -f || mark_unfixed
  else log_ok "disk usage ${disk}%"; fi

  mem=$(free | awk '/Mem:/{printf "%d", $3/$2*100}')
  if [[ "$mem" -ge "$MEM_WARN_PCT" ]]; then log_warn "memory usage ${mem}%"
  else log_ok "memory usage ${mem}%"; fi

  if have timedatectl; then
    if [[ "$(timedatectl show -p NTPSynchronized --value 2>/dev/null)" == "yes" ]]; then
      log_ok "clock synchronized (NTP)"
    else
      log_bad "clock not NTP-synchronized (can break shadowsocks clients)"
      try_fix "enable NTP" timedatectl set-ntp true || mark_unfixed
    fi
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
# Usage: main [--fix-all|--help] -> parses args and runs all checks
main() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --fix-all) FIX_ALL=1 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown argument: $arg"; usage; exit 2 ;;
    esac
  done

  echo "Outline VPN health check - $(date '+%F %T %Z')  (fix mode: $([[ $FIX_ALL -eq 1 ]] && echo ON || echo off))"

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
    [[ $FIX_ALL -ne 1 && $ISSUES -gt 0 ]] && echo "Try: sudo $0 --fix-all"
    exit 1
  fi
  echo "${C_OK}Outline looks healthy.${C_OFF}"
  exit 0
}

main "$@"
