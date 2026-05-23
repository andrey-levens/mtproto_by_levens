# mtproto_by_levens

Easy and fast MTProto proxy install for Telegram ([Telemt](https://github.com/telemt/telemt)).

Works with **XRay Full TUN** (dedicated install mode).
---------------------------------------------------------

Простая и быстрая установка прокси MTProto для Telegram ([Telemt](https://github.com/telemt/telemt)).

Работает с **XRay Full TUN** (специальный режим установки).

---

## 🇷🇺 Русский

Скрипт быстро установит MTProto-прокси на ваш VPS (Debian/Ubuntu, **root**).

**Проверено:** Telegram (20.05.26), Debian 12.

### Установка

Скопируйте и выполните на сервере:

```bash
curl -fsSL https://raw.githubusercontent.com/andrey-levens/mtproto_by_levens/main/mtproto.sh -o mtproto.sh && chmod +x mtproto.sh && bash mtproto.sh
```

Одной строкой без сохранения файла:

```bash
curl -fsSL https://raw.githubusercontent.com/andrey-levens/mtproto_by_levens/main/mtproto.sh | bash
```

### Режимы при установке

| Режим | Описание |
|--------|----------|
| **1 — Xray** | SNI = IP сервера. Рекомендуется, если включён Full TUN / XRay |
| **2 — Fake-TLS** | SNI = свой домен (`starlink.com` и т.д.) |

Без меню (флаги):

```bash
curl -fsSL https://raw.githubusercontent.com/andrey-levens/mtproto_by_levens/main/mtproto.sh -o mtproto.sh && chmod +x mtproto.sh && bash mtproto.sh --mode xray
```

```bash
curl -fsSL https://raw.githubusercontent.com/andrey-levens/mtproto_by_levens/main/mtproto.sh -o mtproto.sh && chmod +x mtproto.sh && bash mtproto.sh --mode faketls --sni starlink.com
```

### Канал-спонсор (@MTProxybot)

После установки скрипт попросит **ad_tag** от [@MTProxybot](https://t.me/MTProxybot).  
Добавить позже:

```bash
bash mtproto.sh --tag ВАШ_32_HEX_ТЕГ
```

---

## 🇬🇧 English

Quick Telegram MTProxy setup on your VPS (Debian/Ubuntu, **root**).

**Tested:** Telegram (20.05.26), Debian 12.

### Installation

Copy and run on the server:

```bash
curl -fsSL https://raw.githubusercontent.com/andrey-levens/mtproto_by_levens/main/mtproto.sh -o mtproto.sh && chmod +x mtproto.sh && bash mtproto.sh
```

One-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/andrey-levens/mtproto_by_levens/main/mtproto.sh | bash
```

### Modes

| Mode | Description |
|------|-------------|
| **1 — Xray** | SNI = server IP (works with XRay Full TUN) |
| **2 — Fake-TLS** | SNI = custom domain |

```bash
bash mtproto.sh --mode xray
```

```bash
bash mtproto.sh --mode faketls --sni starlink.com
```

---

## Notes

- Do not use the same port for **MTProxy** and **VLESS** on one server (e.g. MTProxy `443`, Xray `8443`).
- After install, use the **ee** link printed by the script in Telegram.
- Based on [telemt/telemt](https://github.com/telemt/telemt).
