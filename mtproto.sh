#!/bin/bash

set -euo pipefail

DEFAULT_PORT=443
LANG_OPT=2
LANG_CHOICE="ru"
LANG_PROVIDED=0
PUBLIC_IP=""
SECRET=""
AD_TAG=""
NONINTERACTIVE=0
PORT_PROVIDED=0
TLS_MODE=""
TLS_DOMAIN=""
MODE_PROVIDED=0
SNI_PROVIDED=0
DEFAULT_SNI="starlink.com"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[*]${NC} $*" >&2; }
ok()    { echo -e "${GREEN}[+]${NC} $*" >&2; }
warn()  { echo -e "${YELLOW}[!]${NC} $*" >&2; }
err()   { echo -e "${RED}[!]${NC} $*" >&2; }

set_language() {
  case "${1:-ru}" in
    en|EN|english|1)
      LANG_CHOICE="en"
      LANG_OPT=1
      L_ERR_ROOT="Run as root: sudo bash $0"
      L_ERR_UNKNOWN_ARG="Unknown argument"
      L_ERR_IP_DETECT="Could not detect IPv4. Use: --ip YOUR_IP"
      L_ERR_SECRET_LEN="must be exactly 32 hex characters"
      L_ERR_BAD_PORT="Invalid port"
      L_ERR_BAD_MODE="Unknown mode. Use: xray | faketls"
      L_ERR_BAD_DOMAIN="Invalid SNI/domain"
      L_ERR_BAD_CHOICE="Invalid choice"
      L_ERR_TELEMT_INSTALL="Official install.sh failed"
      L_ERR_TELEMT_PORT="telemt is not listening on port"
      L_ERR_TELEMT_TAG="telemt failed to start after applying tag"
      L_ERR_CONFIG="Config not found"
      L_ERR_INSTALL_FIRST="Install telemt first"
      L_UNKNOWN_PROC="unknown process"
      L_INFO_DEPS="Installing curl, openssl..."
      L_PORT_FREE="Port %s is free"
      L_PORT_USE_FLAG="Using port %s (--port)"
      L_PORT_BUSY_TITLE="PORT %s IS IN USE — cannot continue"
      L_PORT_BUSY_PROC="Process listening on port %s:"
      L_PORT_BUSY_SS="Details (ss):"
      L_PORT_BUSY_TELEMT="Telemt is already on this server."
      L_PORT_BUSY_TELEMT_HINT="You can reinstall/update on port %s."
      L_MENU_REINSTALL="Reinstall Telemt on port %s (stop telemt and continue)"
      L_MENU_OTHER_PORT="Choose another port"
      L_MENU_RETRY="Retry check"
      L_MENU_EXIT="Exit"
      L_PORT_BUSY_HINT="Free the port or pick another (e.g. 8443 if 443 is used by Xray/Marzban)."
      L_MENU_ENTER_PORT="Enter port (1-65535):"
      L_STOP_TELEMT="Stopping telemt for reinstall on port %s..."
      L_PORT_STILL_BUSY="Port %s still in use after stop telemt"
      L_PORT_FREED="Port %s freed"
      L_PROMPT_SNI="Enter masking SNI domain [%s]:"
      L_MODE_XRAY_OK="Mode: Xray (SNI = server IP: %s)"
      L_MODE_FAKE_OK="Mode: Fake-TLS (SNI = %s)"
      L_TLS_MENU_TITLE="Fake-TLS mode (ee)"
      L_TLS_MENU_1="Xray — SNI = server IP (%s)"
      L_TLS_MENU_1_DESC="Works with Full TUN / Xray"
      L_TLS_MENU_2="Standard Fake-TLS — custom SNI domain"
      L_TLS_MENU_2_DESC="starlink.com, petrovich.ru, etc."
      L_MODE_XRAY_SHORT="Mode: Xray, SNI = %s"
      L_MODE_FAKE_SHORT="Mode: Fake-TLS, SNI = %s"
      L_LINKS_TITLE="Telegram proxy links"
      L_LINKS_MODE="Mode"
      L_LINKS_SNI="SNI"
      L_TAG_TITLE="Sponsor tag (@MTProxybot)"
      L_TAG_S1="Open @MTProxybot in Telegram"
      L_TAG_S2="Register proxy: %s:%s"
      L_TAG_S3="Secret: %s"
      L_TAG_S4="Set your channel (e.g. @mychannel)"
      L_TAG_S5="Bot will send a 32 hex tag"
      L_TAG_PROMPT="Paste ad_tag now (Enter to skip):"
      L_TAG_SKIP="Tag not set. Add later:"
      L_TAG_SKIP_HINT1="  sudo bash %s --tag YOUR_32_HEX"
      L_TAG_OK="Sponsor channel will be shown to proxy users"
      L_TAG_APPLIED="ad_tag applied, telemt restarted"
      L_INSTALL_TITLE="Installing Telemt MTProxy"
      L_INSTALL_IP="IP"
      L_INSTALL_PORT="Port"
      L_INSTALL_MODE="Mode"
      L_INSTALL_SNI="SNI"
      L_STEP1="[1/4] Installing telemt binary..."
      L_STEP2="[2/4] Writing configuration..."
      L_STEP3="[3/4] Starting service..."
      L_STEP4="[4/4] Installation complete"
      L_TELEMT_ACTIVE="telemt active on 0.0.0.0:%s"
      L_DONE="Done. Logs: journalctl -u telemt -f"
      L_CONFIG_PATH="Config: /etc/telemt/telemt.toml"
      L_PROMPT_CHOICE="Choice [1]:"
      L_LANG_TITLE="Language / Язык"
      L_LANG_1="Русский"
      L_LANG_2="English"
      L_LANG_OK="Language: English"
      L_USAGE=$(cat <<'EOU'
Usage:
  sudo bash mtproto.sh [options]

Options:
  --ip IP           Public IPv4 (auto-detect if omitted)
  --port PORT       Port (default 443 or interactive)
  --secret HEX32    32 hex secret (random if omitted)
  --lang LANG       ru | en | 1 | 2
  --mode MODE       xray | faketls
  --sni DOMAIN      SNI for faketls (e.g. starlink.com)
  --tag HEX32       ad_tag without prompt
  --yes             Skip ad_tag prompt
  -h, --help        Help

Modes:
  xray     — tls_domain = server IP (Xray Full TUN)
  faketls  — tls_domain = masking domain
EOU
)
      ;;
    *)
      LANG_CHOICE="ru"
      LANG_OPT=2
      L_ERR_ROOT="Запустите от root: sudo bash $0"
      L_ERR_UNKNOWN_ARG="Неизвестный аргумент"
      L_ERR_IP_DETECT="Не удалось определить IPv4. Укажите: --ip ВАШ_IP"
      L_ERR_SECRET_LEN="должен быть ровно 32 hex-символа"
      L_ERR_BAD_PORT="Некорректный порт"
      L_ERR_BAD_MODE="Неизвестный режим. Используйте: xray | faketls"
      L_ERR_BAD_DOMAIN="Некорректный SNI/домен"
      L_ERR_BAD_CHOICE="Неверный выбор"
      L_ERR_TELEMT_INSTALL="Ошибка официального install.sh"
      L_ERR_TELEMT_PORT="telemt не слушает порт"
      L_ERR_TELEMT_TAG="telemt не запустился после применения тега"
      L_ERR_CONFIG="Конфиг не найден"
      L_ERR_INSTALL_FIRST="Сначала установите telemt"
      L_UNKNOWN_PROC="неизвестный процесс"
      L_INFO_DEPS="Установка curl, openssl..."
      L_PORT_FREE="Порт %s свободен"
      L_PORT_USE_FLAG="Используется порт %s (--port)"
      L_PORT_BUSY_TITLE="ПОРТ %s ЗАНЯТ — установка не может продолжить"
      L_PORT_BUSY_PROC="На порту %s уже слушает процесс:"
      L_PORT_BUSY_SS="Подробности (ss):"
      L_PORT_BUSY_TELEMT="Это уже Telemt на этом сервере."
      L_PORT_BUSY_TELEMT_HINT="Можно переустановить/обновить конфиг на порту %s."
      L_MENU_REINSTALL="Переустановить Telemt на порту %s (остановить telemt и продолжить)"
      L_MENU_OTHER_PORT="Выбрать другой порт"
      L_MENU_RETRY="Повторить проверку"
      L_MENU_EXIT="Выход"
      L_PORT_BUSY_HINT="Освободите порт или выберите другой (например 8443, если 443 занят Xray/Marzban)."
      L_MENU_ENTER_PORT="Введите порт (1-65535):"
      L_STOP_TELEMT="Останавливаю telemt для переустановки на порту %s..."
      L_PORT_STILL_BUSY="Порт %s всё ещё занят после stop telemt"
      L_PORT_FREED="Порт %s освобождён"
      L_PROMPT_SNI="Введите SNI домен маскировки [%s]:"
      L_MODE_XRAY_OK="Режим: Xray (SNI = IP сервера: %s)"
      L_MODE_FAKE_OK="Режим: Fake-TLS (SNI = %s)"
      L_TLS_MENU_TITLE="Режим Fake-TLS (ee)"
      L_TLS_MENU_1="Xray — SNI = IP сервера (%s)"
      L_TLS_MENU_1_DESC="Совместимость с Full TUN / Xray"
      L_TLS_MENU_2="Стандартный Fake-TLS — свой SNI-домен"
      L_TLS_MENU_2_DESC="starlink.com, petrovich.ru и т.д."
      L_MODE_XRAY_SHORT="Режим: Xray, SNI = %s"
      L_MODE_FAKE_SHORT="Режим: Fake-TLS, SNI = %s"
      L_LINKS_TITLE="Ссылки для Telegram"
      L_LINKS_MODE="Режим"
      L_LINKS_SNI="SNI"
      L_TAG_TITLE="Рекламный тег (@MTProxybot)"
      L_TAG_S1="Откройте @MTProxybot в Telegram"
      L_TAG_S2="Зарегистрируйте прокси: %s:%s"
      L_TAG_S3="Секрет: %s"
      L_TAG_S4="Укажите канал (например @mychannel)"
      L_TAG_S5="Бот пришлёт тег — 32 hex символа"
      L_TAG_PROMPT="Вставьте ad_tag сейчас (Enter — пропустить):"
      L_TAG_SKIP="Тег не задан. Добавить позже:"
      L_TAG_SKIP_HINT1="  sudo bash %s --tag ВАШ_32_HEX"
      L_TAG_OK="Канал спонсора будет показан пользователям прокси"
      L_TAG_APPLIED="ad_tag применён, telemt перезапущен"
      L_INSTALL_TITLE="Установка Telemt MTProxy"
      L_INSTALL_IP="IP"
      L_INSTALL_PORT="Порт"
      L_INSTALL_MODE="Режим"
      L_INSTALL_SNI="SNI"
      L_STEP1="[1/4] Установка бинарника telemt..."
      L_STEP2="[2/4] Запись конфигурации..."
      L_STEP3="[3/4] Запуск службы..."
      L_STEP4="[4/4] Установка завершена"
      L_TELEMT_ACTIVE="telemt active на 0.0.0.0:%s"
      L_DONE="Готово. Логи: journalctl -u telemt -f"
      L_CONFIG_PATH="Конфиг: /etc/telemt/telemt.toml"
      L_PROMPT_CHOICE="Выбор [1]:"
      L_LANG_TITLE="Язык / Language"
      L_LANG_1="Русский"
      L_LANG_2="English"
      L_LANG_OK="Язык: русский"
      L_USAGE=$(cat <<'EOR'
Использование:
  sudo bash mtproto.sh [опции]

Опции:
  --ip IP           Публичный IPv4 (иначе автоопределение)
  --port PORT       Порт (иначе 443 или интерактивный выбор)
  --secret HEX32    Секрет 32 hex (иначе случайный)
  --lang LANG       ru | en | 1 | 2
  --mode MODE       xray | faketls
  --sni DOMAIN      SNI для faketls
  --tag HEX32       ad_tag сразу
  --yes             Не спрашивать тег
  -h, --help        Справка

Режимы:
  xray     — tls_domain = IP сервера (Full TUN / Xray)
  faketls  — tls_domain = домен маскировки
EOR
)
      ;;
  esac
}

