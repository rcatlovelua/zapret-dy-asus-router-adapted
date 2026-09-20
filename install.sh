#!/bin/sh
# zapret-dy-asus-router-adapted - installer for ASUS routers (mipsel)
# Target: RT-AC51U and similar (MediaTek MT7620A, mipsel, Entware)
# License: MIT

set -e

# ---------- Пути ----------
EXEDIR="$(cd "$(dirname "$0")" && pwd)"
BINDIR="$EXEDIR/bin"
FAKEDIR="$BINDIR/fake"

OPT_BIN="/opt/bin"
OPT_ETC="/opt/etc/zapret"
OPT_FAKE="$OPT_ETC/fake"
OPT_LOG="/opt/var/log/zapret.log"
OPT_INIT="/opt/etc/init.d/S99zapret"

# ---------- Цвета ----------
if [ -t 1 ]; then
    RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[1;33m'; NC='\033[0m'
else
    RED=''; GRN=''; YLW=''; NC=''
fi

log()  { printf "${GRN}[+]${NC} %s\n" "$1"; }
warn() { printf "${YLW}[!]${NC} %s\n" "$1"; }
err()  { printf "${RED}[x]${NC} %s\n" "$1" >&2; }

# ---------- Проверки ----------
check_arch() {
    ARCH="$(uname -m)"
    case "$ARCH" in
        mips|mipsel) log "Архитектура: $ARCH (OK для mipsel)" ;;
        *) err "Архитектура $ARCH не поддерживается. Ожидается mips/mipsel."; exit 1 ;;
    esac
}

check_entware() {
    if [ ! -d /opt ] || [ ! -x /opt/bin/opkg ]; then
        err "Entware не найден. Установи Entware на USB-флешку и перезапусти роутер."
        exit 1
    fi
    log "Entware: OK"
}

check_deps() {
    MISSING=""
    for pkg in iptables ipset conntrack; do
        command -v "$pkg" >/dev/null 2>&1 || MISSING="$MISSING $pkg"
    done
    if [ -n "$MISSING" ]; then
        warn "Не хватает пакетов:$MISSING"
        warn "Установи их: opkg update && opkg install$MISSING"
    else
        log "Зависимости: OK"
    fi

    # Проверка ядерного модуля NFQUEUE
    if [ ! -d /proc/net/netfilter ]; then
        warn "Модуль nfnetlink_queue не загружен. Для tpws не критично, для nfqws — обязательно."
        warn "Попробуй: modprobe nfnetlink_queue"
    fi
}

