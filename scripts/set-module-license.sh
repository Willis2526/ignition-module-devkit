#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <module_dir> <license_mode> [custom_license_text]" >&2
  echo "Modes: free, apache, proprietary, trial, custom" >&2
  exit 1
fi

module_dir="$1"
license_mode="$2"
custom_license="${3:-}"
props_file="$module_dir/gradle.properties"
license_file="$module_dir/LICENSE.txt"

if [[ ! -f "$props_file" ]]; then
  echo "Error: '$props_file' not found." >&2
  exit 1
fi

case "$license_mode" in
  free)
    license_text="Apache-2.0"
    free_value="true"
    ;;
  apache)
    license_text="Apache-2.0"
    free_value="true"
    ;;
  proprietary)
    license_text="Proprietary"
    free_value="false"
    ;;
  trial)
    license_text="Trial"
    free_value="false"
    ;;
  custom)
    if [[ -z "$custom_license" ]]; then
      echo "Error: custom mode requires custom_license_text." >&2
      exit 1
    fi
    license_text="$custom_license"
    free_value="false"
    ;;
  *)
    echo "Error: unsupported license mode '$license_mode'." >&2
    echo "Supported: free, apache, proprietary, trial, custom" >&2
    exit 1
    ;;
esac

printf '%s\n' "$license_text" > "$license_file"

tmp_file="$(mktemp)"
awk -v license_line="moduleLicense=LICENSE.txt" '
  BEGIN { replaced = 0 }
  /^moduleLicense=/ {
    print license_line
    replaced = 1
    next
  }
  { print }
  END {
    if (replaced == 0) {
      print license_line
    }
  }
' "$props_file" > "$tmp_file"

mv "$tmp_file" "$props_file"

tmp_file="$(mktemp)"
awk -v free_line="moduleFree=$free_value" '
  BEGIN { replaced = 0 }
  /^moduleFree=/ {
    print free_line
    replaced = 1
    next
  }
  { print }
  END {
    if (replaced == 0) {
      print free_line
    }
  }
' "$props_file" > "$tmp_file"

mv "$tmp_file" "$props_file"

echo "Updated module license mode in '$props_file' to '$license_mode' (license file: '$license_file')"
