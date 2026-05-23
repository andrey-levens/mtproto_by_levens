#!/bin/bash
#
# Telemt MTProxy — интерактивная установка
# Режимы Fake-TLS:
#   1) xray    — SNI = IP сервера (совместимость с Xray Full TUN)
#   2) faketls — стандартный Fake-TLS, SNI = свой домен (starlink.com и т.д.)
# - если 443 занят — предложить другой порт
# - после установки — запрос ad_tag от @MTProxybot и перезапуск
#
# Запуск:  sudo bash install-telemt-interactive.sh
#          sudo bash install-telemt-interactive.sh --ip 1.2.3.4

set -euo pipefail

DEFAULT_PORT=443
LANG_OPT=2
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

usage() {
  cat <<'EOF'
Использование:
  sudo bash install-telemt-interactive.sh [опции]

Опции:
  --ip IP           Публичный IPv4 (иначе автоопределение)
  --port PORT       Порт (иначе 443 или интерактивный выбор)
  --secret HEX32    Секрет 32 hex (иначе случайный)
  --mode MODE       xray | faketls (иначе меню при установке)
  --sni DOMAIN      SNI для faketls (например starlink.com)
  --tag HEX32       ad_tag сразу, без запроса после установки
  --yes             Не спрашивать тег после установки
  -h, --help        Справка

Режимы:
  xray     — tls_domain = IP сервера (для Full TUN / Xray)
  faketls  — tls_domain = домен маскировки (спросит или --sni)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ip) PUBLIC_IP="$2"; shift 2 ;;
    --port) DEFAULT_PORT="$2"; PORT_PROVIDED=1; shift 2 ;;
    --secret) SECRET="$2"; shift 2 ;;
    --mode) TLS_MODE="$2"; MODE_PROVIDED=1; shift 2 ;;
    --sni) TLS_DOMAIN="$2"; SNI_PROVIDED=1; shift 2 ;;
    --tag) AD_TAG="$2"; NONINTERACTIVE=1; shift 2 ;;
    --yes) NONINTERACTIVE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) err "Неизвестный аргумент: $1"; usage; exit 1 ;;
  esac
done

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    err "Запустите от root: sudo bash $0"
    exit 1
  fi
}

ensure_deps() {
  if ! command -v curl >/dev/null 2>&1; then
    info "Установка curl, openssl..."
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
    err "Не удалось определить IPv4. Укажите: --ip ВАШ_IP"
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
    echo "неизвестный процесс"
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
    echo " ПОРТ ${p} ЗАНЯТ — установка не может продолжить"
    echo "=============================================="
    echo ""
    echo "На порту ${p} уже слушает процесс: ${proc}"
    echo ""
    if [[ -n "$holder" ]]; then
      echo "Подробности (ss):"
      echo "$holder" | sed 's/^/  /'
      echo ""
    fi
    if is_telemt_on_port "$p"; then
      echo "Это уже Telemt на этом сервере."
      echo "Можно переустановить/обновить конфиг на том же порту ${p}."
      echo ""
      echo "  1) Переустановить Telemt на порту ${p} (остановить telemt и продолжить)"
      echo "  2) Выбрать другой порт"
      echo "  3) Повторить проверку"
      echo "  4) Выход"
    else
      echo "Освободите порт или выберите другой (например 8443 для MTProxy,"
      echo "если 443 занят Xray/Marzban)."
      echo ""
      echo "  1) Ввести другой порт"
      echo "  2) Повторить проверку порта ${p}"
      echo "  3) Выход"
    fi
    echo ""
  } >&2
}