usage() {
  echo "$L_USAGE"
}

choose_language() {
  if [[ "$LANG_PROVIDED" -eq 1 ]]; then
    return 0
  fi
  {
    echo ""
    echo "=============================================="
    echo " ${L_LANG_TITLE}"
    echo "=============================================="
    echo ""
    echo "  1) ${L_LANG_1}"
    echo "  2) ${L_LANG_2}"
    echo ""
  } >&2
  local lc
  read -r -p "${L_PROMPT_CHOICE} " lc </dev/tty
  lc="${lc:-1}"
  case "$lc" in
    2|en|EN) set_language en; ok "Language: English" ;;
    *) set_language ru; ok "Язык: русский" ;;
  esac
}

set_language ru

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ip) PUBLIC_IP="$2"; shift 2 ;;
    --port) DEFAULT_PORT="$2"; PORT_PROVIDED=1; shift 2 ;;
    --secret) SECRET="$2"; shift 2 ;;
    --lang) set_language "$2"; LANG_PROVIDED=1; shift 2 ;;
    --mode) TLS_MODE="$2"; MODE_PROVIDED=1; shift 2 ;;
    --sni) TLS_DOMAIN="$2"; SNI_PROVIDED=1; shift 2 ;;
    --tag) AD_TAG="$2"; NONINTERACTIVE=1; shift 2 ;;
    --yes) NONINTERACTIVE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "${L_ERR_UNKNOWN_ARG}: $1"; usage; exit 1 ;;
  esac
