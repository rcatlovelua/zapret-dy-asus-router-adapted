<div align="center">

# zapret-dy-asus-router-adapted

**Адаптированная сборка zapret для роутеров ASUS на Asuswrt / Asuswrt-Merlin / Padavan**

Форк [Flowseal/zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube) на базе [bol-van/zapret](https://github.com/bol-van/zapret)

</div>

> [!CAUTION]
> Это не оффициальный zapret-discord-youtube
> не доверяешь - уйди, но не хейти

> [!IMPORTANT]
>
> Все бинарники в папке [`bin`](./bin) взяты из [zapret/releases](https://github.com/bol-van/zapret/releases) (архитектура **mipsel**). Вы можете проверить это с помощью хэшей/контрольных сумм.
>
> #### Проверяйте, что запускаете, используя сборки из интернета, и не используйте Яндекс Поиск! Он часто предлагает вредоносы по первым ссылкам, а настоящий репозиторий скрыт.

> [!WARNING]
>
> ### АНТИВИРУСЫ И DPI
> `nfqws` и `tpws` — это инструменты для перехвата и модификации трафика, необходимые для работы zapret.
> Они могут использоваться как хорошими, так и плохими программами, но сами по себе не являются вирусом.
> Некоторые антивирусы и провайдеры могут реагировать на них настороженно — это нормально.

## ⚙️Установка

1.  **Установите Entware** на USB-флешку (рекомендуется, минимум 256 МБ). Не ставьте на `/jffs` — пожалейте flash.
    *   Для Asuswrt / Merlin: включите JFFS, включите SSH, подключите USB, установите Entware.
    *   Для Padavan: включите Entware в веб-интерфейсе, перезагрузите роутер.

2.  **Скачайте репозиторий** на флешку:
```
cd /opt
git clone https://github.com/cratlovelua/zapret-dy-asus-router-adapted.git
cd zapret-dy-asus-router-adapted
```

3.  **Запустите установщик** — он сам определит архитектуру (`mipsel`) и разложит бинарники:
```
./install.sh
```

4.  **Выберите стратегию** и запустите:
```
/opt/etc/init.d/S99zapret start
```
    По умолчанию — `tpws/DEFAULT` (прокси-режим, лёгкий для RT-AC51U).

5.  **Проверьте статус**:
```
/opt/etc/init.d/S99zapret status
```

## 🎛️Управление

| Команда | Что делает |
|---|---|
| `/opt/etc/init.d/S99zapret start` | Запуск обхода |
| `/opt/etc/init.d/S99zapret stop` | Остановка |
| `/opt/etc/init.d/S99zapret restart` | Перезапуск |
| `/opt/etc/init.d/S99zapret status` | Проверка статуса |

**Смена стратегии**:
```
ZAPRET_STRATEGY="tpws/ALT9" /opt/etc/init.d/S99zapret restart
```

Доступные стратегии:
- `tpws/DEFAULT` — базовая (рекомендуется для RT-AC51U)
- `tpws/ALT9` — Discord + YouTube
- `tpws/ALT10` — мягкая
- `nfqws/DEFAULT` — NFQUEUE (только если хватает RAM, **конфликтует с HW offload**)
- `nfqws/FAKE` — fake-пакеты
- `nfqws/SPLIT` — фрагментация ClientHello

## 🔄Автообновление

Два скрипта в корне репо:

| Скрипт | Что обновляет | Откуда |
|---|---|---|
| `update-lists.sh` | Списки доменов/IP + фейки | Flowseal |
| `update-binaries.sh` | Бинарники (`nfqws`, `tpws`, `ip2net`, `mdig`) | bol-van releases |

### Настройка cron

Добавь в `/opt/etc/crontab`:
```
# Обновление списков и фейков — раз в 2 дня в 4:00
0 4 */2 * * /opt/zapret-dy-asus-router-adapted/update-lists.sh

# Проверка новых бинарников — раз в неделю в 5:00
0 5 * * 0 /opt/zapret-dy-asus-router-adapted/update-binaries.sh
```

**Важно**: слишком частая запись убивает флеш-память. Раз в 2 дня для списков — разумный компромисс.

## ☑️Распространенные вопросы и проблемы

### После запуска ничего не происходит

- Проверь `status` — процесс `tpws` или `nfqws` должен быть запущен.
- Проверь лог: `/opt/var/log/zapret.log`.
- Убедись, что Entware работает и `/opt/bin/tpws` существует.

### Ни одна стратегия не подходит

- Убедись, что установлен Entware и зависимости (`iptables`, `ipset`, `conntrack`).
- Сбрось сетевые счётчики: `conntrack -F`.
- Перезагрузи роутер.
- Попробуй `tpws` вместо `nfqws` (он легче и не конфликтует с HW offload).

### Не работает Telegram (веб версия)

- На роутере проще использовать десктопный Telegram с локальным прокси [tg-ws-proxy](https://github.com/Flowseal/tg-ws-proxy) или любым публичным MTProto-прокси.

### Обход не работает / перестал работать

> [!IMPORTANT]
> **Стратегии со временем могут переставать работать.**
> В репозитории представлены несколько стратегий для обхода. Если ни одна из них вам не помогает, то вам необходимо создать новую, взяв за основу одну из представленных здесь и изменив её параметры.

- Запусти `update-lists.sh` — возможно, просто устарели списки.
- Проверь другие стратегии (`ALT9`, `ALT10`, `FAKE`, `SPLIT`).
- См. [Issues](https://github.com/cratlovelua/zapret-dy-asus-router-adapted/issues).

### Не работает игра/приложение с включённым запретом

- Проверь, что в стратегии нет `IPSET_FILTER=any`. Иначе это может затронуть доступность ресурсов, которых вы не ожидали.

### Не работает YouTube

- Убедись, что настроен Secure DNS (DoH/DoT) — на роутере можно через `dnsmasq` + `https-dns-proxy` или через настройки Asuswrt.
- Отключи блокировщик рекламы.
- Пробуй другие стратегии.

### Не работает Discord

- Убедись, что настроен Secure DNS.
- Запусти `update-lists.sh`.
- Проверь приложение Discord на ПК.
- См. [Discussion #252](https://github.com/Flowseal/zapret-discord-youtube/discussions/252).

### Не работают игры

Наиболее универсальный рецепт:
- Через `update-lists.sh` обнови `ipset-all.txt`.
- Если не поможет — выясни IP-адреса игры и добавь их в `ipset-all.txt`.

## 🗒️Добавление своих адресов

Список адресов для обхода можно расширить, добавляя их в:
- **`lists/list-general-user.txt`** — домены (поддомены учитываются автоматически)
- **`lists/list-exclude-user.txt`** — исключения доменов
- **`lists/ipset-all-user.txt`** — IP и подсети
- **`lists/ipset-exclude-user.txt`** — исключения IP

Файлы `*-user.txt` автоматически создадутся при первом запуске.

## ⭐Поддержка проекта

Поставь :star: этому репозиторию.

Также можешь материально поддержать оригинального разработчика zapret [тут](https://github.com/bol-van/zapret?tab=readme-ov-file#%D0%BF%D0%BE%D0%B4%D0%B4%D0%B5%D1%80%D0%B6%D0%B0%D1%82%D1%8C-%D1%80%D0%B0%D0%B7%D1%80%D0%B0%D0%B1%D0%BE%D1%82%D1%87%D0%B8%D0%BA%D0%B0).

## ⚖️Лицензирование

Проект распространяется на условиях лицензии [MIT](https://github.com/Flowseal/zapret-discord-youtube/blob/main/LICENSE.txt).

## 🩷Благодарность

[![Contributors](https://contrib.rocks/image?repo=Flowseal/zapret-discord-youtube)](https://github.com/Flowseal/zapret-discord-youtube/graphs/contributors)

💖 Отдельная благодарность разработчику [zapret](https://github.com/bol-van/zapret) — [bol-van](https://github.com/bol-van).
