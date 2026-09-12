#!/bin/bash
# Собирает EyeBreak.app в ./dist и (опционально) ставит в /Applications
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=dist/EyeBreak.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/EyeBreak "$APP/Contents/MacOS/EyeBreak"
cp Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp -R Sounds "$APP/Contents/Resources/Sounds"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "Собрано: $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x EyeBreak 2>/dev/null || true
    rm -rf /Applications/EyeBreak.app
    cp -R "$APP" /Applications/EyeBreak.app
    open /Applications/EyeBreak.app
    echo "Установлено и запущено: /Applications/EyeBreak.app"
fi
