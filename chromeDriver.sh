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