done

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    err "$L_ERR_ROOT"
    exit 1
  fi
}

ensure_deps() {
  if ! command -v curl >/dev/null 2>&1; then
    info "$L_INFO_DEPS"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq curl ca-certificates openssl
  fi
}

detect_public_ip() {
  local ip=""
  ip="$(curl -fsS --max-time 10 -4 ifconfig.me 2>/dev/null || true)"
  [[ -z "$ip" ]] && ip="$(curl -fsS --max-time 10 -4 api.ipify.org 2>/dev/null || true)"
  [[ -z "$ip" ]] && ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    err "$L_ERR_IP_DETECT"
    exit 1
  fi
  echo "$ip"
}

port_in_use() {
  local p="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -tlnp 2>/dev/null | grep -qE ":${p}([[:space:]]|$)"
    return $?
  fi
  if command -v netstat >/dev/null 2>&1; then
    netstat -tlnp 2>/dev/null | grep -qE ":${p}([[:space:]]|$)"
    return $?
  fi
  return 1
}

port_holder() {
  local p="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -tlnp 2>/dev/null | grep -E ":${p}([[:space:]]|$)" || true
  elif command -v netstat >/dev/null 2>&1; then
    netstat -tlnp 2>/dev/null | grep -E ":${p}([[:space:]]|$)" || true
  fi
}