choose_port() {
  local p="$DEFAULT_PORT"
  while true; do
    if ! port_in_use "$p"; then
      ok "Порт ${p} свободен"
      PORT="$p"
      return 0
    fi

    show_port_busy_banner "$p"

    if is_telemt_on_port "$p"; then
      read -r -p "Выбор [1]: " choice </dev/tty
      choice="${choice:-1}"
      case "$choice" in
        1)
          info "Останавливаю telemt для переустановки на порту ${p}..."
          systemctl stop telemt 2>/dev/null || true
          sleep 1
          if port_in_use "$p"; then
            err "Порт ${p} всё ещё занят после stop telemt"
            continue
          fi
          ok "Порт ${p} освобождён"
          PORT="$p"
          return 0
          ;;
        2)
          read -r -p "Введите порт (1-65535): " p </dev/tty
          if [[ ! "$p" =~ ^[0-9]+$ ]] || [[ "$p" -lt 1 ]] || [[ "$p" -gt 65535 ]]; then
            err "Некорректный порт, снова ${DEFAULT_PORT}"
            p="$DEFAULT_PORT"
          fi
          ;;
        3) ;;
        4) exit 1 ;;
        *) p="$DEFAULT_PORT" ;;
      esac
    else
      read -r -p "Выбор [1]: " choice </dev/tty
      choice="${choice:-1}"
      case "$choice" in
        1)
          read -r -p "Введите порт (1-65535): " p </dev/tty
          if [[ ! "$p" =~ ^[0-9]+$ ]] || [[ "$p" -lt 1 ]] || [[ "$p" -gt 65535 ]]; then
            err "Некорректный порт"
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
    err "Некорректный порт: '$1'"
    exit 1
  fi
  echo "$p"
}

resolve_port() {
  local p="$DEFAULT_PORT"
  if [[ "$PORT_PROVIDED" -eq 1 ]] && ! port_in_use "$p"; then
    ok "Используется порт ${p} (--port)"
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
    err "${name} должен быть ровно 32 hex-символа"
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
  err "Некорректный SNI/домен: ${d}"
  return 1
}

prompt_sni_domain() {
  local input
  read -r -p "Введите SNI домен маскировки [${DEFAULT_SNI}]: " input </dev/tty
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
        ok "Режим: Xray (SNI = IP сервера: ${TLS_DOMAIN})"
        ;;
      faketls|fake|FAKETLS|2)
        TLS_MODE="faketls"
        if [[ -z "$TLS_DOMAIN" ]]; then
          prompt_sni_domain
        else
          validate_tls_domain "$TLS_DOMAIN" || exit 1
        fi
        ok "Режим: Fake-TLS (SNI = ${TLS_DOMAIN})"
        ;;
      *)
        err "Неизвестный режим: ${TLS_MODE}. Используйте: xray | faketls"
        exit 1
        ;;
    esac
    return 0
  fi

  {
    echo ""
    echo "=============================================="
    echo " Режим Fake-TLS (ee)"
    echo "=============================================="
    echo ""
    echo "  1) Xray — SNI = IP сервера (${PUBLIC_IP})"
    echo "     Совместимость с Full TUN / Xray (как 88.218.120.5)"
    echo ""
    echo "  2) Стандартный Fake-TLS — свой SNI-домен"
    echo "     starlink.com, petrovich.ru и т.д. (лучше для обхода DPI)"
    echo ""
  } >&2

  local choice
  read -r -p "Выбор [1]: " choice </dev/tty
  choice="${choice:-1}"
  case "$choice" in
    1)
      TLS_MODE="xray"
      TLS_DOMAIN="$PUBLIC_IP"
      ok "Режим: Xray, SNI = ${TLS_DOMAIN}"
      ;;
    2)
      TLS_MODE="faketls"
      prompt_sni_domain
      ok "Режим: Fake-TLS, SNI = ${TLS_DOMAIN}"
      ;;
    *)
      err "Неверный выбор"
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
    err "Конфиг не найден: $config"
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
    ok "ad_tag применён, telemt перезапущен"
    return 0
  fi
  err "telemt не запустился после применения тега"
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
  echo " Ссылки для Telegram"
  echo " Режим: ${mode_label}"
  echo " SNI:   ${tls_domain}"
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
  echo "Для @MTProxybot (регистрация прокси):"
  echo "  Адрес: ${ip}:${port}"
  echo "  Секрет (hex): ${secret}"
  echo ""

  if curl -fsS --max-time 3 "http://127.0.0.1:9091/v1/users" >/tmp/telemt_users.json 2>/dev/null; then
    info "Ссылки из API:"
    grep -oE 'tg://proxy[^"]+' /tmp/telemt_users.json | head -5 | sed 's/^/  /'
    rm -f /tmp/telemt_users.json
  fi
}

