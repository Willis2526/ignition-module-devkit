#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <output_jar_path> [direct_jar_url]" >&2
  exit 1
fi

output_jar="$1"
direct_url="${2:-}"

nexus_base="${MODULE_SIGNER_NEXUS_BASE:-https://nexus.inductiveautomation.com/repository/inductiveautomation-releases}"
group_id="${MODULE_SIGNER_GROUP_ID:-com.inductiveautomation.ignitionsdk}"
artifact_id="${MODULE_SIGNER_ARTIFACT_ID:-module-signer}"
fallback_url="${MODULE_SIGNER_FALLBACK_URL:-}"

mkdir -p "$(dirname "$output_jar")"

download_from_url() {
  local url="$1"
  echo "Downloading module-signer from: $url"
  curl -fL "$url" -o "$output_jar"
}

resolve_latest_from_nexus() {
  local group_path metadata_url metadata version artifact_url
  group_path="${group_id//./\/}"
  metadata_url="${nexus_base%/}/${group_path}/${artifact_id}/maven-metadata.xml"
  metadata="$(curl -fsSL "$metadata_url")"

  version="$(printf '%s' "$metadata" | sed -n 's|.*<release>\(.*\)</release>.*|\1|p' | head -n 1)"
  if [[ -z "$version" ]]; then
    version="$(printf '%s' "$metadata" | sed -n 's|.*<latest>\(.*\)</latest>.*|\1|p' | head -n 1)"
  fi
  if [[ -z "$version" ]]; then
    version="$(printf '%s' "$metadata" | sed -n 's|.*<version>\(.*\)</version>.*|\1|p' | tail -n 1)"
  fi
  if [[ -z "$version" ]]; then
    echo "Error: could not resolve latest version from $metadata_url" >&2
    return 1
  fi

  artifact_url="${nexus_base%/}/${group_path}/${artifact_id}/${version}/${artifact_id}-${version}.jar"
  download_from_url "$artifact_url"
}

if [[ -n "$direct_url" ]]; then
  download_from_url "$direct_url"
else
  if ! resolve_latest_from_nexus; then
    if [[ -n "$fallback_url" ]]; then
      echo "Nexus resolution failed. Trying fallback URL..." >&2
      download_from_url "$fallback_url"
    else
      echo "Error: failed to download module-signer from Nexus and no fallback URL provided." >&2
      exit 1
    fi
  fi
fi

echo "Downloaded signer jar to '$output_jar'"