port_process_hint() {
  local p="$1"
  local line
  line="$(port_holder "$p" | head -1)"
  if echo "$line" | grep -qi telemt; then
    echo "telemt"
  elif echo "$line" | grep -q 'users:(('; then
    echo "$line" | sed -n 's/.*users:((\"\([^\"]*\)\".*/\1/p' | head -1
  else
    echo "$L_UNKNOWN_PROC"
  fi
}

is_telemt_on_port() {
  local p="$1"
  port_holder "$p" | grep -qi telemt
}

show_port_busy_banner() {
  local p="$1"
  local holder proc
  holder="$(port_holder "$p")"
  proc="$(port_process_hint "$p")"

  {
    echo ""
    echo "=============================================="
    printf ' %s\n' "$(printf "$L_PORT_BUSY_TITLE" "$p")"
    echo "=============================================="
    echo ""
    printf ' %s %s\n' "$(printf "$L_PORT_BUSY_PROC" "$p")" "$proc"
    echo ""
    if [[ -n "$holder" ]]; then
      echo "$L_PORT_BUSY_SS"
      echo "$holder" | sed 's/^/  /'
      echo ""
    fi
    if is_telemt_on_port "$p"; then
      echo "$L_PORT_BUSY_TELEMT"
      printf ' %s\n' "$(printf "$L_PORT_BUSY_TELEMT_HINT" "$p")"
      echo ""
      printf '  1) %s\n' "$(printf "$L_MENU_REINSTALL" "$p")"
      echo "  2) ${L_MENU_OTHER_PORT}"
      echo "  3) ${L_MENU_RETRY}"
      echo "  4) ${L_MENU_EXIT}"
    else
      echo "$L_PORT_BUSY_HINT"
      echo ""
      echo "  1) ${L_MENU_OTHER_PORT}"
      printf '  2) %s\n' "$(printf "$L_MENU_RETRY" "$p")"
      echo "  3) ${L_MENU_EXIT}"
    fi
    echo ""
  } >&2
}

