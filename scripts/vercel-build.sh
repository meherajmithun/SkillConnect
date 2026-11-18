#!/usr/bin/env bash
set -euo pipefail

flutter_version="3.47.2"
flutter_root="${FLUTTER_ROOT:-/tmp/skillconnect-flutter-${flutter_version}}"

if command -v flutter >/dev/null 2>&1; then
  flutter_command="$(command -v flutter)"
else
  if [[ ! -x "${flutter_root}/bin/flutter" ]]; then
    git clone --depth 1 --branch "${flutter_version}" \
      https://github.com/flutter/flutter.git "${flutter_root}"
  fi
  flutter_command="${flutter_root}/bin/flutter"
fi

"${flutter_command}" config --no-analytics

(
  cd mobile
  "${flutter_command}" pub get
  "${flutter_command}" build web --release
)

mkdir -p public/admin
cp -R mobile/build/web/. public/
cp -R backend/public/. public/admin/