prompt_ad_tag() {
  echo ""
  echo "=============================================="
  echo " Рекламный тег (@MTProxybot)"
  echo "=============================================="
  echo ""
  echo "1. Откройте @MTProxybot в Telegram"
  echo "2. Зарегистрируйте прокси: ${PUBLIC_IP}:${PORT}"
  echo "3. Секрет: ${SECRET}"
  echo "4. Укажите канал (например @petya)"
  echo "5. Бот пришлёт тег — 32 hex символа"
  echo ""
  read -r -p "Вставьте ad_tag сейчас (Enter — пропустить): " input_tag </dev/tty

  input_tag="$(echo "$input_tag" | tr -d '[:space:]')"
  if [[ -z "$input_tag" ]]; then
    warn "Тег не задан. Добавить позже:"
    echo "  sudo bash $0 --tag ВАШ_32_HEX   # только применить тег"
    echo "  или отредактируйте /etc/telemt/telemt.toml и: systemctl restart telemt"
    return 0
  fi

  if apply_ad_tag "$input_tag"; then
    ok "Канал спонсора будет показан пользователям прокси"
  fi
}

# --- основная установка ---
main() {
  require_root
  ensure_deps

  [[ -z "$PUBLIC_IP" ]] && PUBLIC_IP="$(detect_public_ip)"
  resolve_port
  PORT="$(normalize_port "$PORT")"
  choose_tls_mode
  [[ -z "$SECRET" ]] && SECRET="$(generate_secret)"
  validate_hex32 "$SECRET" "secret" || exit 1
  SECRET="$(echo "$SECRET" | tr 'A-F' 'a-f')"

  echo ""
  echo "=============================================="
  echo " Установка Telemt MTProxy"
  echo " IP:     ${PUBLIC_IP}"
  echo " Порт:   ${PORT}"
  echo " Режим:  $(tls_mode_label)"
  echo " SNI:    ${TLS_DOMAIN}"
  echo "=============================================="
  echo ""

  info "[1/4] Установка бинарника telemt..."
  export DEBIAN_FRONTEND=noninteractive
  if ! curl -fsSL https://raw.githubusercontent.com/telemt/telemt/main/install.sh | sh -s -- \
    -d "${TLS_DOMAIN}" -p "${PORT}" -s "${SECRET}" -l "${LANG_OPT}"; then
    err "Ошибка официального install.sh"
    exit 1
  fi

  info "[2/4] Запись конфигурации..."
  write_config "$PUBLIC_IP" "$PORT" "$SECRET" "" "$TLS_DOMAIN"

  info "[3/4] Запуск службы..."
  systemctl daemon-reload
  systemctl enable telemt
  systemctl restart telemt

  if command -v iptables >/dev/null 2>&1; then
    iptables -C INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null || \
      iptables -I INPUT -p tcp --dport "${PORT}" -j ACCEPT 2>/dev/null || true
  fi

  if ! wait_telemt "$PORT"; then
    err "telemt не слушает порт ${PORT}"
    journalctl -u telemt -n 40 --no-pager
    exit 1
  fi

  ok "telemt active на 0.0.0.0:${PORT}"
  info "[4/4] Установка завершена"

  print_links "$PUBLIC_IP" "$PORT" "$SECRET" "$TLS_DOMAIN"

  if [[ -n "$AD_TAG" ]]; then
    validate_hex32 "$AD_TAG" "ad_tag" && apply_ad_tag "$AD_TAG"
  elif [[ "$NONINTERACTIVE" -eq 0 ]]; then
    prompt_ad_tag
  fi

  echo ""
  ok "Готово. Логи: journalctl -u telemt -f"
  echo "Конфиг: /etc/telemt/telemt.toml"
}

# Режим: только применить тег (telemt уже установлен)
tag_only_mode() {
  require_root
  [[ -f /etc/telemt/telemt.toml ]] || { err "Сначала установите telemt"; exit 1; }
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