choose_port() {
  local p="$DEFAULT_PORT"
  while true; do
    if ! port_in_use "$p"; then
      ok "$(printf "$L_PORT_FREE" "$p")"
      PORT="$p"
      return 0
    fi

    show_port_busy_banner "$p"

    if is_telemt_on_port "$p"; then
      read -r -p "${L_PROMPT_CHOICE} " choice </dev/tty
      choice="${choice:-1}"
      case "$choice" in
        1)
          info "$(printf "$L_STOP_TELEMT" "$p")"
          systemctl stop telemt 2>/dev/null || true
          sleep 1
          if port_in_use "$p"; then
            err "$(printf "$L_PORT_STILL_BUSY" "$p")"
            continue
          fi
          ok "$(printf "$L_PORT_FREED" "$p")"
          PORT="$p"
          return 0
          ;;
        2)
          read -r -p "${L_MENU_ENTER_PORT} " p </dev/tty
          if [[ ! "$p" =~ ^[0-9]+$ ]] || [[ "$p" -lt 1 ]] || [[ "$p" -gt 65535 ]]; then
            err "$L_ERR_BAD_PORT"
            p="$DEFAULT_PORT"
          fi
          ;;
        3) ;;
        4) exit 1 ;;
        *) p="$DEFAULT_PORT" ;;
      esac
    else
      read -r -p "${L_PROMPT_CHOICE} " choice </dev/tty
      choice="${choice:-1}"
      case "$choice" in
        1)
          read -r -p "${L_MENU_ENTER_PORT} " p </dev/tty
          if [[ ! "$p" =~ ^[0-9]+$ ]] || [[ "$p" -lt 1 ]] || [[ "$p" -gt 65535 ]]; then
            err "$L_ERR_BAD_PORT"
            p="$DEFAULT_PORT"
          fi
          ;;
        2) ;;
        3) exit 1 ;;
        *) p="$DEFAULT_PORT" ;;
      esac
    fi
  done
}

normalize_port() {
  local p="$1"
  p="$(echo "$p" | tr -d '\r\n[:space:]' | grep -oE '[0-9]+' | head -1)"
  if [[ ! "$p" =~ ^[0-9]+$ ]] || [[ "$p" -lt 1 ]] || [[ "$p" -gt 65535 ]]; then
    err "$L_ERR_BAD_PORT: '$1'"
    exit 1
  fi
  echo "$p"
}

resolve_port() {
  local p="$DEFAULT_PORT"
  if [[ "$PORT_PROVIDED" -eq 1 ]] && ! port_in_use "$p"; then
    ok "$(printf "$L_PORT_USE_FLAG" "$p")"
    PORT="$p"
    return 0
  fi
  choose_port
}

generate_secret() {
  if [[ -f /etc/telemt/telemt.toml ]]; then
    local old
    old="$(awk -F'"' '/^[[:space:]]*hello[[:space:]]*=/ {print $2; exit}' /etc/telemt/telemt.toml 2>/dev/null || true)"
    if [[ "$old" =~ ^[0-9a-fA-F]{32}$ ]]; then
      echo "$old" | tr 'A-F' 'a-f'
      return 0
    fi
  fi
  openssl rand -hex 16
}

validate_hex32() {
  local v="$1" name="$2"
  if [[ ! "$v" =~ ^[0-9a-fA-F]{32}$ ]]; then
    err "${name} ${L_ERR_SECRET_LEN}"
    return 1
  fi
  return 0
}

domain_hex() {
  printf '%s' "$1" | od -An -tx1 | tr -d ' \n'
}

build_ee_secret() {
  local secret="$1" tls_domain="$2"
  echo "ee${secret}$(domain_hex "$tls_domain")"
}

