#!/bin/bash
#
# entrypoint.sh — валидирует переменные окружения, генерирует awg-конфиг
# в директории amnezia и поднимает интерфейс.

log() {
    echo "[entrypoint] $1"
}

require_value() {
    local var_name=$1
    local message=${2:-"Ожидание значения для ${var_name}..."}
    local value="${!var_name:-}"

    if [ -z "$value" ]; then
        log "$message"
        return 1
    fi
    return 0
}

require_range() {
    local env_name=$1
    local value=$2
    local message="${env_name}: ожидался формат 'число-число' (получено: '${value}')"

    if [[ ! "$value" =~ ^[0-9]+-[0-9]+$ ]]; then
        log "$message"
        return 1
    fi

    local start="${value%%-*}"
    local end="${value##*-}"

    if [ "$start" -gt "$end" ]; then
        log "Некорректный диапазон для '${env_name}' = '${value}': начало больше конца."
        return 1
    fi

    return 0
}

mustbe_oneof() {
    local env_name=$1
    local value=$2
    shift 2

    local allowed=("$@")

    local a
    for a in "${allowed[@]}"; do
        if [ "$value" == "$a" ]; then
            return 0
        fi
    done

    log "Недопустимое значение для '${env_name}' = '${value}'. Ожидалось одно из: ${allowed[*]}"
    return 1
}

is_base64() {
    local env_name=$1
    local value=$2
    local len=${#value}

    if [ -z "$value" ]; then
        log "'${env_name}' пустая строка — не base64."
        return 1
    fi

    if (( len % 4 != 0 )); then
        log "Длина '${env_name}' = '${value}' (${len}) не кратна 4 — не base64."
        return 1
    fi

    if [[ ! "$value" =~ ^[A-Za-z0-9+/]+={0,2}$ ]]; then
        log "Строка '${env_name}' = '${value}' содержит недопустимые символы для base64."
        return 1
    fi

    return 0
}

set -e

# ============================================================
#  [Interface] Basic variables
# ============================================================

IFACE="${IFACE:-awg0}"
ADDR="${ADDR:-10.0.0.1/24}"
LPORT="${LPORT:-51830}"
LADDR="${LADDR:-0.0.0.0}"
MTU="${MTU:-1280}"

AMNEZIA_DIR="${AMNEZIA_DIR:-/etc/amnezia/amneziawg}"
CONF_FILE="${AMNEZIA_DIR}/${IFACE}.conf"

# ============================================================
#  Валидация
# ============================================================

require_value "POST_UP"     $POST_UP
require_value "POST_DOWN"   $POST_DOWN

is_base64 "PKEY" $PKEY

require_value "S1" $S1
require_value "S2" $S2
require_value "S3" $S3
require_value "S4" $S4

require_range "H1" $H1
require_range "H2" $H2
require_range "H3" $H3
require_range "H4" $H4

is_base64       "HEADER_PROTECTION_KEY"     $HEADER_PROTECTION_KEY
require_range   "CONTENT_PADDING_ADDTION"   $CONTENT_PADDING_ADDTION

require_range "REKEY_AFTER_TIME"        $REKEY_AFTER_TIME
require_range "REKEY_TIMEOUT"           $REKEY_TIMEOUT
require_range "REJECT_AFETR_TIME"       $REJECT_AFETR_TIME
require_range "KEEPALIVE_TIMEOUT"       $KEEPALIVE_TIMEOUT
require_range "MAX_HANDSAHE_ATTEMPTS"   $MAX_HANDSAHE_ATTEMPTS

mustbe_oneof "RANDOM_TRAILERS" $RANDOM_TRAILERS "off" "on"
mustbe_oneof "DISABLE_COOKIES" $DISABLE_COOKIES "off" "on"

require_value "PEERS_PATH" $PEERS_PATH

if [ ! -f "$PEERS_PATH" ]; then
    log "Пиры по пути '$PEERS_PATH' не найдены..."
    sleep infinity
fi

# ============================================================
#  Генерация .conf в директории amnezia
# ============================================================

mkdir -p "$AMNEZIA_DIR"

log "Генерируем конфигурацию ${CONF_FILE}..."

{
    echo "[Interface]"
    echo "PrivateKey = ${PKEY}"
    echo "Address = ${ADDR}"
    echo "ListenPort = ${LPORT}"
    echo "MTU = ${MTU}"
    echo
    echo "PostUp = ${POST_UP}"
    echo "PostDown = ${POST_DOWN}"
    echo
    echo "S1 = ${S1}"
    echo "S2 = ${S2}"
    echo "S3 = ${S3}"
    echo "S4 = ${S4}"
    echo
    echo "H1 = ${H1}"
    echo "H2 = ${H2}"
    echo "H3 = ${H3}"
    echo "H4 = ${H4}"
    echo
    echo "HeaderProtectionKey = ${HEADER_PROTECTION_KEY}"
    echo "ContentPaddingAddition = ${CONTENT_PADDING_ADDTION}"
    echo
    echo "RekeyAfterTime = ${REKEY_AFTER_TIME}"
    echo "RekeyTimeout = ${REKEY_TIMEOUT}"
    echo "RejectAfterTime = ${REJECT_AFETR_TIME}"
    echo "KeepaliveTimeout = ${KEEPALIVE_TIMEOUT}"
    echo "MaxHandshakeAttempts = ${MAX_HANDSAHE_ATTEMPTS}"
    echo
    echo "RandomTrailers = ${RANDOM_TRAILERS}"
    echo "DisableCookies = ${DISABLE_COOKIES}"
    echo
    cat "$PEERS_PATH"
} > "$CONF_FILE"

log "Конфиг записан: ${CONF_FILE}"
log "Выдача прав 0600: ${CONF_FILE}"
chmod 0600 "$CONF_FILE"

if command -v awg-quick >/dev/null 2>&1; then
    log "Запуск AWG интерфейса: ${IFACE}..."

    cleanup() {
        log "Останавливаем AWG интерфейс: ${IFACE}..."
        awg-quick down "$CONF_FILE" 2>/dev/null || true
        exit 0
    }

    trap cleanup TERM INT

    awg-quick up "$CONF_FILE"

    log "AWG интерфейс: ${IFACE} запущен. Статус:"
    awg show "$IFACE" || true

    tail -f /dev/null &
    wait $!
else
    log "awg-quick - не установлен. Ожидание закрытия..."
    sleep "10s"
fi