#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <module_dir> <license_mode> [custom_license_text]" >&2
  echo "Modes: apache, proprietary, trial, custom" >&2
  exit 1
fi

module_dir="$1"
license_mode="$2"
custom_license="${3:-}"
props_file="$module_dir/gradle.properties"

if [[ ! -f "$props_file" ]]; then
  echo "Error: '$props_file' not found." >&2
  exit 1
fi

case "$license_mode" in
  apache)
    license_value="Apache-2.0"
    ;;
  proprietary)
    license_value="Proprietary"
    ;;
  trial)
    license_value="Trial"
    ;;
  custom)
    if [[ -z "$custom_license" ]]; then
      echo "Error: custom mode requires custom_license_text." >&2
      exit 1
    fi
    license_value="$custom_license"
    ;;
  *)
    echo "Error: unsupported license mode '$license_mode'." >&2
    echo "Supported: apache, proprietary, trial, custom" >&2
    exit 1
    ;;
esac

tmp_file="$(mktemp)"
awk -v line="moduleLicense=$license_value" '
  BEGIN { replaced = 0 }
  /^moduleLicense=/ {
    print line
    replaced = 1
    next
  }
  { print }
  END {
    if (replaced == 0) {
      print line
    }
  }
' "$props_file" > "$tmp_file"

mv "$tmp_file" "$props_file"

echo "Updated module license in '$props_file' to '$license_value'"