validate_tls_domain() {
  local d="$1"
  if [[ "$d" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    return 0
  fi
  if [[ "$d" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]] && [[ "$d" == *.* ]]; then
    return 0
  fi
  err "${L_ERR_BAD_DOMAIN}: ${d}"
  return 1
}

prompt_sni_domain() {
  local input
  read -r -p "$(printf "$L_PROMPT_SNI" "$DEFAULT_SNI") " input </dev/tty
  input="$(echo "$input" | tr -d '[:space:]')"
  TLS_DOMAIN="${input:-$DEFAULT_SNI}"
  validate_tls_domain "$TLS_DOMAIN" || prompt_sni_domain
}

choose_tls_mode() {
  if [[ "$MODE_PROVIDED" -eq 1 ]]; then
    case "$TLS_MODE" in
      xray|XRAY|1)
        TLS_MODE="xray"
        TLS_DOMAIN="$PUBLIC_IP"
        ok "$(printf "$L_MODE_XRAY_OK" "$TLS_DOMAIN")"
        ;;
      faketls|fake|FAKETLS|2)
        TLS_MODE="faketls"
        if [[ -z "$TLS_DOMAIN" ]]; then
          prompt_sni_domain
        else
          validate_tls_domain "$TLS_DOMAIN" || exit 1
        fi
        ok "$(printf "$L_MODE_FAKE_OK" "$TLS_DOMAIN")"
        ;;
      *)
        err "${L_ERR_BAD_MODE}: ${TLS_MODE}"
        exit 1
        ;;
    esac
    return 0
  fi

  {
    echo ""
    echo "=============================================="
    echo " ${L_TLS_MENU_TITLE}"
    echo "=============================================="
    echo ""
    printf '  1) %s\n' "$(printf "$L_TLS_MENU_1" "$PUBLIC_IP")"
    echo "     ${L_TLS_MENU_1_DESC}"
    echo ""
    echo "  2) ${L_TLS_MENU_2}"
    echo "     ${L_TLS_MENU_2_DESC}"
    echo ""
  } >&2

  local choice
  read -r -p "${L_PROMPT_CHOICE} " choice </dev/tty
  choice="${choice:-1}"
  case "$choice" in
    1)
      TLS_MODE="xray"
      TLS_DOMAIN="$PUBLIC_IP"
      ok "$(printf "$L_MODE_XRAY_SHORT" "$TLS_DOMAIN")"
      ;;
    2)
      TLS_MODE="faketls"
      prompt_sni_domain
      ok "$(printf "$L_MODE_FAKE_SHORT" "$TLS_DOMAIN")"
      ;;
    *)
      err "$L_ERR_BAD_CHOICE"
      choose_tls_mode
      ;;
  esac
}

tls_mode_label() {
  case "$TLS_MODE" in
    xray) echo "Xray (SNI = IP)" ;;
    faketls) echo "Fake-TLS (SNI = ${TLS_DOMAIN})" ;;
    *) echo "$TLS_DOMAIN" ;;
  esac
}

write_config() {
  local ip="$1" port="$2" secret="$3" tag="$4" tls_domain="$5"
  local config="/etc/telemt/telemt.toml"

  cp -a "$config" "${config}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

  {
    cat <<EOF
[general]
use_middle_proxy = true
EOF
    if [[ -n "$tag" ]]; then
      echo "ad_tag = \"${tag}\""
    fi
    cat <<EOF

[general.modes]
classic = true
secure = true
tls = true

[general.links]
public_host = "${ip}"
public_port = ${port}
show = "*"

[server]
port = ${port}

[[server.listeners]]
ip = "0.0.0.0"

[server.api]
enabled = true
listen = "127.0.0.1:9091"
whitelist = ["127.0.0.1/32", "::1/128"]

[censorship]
tls_domain = "${tls_domain}"
mask = true
tls_emulation = true
tls_front_dir = "tlsfront"

[access.users]
hello = "${secret}"
EOF
    if [[ -n "$tag" ]]; then
      cat <<EOF

[access.user_ad_tags]
hello = "${tag}"
EOF
    fi
  } > "$config"

  chown telemt:telemt "$config" 2>/dev/null || chown root:telemt "$config" 2>/dev/null || true
  chmod 640 "$config"
}

