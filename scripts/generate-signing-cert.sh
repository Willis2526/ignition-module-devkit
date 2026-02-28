#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 5 || $# -gt 6 ]]; then
  echo "Usage: $0 <cert_dir> <cert_name> <cert_cn> <key_alias> <cert_password> [days]" >&2
  exit 1
fi

cert_dir="$1"
cert_name="$2"
cert_cn="$3"
key_alias="$4"
cert_password="$5"
days="${6:-825}"

mkdir -p "$cert_dir"

key_pem="$cert_dir/$cert_name.key.pem"
cert_pem="$cert_dir/$cert_name.cert.pem"
keystore_p12="$cert_dir/$cert_name.p12"
chain_p7b="$cert_dir/$cert_name.chain.p7b"

openssl req -x509 -newkey rsa:3072 -sha256 -nodes \
  -keyout "$key_pem" \
  -out "$cert_pem" \
  -days "$days" \
  -subj "/CN=$cert_cn"

openssl pkcs12 -export \
  -inkey "$key_pem" \
  -in "$cert_pem" \
  -name "$key_alias" \
  -out "$keystore_p12" \
  -passout "pass:$cert_password"

openssl crl2pkcs7 -nocrl \
  -certfile "$cert_pem" \
  -out "$chain_p7b" \
  -outform DER

echo "Generated signing assets:"
echo "  Certificate: $cert_pem"
echo "  Private key: $key_pem"
echo "  PKCS12 keystore: $keystore_p12"
echo "  PKCS7 chain: $chain_p7b"
