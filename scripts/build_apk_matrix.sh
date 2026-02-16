#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Build 2 APK variants: v7a/v8a with plugins enabled"
  echo
  echo "Usage:"
  echo "  bash scripts/build_apk_matrix.sh [extra flutter build apk args]"
  echo
  echo "Examples:"
  echo "  bash scripts/build_apk_matrix.sh"
  echo "  bash scripts/build_apk_matrix.sh --obfuscate --split-debug-info=build/symbols"
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/build/apk-matrix"
FLUTTER_OUTPUT_DIR="$ROOT_DIR/build/app/outputs/flutter-apk"
EXTRA_ARGS=("$@")

mkdir -p "$OUTPUT_DIR"

echo
echo "==> Building armeabi-v7a + arm64-v8a (plugins-on)"

cmd=(
  flutter build apk
  --release
  --split-per-abi
  --target-platform android-arm,android-arm64
  --dart-define=ENABLE_PLUGINS=true
)
if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  cmd+=("${EXTRA_ARGS[@]}")
fi
"${cmd[@]}"

# Copy output APKs
for abi_pair in "armeabi-v7a:v7a" "arm64-v8a:v8a"; do
  abi="${abi_pair%%:*}"
  name="${abi_pair##*:}"
  src_apk="$FLUTTER_OUTPUT_DIR/app-$abi-release.apk"
  dst_apk="$OUTPUT_DIR/$name.apk"

  if [[ ! -f "$src_apk" ]]; then
    echo "ERROR: Expected APK not found: $src_apk" >&2
    exit 1
  fi

  cp "$src_apk" "$dst_apk"
  echo "Saved: $dst_apk"
done

echo
echo "Done. Output files:"
ls -lh "$OUTPUT_DIR"