apply_ad_tag() {
  local tag="$1"
  local config="/etc/telemt/telemt.toml"

  validate_hex32 "$tag" "ad_tag" || return 1
  tag="$(echo "$tag" | tr 'A-F' 'a-f')"

  if [[ ! -f "$config" ]]; then
    err "$L_ERR_CONFIG: $config"
    return 1
  fi

  cp -a "$config" "${config}.bak.tag.$(date +%Y%m%d%H%M%S)"

  if grep -q '^[[:space:]]*ad_tag[[:space:]]*=' "$config"; then
    sed -i "s/^[[:space:]]*ad_tag[[:space:]]*=.*/ad_tag = \"${tag}\"/" "$config"
  else
    sed -i "/^\[general\]/a ad_tag = \"${tag}\"" "$config"
  fi

  if grep -q '^\[access\.user_ad_tags\]' "$config"; then
    if grep -q '^[[:space:]]*hello[[:space:]]*=' "$config"; then
      sed -i "/^\[access\.user_ad_tags\]/,/^\[/ s/^[[:space:]]*hello[[:space:]]*=.*/hello = \"${tag}\"/" "$config"
    else
      sed -i "/^\[access\.user_ad_tags\]/a hello = \"${tag}\"" "$config"
    fi
  else
    cat >> "$config" <<EOF

[access.user_ad_tags]
hello = "${tag}"
EOF
  fi

  chown telemt:telemt "$config" 2>/dev/null || true
  systemctl restart telemt
  sleep 2
  if systemctl is-active --quiet telemt; then
    ok "$L_TAG_APPLIED"
    return 0
  fi
  err "$L_ERR_TELEMT_TAG"
  journalctl -u telemt -n 20 --no-pager
  return 1
}

wait_telemt() {
  local port="$1"
  local i
  for i in $(seq 1 15); do
    if systemctl is-active --quiet telemt && port_in_use "$port" && ss -tlnp 2>/dev/null | grep ":${port}" | grep -q telemt; then
      return 0
    fi
    sleep 1
  done
  return 1
}

print_links() {
  local ip="$1" port="$2" secret="$3" tls_domain="${4:-$ip}"
  local ee mode_label
  ee="$(build_ee_secret "$secret" "$tls_domain")"
  mode_label="$(tls_mode_label 2>/dev/null || echo "ee")"

  echo ""
  echo "=============================================="
  echo " ${L_LINKS_TITLE}"
  echo " ${L_LINKS_MODE}: ${mode_label}"
  echo " ${L_LINKS_SNI}:   ${tls_domain}"
  echo "=============================================="
  echo ""
  echo "TLS (ee):"
  echo "  tg://proxy?server=${ip}&port=${port}&secret=${ee}"
  echo "  https://t.me/proxy?server=${ip}&port=${port}&secret=${ee}"
  echo ""
  echo "Secure (dd):"
  echo "  tg://proxy?server=${ip}&port=${port}&secret=dd${secret}"
  echo ""
  echo "Classic:"
  echo "  tg://proxy?server=${ip}&port=${port}&secret=${secret}"
  echo ""
  echo "@MTProxybot:"
  echo "  ${ip}:${port}"
  echo "  ${secret}"
  echo ""

  if curl -fsS --max-time 3 "http://127.0.0.1:9091/v1/users" >/tmp/telemt_users.json 2>/dev/null; then
    info "API:"
    grep -oE 'tg://proxy[^"]+' /tmp/telemt_users.json | head -5 | sed 's/^/  /'
    rm -f /tmp/telemt_users.json
  fi
}

prompt_ad_tag() {
  echo ""
  echo "=============================================="
  echo " ${L_TAG_TITLE}"
  echo "=============================================="
  echo ""
  echo "1. ${L_TAG_S1}"
  printf '2. %s\n' "$(printf "$L_TAG_S2" "$PUBLIC_IP" "$PORT")"
  printf '3. %s\n' "$(printf "$L_TAG_S3" "$SECRET")"
  echo "4. ${L_TAG_S4}"
  echo "5. ${L_TAG_S5}"
  echo ""
  read -r -p "${L_TAG_PROMPT} " input_tag </dev/tty

  input_tag="$(echo "$input_tag" | tr -d '[:space:]')"
  if [[ -z "$input_tag" ]]; then
    warn "$L_TAG_SKIP"
    printf '%s\n' "$(printf "$L_TAG_SKIP_HINT1" "$0")"
    return 0
  fi

  if apply_ad_tag "$input_tag"; then
    ok "$L_TAG_OK"
  fi
}

