#!/usr/bin/env bash
# Xenoglyph — Floating Runes (KWin Script): install.  ./install.sh
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DST=${XDG_DATA_HOME:-$HOME/.local/share}/kwin/scripts/xenoglyph_runes
rm -rf "$DST"; mkdir -p "$DST"
for f in "$HERE"/* "$HERE"/.[!.]*; do
    [[ -e $f ]] || continue
    case ${f##*/} in README.md|LICENSE|install.sh|screenshots|.git) continue ;; esac
    cp -r "$f" "$DST"/
done
kwriteconfig6 --file kwinrc --group Plugins --key xenoglyph_runesEnabled true
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript xenoglyph_runes >/dev/null 2>&1 || true
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null 2>&1 || true
