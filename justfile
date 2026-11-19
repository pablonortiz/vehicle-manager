# Análisis estático y tests, antes de commitear
check:
    flutter analyze --no-fatal-infos
    flutter test

# APK release instalada en el celular conectado (USB o depuración inalámbrica), sin borrar sus datos
release-phone:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! grep -Eq '^SUPABASE_URL=https://[a-z0-9]+\.supabase\.co' .env || ! grep -Eq '^SUPABASE_ANON_KEY=.+' .env; then
        echo "El .env no tiene las credenciales reales de Supabase: la APK saldría sin sincronización." >&2
        exit 1
    fi
    phone=$(adb devices | awk 'NR > 1 && $2 == "device" && $1 !~ /^emulator-/ && !found { print $1; found = 1 }')
    if [[ -z "$phone" ]]; then
        echo "No hay ningún celular conectado: activá la depuración inalámbrica o conectalo por USB." >&2
        exit 1
    fi
    flutter build apk --release
    # install -r actualiza conservando los datos; flutter install desinstala antes y los borraría.
    adb -s "$phone" install -r build/app/outputs/flutter-apk/app-release.apk
