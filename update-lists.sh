#!/bin/sh
# update-lists.sh - обновление списков и фейков zapret из Flowseal
# Для ASUS роутеров (mipsel, Entware)

ZAPRET_ETC="/opt/etc/zapret"
ZAPRET_FAKE="$ZAPRET_ETC/fake"
ZAPRET_LISTS="$ZAPRET_ETC/lists"
ZAPRET_LOG="/opt/var/log/zapret-update.log"

# Источник
FLOWSEAL_RAW="https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main"

# Файлы списков
LISTS="list-general.txt list-exclude.txt ipset-all.txt ipset-exclude.txt"

# Файлы фейков (только *.bin)
FAKES="ACTIVE_DISCORD_UDP.bin ACTIVE_GAME_UDP.bin quic_initial_www_google_com.bin quic_initial_4pda_to.bin quic_initial_5ka_ru.bin quic_initial_rutube_ru.bin quic_initial_steamcommunity_com.bin quic_initial_tencent_com.bin tls_clienthello_4pda_to.bin tls_clienthello_5ka_ru.bin tls_clienthello_max_ru.bin tls_clienthello_soschi_park.bin tls_clienthello_www_google_com.bin tls_clienthello_www_sferum_ru.bin stun.bin stun2.bin"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$ZAPRET_LOG"; }

# Проверка зависимости
if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    echo "Нужен curl или wget. Установи: opkg install curl"
    exit 1
fi

# Функция скачивания
download() {
    local url="$1"
    local out="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -sL --max-time 30 -o "$out" "$url" && return 0
    else
        wget -q -T 30 -O "$out" "$url" && return 0
    fi
    return 1
}

# Обновление списков
log "Обновление списков..."
mkdir -p "$ZAPRET_LISTS"
UPDATED=0
for f in $LISTS; do
    if download "$FLOWSEAL_RAW/$f" "$ZAPRET_LISTS/$f.tmp"; then
        if [ -s "$ZAPRET_LISTS/$f.tmp" ]; then
            mv -f "$ZAPRET_LISTS/$f.tmp" "$ZAPRET_LISTS/$f"
            log "  OK: $f"
            UPDATED=$((UPDATED+1))
        else
            rm -f "$ZAPRET_LISTS/$f.tmp"
            log "  ПУСТО: $f"
        fi
    else
        log "  ОШИБКА: $f"
    fi
done

# Обновление фейков
log "Обновление фейков..."
mkdir -p "$ZAPRET_FAKE"
for f in $FAKES; do
    if download "$FLOWSEAL_RAW/bin/$f" "$ZAPRET_FAKE/$f.tmp"; then
        if [ -s "$ZAPRET_FAKE/$f.tmp" ]; then
            mv -f "$ZAPRET_FAKE/$f.tmp" "$ZAPRET_FAKE/$f"
            log "  OK: $f"
            UPDATED=$((UPDATED+1))
        else
            rm -f "$ZAPRET_FAKE/$f.tmp"
            log "  ПУСТО: $f"
        fi
    else
        log "  ОШИБКА: $f"
    fi
done

log "Обновление завершено. Обновлено файлов: $UPDATED"

# Перезапуск zapret, если он запущен
if [ -x /opt/etc/init.d/S99zapret ]; then
    if /opt/etc/init.d/S99zapret status | grep -q RUNNING; then
        log "Перезапуск zapret..."
        /opt/etc/init.d/S99zapret restart
    fi
fi

echo "Готово. Обновлено файлов: $UPDATED"