# --- основная установка ---
main() {
  require_root
  ensure_deps
  choose_language

  [[ -z "$PUBLIC_IP" ]] && PUBLIC_IP="$(detect_public_ip)"
  resolve_port
  PORT="$(normalize_port "$PORT")"
  choose_tls_mode
  [[ -z "$SECRET" ]] && SECRET="$(generate_secret)"
  validate_hex32 "$SECRET" "secret" || exit 1
  SECRET="$(echo "$SECRET" | tr 'A-F' 'a-f')"

  echo ""
  echo "=============================================="
  echo " ${L_INSTALL_TITLE}"
  echo " ${L_INSTALL_IP}:     ${PUBLIC_IP}"
  echo " ${L_INSTALL_PORT}:   ${PORT}"
  echo " ${L_INSTALL_MODE}:  $(tls_mode_label)"
  echo " ${L_INSTALL_SNI}:    ${TLS_DOMAIN}"
  echo "=============================================="
  echo ""

  info "$L_STEP1"
  export DEBIAN_FRONTEND=noninteractive
  if ! curl -fsSL https://raw.githubusercontent.com/telemt/telemt/main/install.sh | sh -s -- \
    -d "${TLS_DOMAIN}" -p "${PORT}" -s "${SECRET}" -l "${LANG_OPT}"; then
    err "$L_ERR_TELEMT_INSTALL"
    exit 1
  fi

  info "$L_STEP2"
  write_config "$PUBLIC_IP" "$PORT" "$SECRET" "" "$TLS_DOMAIN"

  info "$L_STEP3"
  systemctl daemon-reload
  systemctl enable telemt
  systemctl restart telemt

  if command -v iptables >/dev/null 2>&1; then
    iptables -C INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null || \
      iptables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null || true
  fi

  if ! wait_telemt "$PORT"; then
    err "$L_ERR_TELEMT_PORT ${PORT}"
    journalctl -u telemt -n 40 --no-pager
    exit 1
  fi

  ok "$(printf "$L_TELEMT_ACTIVE" "$PORT")"
  info "$L_STEP4"

  print_links "$PUBLIC_IP" "$PORT" "$SECRET" "$TLS_DOMAIN"

  if [[ -n "$AD_TAG" ]]; then
    validate_hex32 "$AD_TAG" "ad_tag" && apply_ad_tag "$AD_TAG"
  elif [[ "$NONINTERACTIVE" -eq 0 ]]; then
    prompt_ad_tag
  fi

  echo ""
  ok "$L_DONE"
  echo "$L_CONFIG_PATH"
}

# Режим: только применить тег (telemt уже установлен)
tag_only_mode() {
  require_root
  [[ -f /etc/telemt/telemt.toml ]] || { err "$L_ERR_INSTALL_FIRST"; exit 1; }
  apply_ad_tag "$AD_TAG" || exit 1
  PUBLIC_IP="$(awk -F'"' '/^[[:space:]]*public_host[[:space:]]*=/ {print $2; exit}' /etc/telemt/telemt.toml 2>/dev/null || detect_public_ip)"
  PORT="$(awk -F'=' '/^[[:space:]]*port[[:space:]]*=/ {gsub(/[^0-9]/,"",$2); print $2; exit}' /etc/telemt/telemt.toml)"
  SECRET="$(awk -F'"' '/^[[:space:]]*hello[[:space:]]*=/ {print $2; exit}' /etc/telemt/telemt.toml)"
  TLS_DOMAIN="$(awk -F'"' '/^[[:space:]]*tls_domain[[:space:]]*=/ {print $2; exit}' /etc/telemt/telemt.toml 2>/dev/null || echo "$PUBLIC_IP")"
  if [[ "$TLS_DOMAIN" == "$PUBLIC_IP" ]]; then
    TLS_MODE="xray"
  else
    TLS_MODE="faketls"
  fi
  print_links "$PUBLIC_IP" "$PORT" "$SECRET" "$TLS_DOMAIN"
}

if [[ -n "$AD_TAG" ]] && [[ -f /etc/telemt/telemt.toml ]] && systemctl is-active --quiet telemt 2>/dev/null; then
  tag_only_mode
  exit 0
fi

main "$@"
