#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 8 || $# -gt 10 ]]; then
  echo "Usage: $0 <module_dir> <signer_jar> <keystore_path> <keystore_password> <key_alias> <alias_password> <cert_chain_path> [module_in] [module_out]" >&2
  exit 1
fi

module_dir="$1"
signer_jar="$2"
keystore_path="$3"
keystore_password="$4"
key_alias="$5"
alias_password="$6"
cert_chain_path="$7"
module_in="${8:-}"
module_out="${9:-}"
host_workspace_root="$(pwd -P)"

if [[ ! -d "$module_dir" ]]; then
  echo "Error: module directory '$module_dir' does not exist." >&2
  exit 1
fi

if [[ ! -f "$signer_jar" ]]; then
  echo "Signer jar '$signer_jar' not found. Downloading latest..." >&2
  "$(dirname "$0")/download-module-signer.sh" "$signer_jar"
fi

if [[ ! -f "$keystore_path" ]]; then
  echo "Error: keystore '$keystore_path' not found." >&2
  exit 1
fi

if [[ ! -f "$cert_chain_path" ]]; then
  echo "Error: cert chain '$cert_chain_path' not found." >&2
  exit 1
fi

if [[ -z "$module_in" ]]; then
  module_in="$(find "$module_dir/build" -type f -name '*.unsigned.modl' -print 2>/dev/null | sort | tail -n 1 || true)"
  if [[ -z "$module_in" ]]; then
    echo "Error: no '*.unsigned.modl' found in '$module_dir/build'." >&2
    echo "Build first (make module-build MODULE_DIR=$module_dir) or set MODULE_IN explicitly." >&2
    exit 1
  fi
fi

if [[ ! -f "$module_in" ]]; then
  echo "Error: module input '$module_in' not found." >&2
  exit 1
fi

if [[ -z "$module_out" ]]; then
  if [[ "$module_in" == *.unsigned.modl ]]; then
    module_out="${module_in%.unsigned.modl}.signed.modl"
  else
    module_out="${module_in%.modl}.signed.modl"
  fi
fi

to_container_path() {
  local p="$1"
  if [[ "$p" == /workspace/* ]]; then
    printf '%s' "$p"
  elif [[ "$p" == /* ]]; then
    case "$p" in
      "$host_workspace_root"/*)
        printf '/workspace/%s' "${p#"$host_workspace_root"/}"
        ;;
      *)
        echo "Error: absolute path '$p' is outside the repository bind mount." >&2
        echo "Use a path under '$host_workspace_root' or a repo-relative path." >&2
        exit 1
        ;;
    esac
  else
    printf '/workspace/%s' "$p"
  fi
}

signer_jar_c="$(to_container_path "$signer_jar")"
keystore_path_c="$(to_container_path "$keystore_path")"
cert_chain_path_c="$(to_container_path "$cert_chain_path")"
module_in_c="$(to_container_path "$module_in")"
module_out_c="$(to_container_path "$module_out")"

if ! docker compose ps --status running dev >/dev/null 2>&1; then
  echo "Error: dev container is not running. Start it with 'make dev-up'." >&2
  exit 1
fi

docker compose exec -T dev java -jar "$signer_jar_c" \
  "-keystore=$keystore_path_c" \
  "-keystore-pwd=$keystore_password" \
  "-alias=$key_alias" \
  "-alias-pwd=$alias_password" \
  "-chain=$cert_chain_path_c" \
  "-module-in=$module_in_c" \
  "-module-out=$module_out_c"

echo "Signed module written to '$module_out'"