# ---------- Установка ----------
do_install() {
    check_arch
    check_entware
    check_deps

    log "Создаю каталоги..."
    mkdir -p "$OPT_BIN" "$OPT_ETC" "$OPT_FAKE"

    log "Копирую бинарники в $OPT_BIN..."
    for f in nfqws tpws ip2net mdig; do
        if [ -f "$BINDIR/$f" ]; then
            cp -f "$BINDIR/$f" "$OPT_BIN/$f"
            chmod +x "$OPT_BIN/$f"
            log "  $f -> $OPT_BIN/$f"
        else
            warn "  $f отсутствует в $BINDIR, пропускаю"
        fi
    done

    # Симлинк для совместимости со стратегиями Flowseal (там путь nfq/nfqws)
    if [ -x "$OPT_BIN/nfqws" ]; then
        ln -sf "$OPT_BIN/nfqws" "$OPT_BIN/nfq"
        log "  симлинк: $OPT_BIN/nfq -> nfqws"
    fi

    log "Копирую фейки в $OPT_FAKE..."
    if [ -d "$FAKEDIR" ]; then
        cp -f "$FAKEDIR"/*.bin "$OPT_FAKE/" 2>/dev/null || true
        CNT=$(ls -1 "$OPT_FAKE"/*.bin 2>/dev/null | wc -l)
        log "  скопировано фейков: $CNT"
    else
        warn "  папка $FAKEDIR не найдена"
    fi

    log "Устанавливаю init-скрипт..."
    install_init

    log "Готово. Управление:"
    echo "    /opt/etc/init.d/S99zapret start"
    echo "    /opt/etc/init.d/S99zapret stop"
    echo "    /opt/etc/init.d/S99zapret restart"
    echo "    /opt/etc/init.d/S99zapret status"
}

# ---------- Init-скрипт ----------
install_init() {
    cat > "$OPT_INIT" <<'INIT_EOF'
#!/bin/sh
# zapret init script for ASUS (mipsel)

ZAPRET_BIN="/opt/bin"
ZAPRET_ETC="/opt/etc/zapret"
ZAPRET_FAKE="$ZAPRET_ETC/fake"
ZAPRET_LOG="/opt/var/log/zapret.log"
PIDFILE="/opt/var/run/zapret.pid"

# Режим: nfqws (NFQUEUE) или tpws (proxy). Для RT-AC51U рекомендуется tpws.
MODE="${ZAPRET_MODE:-tpws}"

# Порт для tpws (локальный SOCKS/HTTP-прокси)
TPWS_PORT="${ZAPRET_TPWS_PORT:-987}"

start() {
    [ -f "$PIDFILE" ] && { echo "zapret уже запущен"; return 0; }

    case "$MODE" in
        nfqws)
            [ -x "$ZAPRET_BIN/nfqws" ] || { echo "nfqws не найден"; exit 1; }
            # Базовая стратегия (пример). Позже заменим на конфиг из strategies/
            "$ZAPRET_BIN/nfqws" \
                --dpi-desync=fake,split2 \
                --dpi-desync-ttl=2 \
                --dpi-desync-fake-tls="$ZAPRET_FAKE/tls_clienthello_www_google_com.bin" \
                --dpi-desync-fake-quic="$ZAPRET_FAKE/quic_initial_www_google_com.bin" \
                --qnum=200 \
                >>"$ZAPRET_LOG" 2>&1 &
            echo $! > "$PIDFILE"
            ;;
        tpws)
            [ -x "$ZAPRET_BIN/tpws" ] || { echo "tpws не найден"; exit 1; }
            "$ZAPRET_BIN/tpws" \
                --port="$TPWS_PORT" \
                --split-pos=1 \
                --disorder \
                --fake-from-hex=0 \
                >>"$ZAPRET_LOG" 2>&1 &
            echo $! > "$PIDFILE"
            ;;
        *)
            echo "Неизвестный режим: $MODE"; exit 1 ;;
    esac

    sleep 1
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "zapret запущен (режим: $MODE, PID: $(cat "$PIDFILE"))"
    else
        echo "zapret не запустился, смотри $ZAPRET_LOG"; exit 1
    fi
}

stop() {
    if [ -f "$PIDFILE" ]; then
        PID="$(cat "$PIDFILE")"
        kill "$PID" 2>/dev/null || true
        rm -f "$PIDFILE"
        echo "zapret остановлен"
    else
        echo "zapret не запущен"
    fi
    # На всякий случай добиваем процессы
    pkill -f "$ZAPRET_BIN/nfqws" 2>/dev/null || true
    pkill -f "$ZAPRET_BIN/tpws"  2>/dev/null || true
}

status() {
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "zapret: RUNNING (режим: $MODE, PID: $(cat "$PIDFILE"))"
    else
        echo "zapret: STOPPED"
    fi
}

case "$1" in
    start)   start ;;
    stop)    stop ;;
    restart) stop; sleep 1; start ;;
    status)  status ;;
    *) echo "Usage: $0 {start|stop|restart|status}"; exit 1 ;;
esac
INIT_EOF
    chmod +x "$OPT_INIT"
    log "  init-скрипт: $OPT_INIT"
}

# ---------- Удаление ----------
do_uninstall() {
    log "Останавливаю zapret..."
    [ -x "$OPT_INIT" ] && "$OPT_INIT" stop || true

    log "Удаляю init-скрипт..."
    rm -f "$OPT_INIT"

    log "Удаляю бинарники..."
    rm -f "$OPT_BIN/nfqws" "$OPT_BIN/tpws" "$OPT_BIN/ip2net" "$OPT_BIN/mdig" "$OPT_BIN/nfq"

    log "Удаляю конфиги и фейки..."
    rm -rf "$OPT_ETC"

    log "Готово. Лог оставлен: $OPT_LOG"
}

# ---------- Статус ----------
do_status() {
    if [ -x "$OPT_INIT" ]; then
        "$OPT_INIT" status
    else
        echo "zapret не установлен (нет $OPT_INIT)"
    fi
}

# ---------- Точка входа ----------
case "$1" in
    install|"") do_install ;;
    uninstall)  do_uninstall ;;
    status)     do_status ;;
    *)
        echo "Usage: $0 {install|uninstall|status}"
        exit 1
        ;;
esac
