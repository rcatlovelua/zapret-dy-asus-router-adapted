#!/bin/sh
# update-binaries.sh - проверка и скачивание новых бинарников zapret
# Для ASUS роутеров (mipsel)

ARCH="mipsel"  # для RT-AC51U
ZAPRET_TMP="/opt/tmp/zapret-new"
LOG="/opt/var/log/zapret-update.log"
RELEASES_API="https://api.github.com/repos/bol-van/zapret/releases/latest"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"; }

# Получаем URL последнего релиза
if command -v curl >/dev/null 2>&1; then
    RELEASE_JSON=$(curl -sL --max-time 30 "$RELEASES_API")
else
    RELEASE_JSON=$(wget -qO- --timeout=30 "$RELEASES_API")
fi

# Ищем ссылку на архив с бинарниками
# Формат: zapret-vXX.X.tar.gz или zapret-vXX.X-openwrt-embedded.tar.gz
URL=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url": "[^"]*"' | grep -i 'tar.gz' | head -1 | cut -d'"' -f4)

if [ -z "$URL" ]; then
    log "Не удалось получить URL релиза"
    echo "Не удалось получить URL релиза"
    exit 1
fi

log "Найден релиз: $URL"
echo "Найден релиз: $URL"

# Скачиваем
mkdir -p "$ZAPRET_TMP"
ARCHIVE="$ZAPRET_TMP/zapret.tar.gz"

if command -v curl >/dev/null 2>&1; then
    curl -sL --max-time 120 -o "$ARCHIVE" "$URL"
else
    wget -q -T 120 -O "$ARCHIVE" "$URL"
fi

if [ ! -s "$ARCHIVE" ]; then
    log "Ошибка скачивания"
    echo "Ошибка скачивания"
    exit 1
fi

# Распаковываем
cd "$ZAPRET_TMP" || exit 1
tar -xzf "$ARCHIVE"

# Ищем бинарники под mipsel
BIN_PATH=$(find "$ZAPRET_TMP" -type d -name "linux-mipsel" | head -1)
if [ -z "$BIN_PATH" ]; then
    log "Не найдена папка linux-mipsel в архиве"
    echo "Не найдена папка linux-mipsel в архиве"
    exit 1
fi

# Копируем новые бинарники в отдельную папку (НЕ перезаписываем рабочие!)
mkdir -p /opt/bin/zapret-new
cp -f "$BIN_PATH/nfqws" /opt/bin/zapret-new/ 2>/dev/null || true
cp -f "$BIN_PATH/tpws"  /opt/bin/zapret-new/ 2>/dev/null || true
cp -f "$BIN_PATH/ip2net" /opt/bin/zapret-new/ 2>/dev/null || true
cp -f "$BIN_PATH/mdig"  /opt/bin/zapret-new/ 2>/dev/null || true

chmod +x /opt/bin/zapret-new/* 2>/dev/null || true

log "Новые бинарники скачаны в /opt/bin/zapret-new/"
echo "Новые бинарники скачаны в /opt/bin/zapret-new/"
echo "Проверь их работоспособность и скопируй в /opt/bin/ вручную:"
echo "  cp /opt/bin/zapret-new/nfqws /opt/bin/"
echo "  cp /opt/bin/zapret-new/tpws /opt/bin/"
