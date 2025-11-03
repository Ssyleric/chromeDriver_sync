# Synchronisation `chromedriver` ↔ `Google Chrome` (Ubuntu)

**Dernière mise à jour :** 2025-11-03 15:15

Ce guide explique comment garder **chromedriver** aligné automatiquement avec la version installée de **Google Chrome**.  
Il inclut : un script robuste (`/home/scripts/chromeDriver.sh`) et une planification via **cron** (ou, en option, un **timer systemd**).

---

## 🎯 Objectif
Éviter les erreurs du type :
> The chromedriver version ... might not be compatible with the detected chrome version ...

En téléchargeant **exactement** la version correspondante depuis **Chrome for Testing** et en l’installant dans `/usr/local/bin/chromedriver`.

---

## ✅ Prérequis
- Ubuntu (ou Debian-like) avec `curl`, `unzip` et `util-linux` (pour `flock`)
- Chrome installé (`google-chrome --version` doit fonctionner)
- Droits `root` pour installer dans `/usr/local/bin`

```bash
sudo apt update
sudo apt install -y curl unzip
```

---

## 🧩 Installation du script
1) Créer le dossier scripts (si nécessaire) :
```bash
sudo mkdir -p /home/scripts
```

2) Créer/mettre à jour le script `/home/scripts/chromeDriver.sh` :
```bash
sudo nano /home/scripts/chromeDriver.sh
```

3) Coller **le contenu ci‑dessous**, sauvegarder, rendre exécutable :
```bash
sudo chmod +x /home/scripts/chromeDriver.sh
```

### Contenu recommandé de `/home/scripts/chromeDriver.sh`
```bash
#!/usr/bin/env bash
set -Eeuo pipefail

# -- Config --
DRIVER_DST="/usr/local/bin/chromedriver"

# -- Fonctions utilitaires --
log(){ printf "[%(%F %T)T] %s\n" -1 "$*"; }
die(){ log "❌ $*"; exit 1; }

# -- Trouver Google Chrome --
if command -v google-chrome >/dev/null 2>&1; then
  CHROME_BIN="google-chrome"
elif command -v google-chrome-stable >/dev/null 2>&1; then
  CHROME_BIN="google-chrome-stable"
else
  die "Google Chrome introuvable. Installe-le puis relance le script."
fi

CHROME_VER="$($CHROME_BIN --version | awk '{print $3}')"
[[ -n "${CHROME_VER:-}" ]] || die "Impossible de lire la version de Chrome."

# -- Si chromedriver existe déjà, comparer les versions --
CURRENT_DRV_VER=""
if [[ -x "$DRIVER_DST" ]]; then
  CURRENT_DRV_VER="$( "$DRIVER_DST" --version 2>/dev/null | awk '{print $2}' )" || true
fi

if [[ "$CURRENT_DRV_VER" == "$CHROME_VER" ]]; then
  log "✅ Déjà à jour : chromedriver=$CURRENT_DRV_VER | chrome=$CHROME_VER"
  exit 0
fi

# -- Télécharger le driver correspondant via Chrome for Testing --
URL="https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VER}/linux64/chromedriver-linux64.zip"
TMPDIR="$(mktemp -d)"
cleanup(){ rm -rf "$TMPDIR"; }
trap cleanup EXIT

log "⬇️  Téléchargement : $URL"
curl -fL --connect-timeout 10 --retry 3 --retry-delay 1 -o "$TMPDIR/chromedriver.zip" "$URL" \
  || die "Téléchargement impossible pour la version $CHROME_VER (URL invalide ? Chrome pas encore à jour côté Google ?)"

log "📦 Décompression"
unzip -o -q "$TMPDIR/chromedriver.zip" -d "$TMPDIR"

log "🛠️  Installation vers $DRIVER_DST"
install -m 0755 "$TMPDIR/chromedriver-linux64/chromedriver" "$DRIVER_DST"

NEW_VER="$( "$DRIVER_DST" --version | awk '{print $2}' )"
if [[ "$NEW_VER" != "$CHROME_VER" ]]; then
  die "Mismatch après installation: driver=$NEW_VER vs chrome=$CHROME_VER"
fi

log "✅ chromedriver $NEW_VER installé (aligné sur Chrome $CHROME_VER)"
```

4) Test manuel :
```bash
sudo /home/scripts/chromeDriver.sh
chromedriver --version
google-chrome --version
```

---

## ⏱️ Planification avec `cron`
Édite la **crontab root** :
```bash
sudo crontab -e
```
Ajoute **une** ligne (exécuter tous les vendredis à 08:00) :
```cron
0 8 * * 5 bash /home/scripts/chromeDriver.sh
```

---

## 🧪 Smoke test Robot Framework
`sanity.robot` :
```robot
*** Settings ***
Library    SeleniumLibrary

*** Test Cases ***
Sanity Chrome
    Open Browser    https://example.com    chrome
    Page Should Contain    Example Domain
    [Teardown]    Close Browser
```

Exécution :
```bash
which robot || python3 -m pip install -U robotframework selenium robotframework-seleniumlibrary
robot sanity.robot
```

---

## 🛠️ Dépannage
- **Mismatch persistant** : un ancien `chromedriver` peut traîner dans le PATH :
  ```bash
  type -a chromedriver
  sudo rm -f /usr/bin/chromedriver ~/.local/bin/chromedriver
  ```
- **Proxy** : définir `HTTPS_PROXY`, `HTTP_PROXY`, `NO_PROXY` si besoin.
- **Permissions** : le script installe dans `/usr/local/bin` → nécessite `root`.

---

## ✅ Résumé
- Script robuste : `/home/scripts/chromeDriver.sh`
- Installation dans : `/usr/local/bin/chromedriver`
- Planification via cron
- Compatible Ubuntu 24.04+ (Noble) / Chrome stable

Bon tests ! 🧪🚀
