#!/usr/bin/env bash
# Stores the macOS signing and notarization secrets in the GitHub "release" environment (memory/release-update.md).
# Run it yourself in a terminal: every secret is typed at a hidden prompt and piped to `gh secret set` on stdin,
# so nothing lands in shell history, process arguments or logs.
#
# Usage:
#   .github/scripts/set-release-secrets.sh DeveloperID.p12              # existing .p12, you know its password
#   .github/scripts/set-release-secrets.sh developer-id.key cert.pem    # build a fresh .p12 with a new password
set -euo pipefail

repo=metin-aydin/Hopclick
env=release
[ $# -ge 1 ] || { sed -n '5,8p' "$0"; exit 1; }
for f in "$@"; do [ -f "$f" ] || { echo "No such file: $f" >&2; exit 1; }; done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [ $# -eq 2 ]; then
  key=$1 cert=$2
  # The key must belong to the certificate, or codesign finds no identity.
  if [ "$(openssl pkey -in "$key" -pubout | openssl sha256)" != "$(openssl x509 -in "$cert" -noout -pubkey | openssl sha256)" ]; then
    echo "$key does not match $cert; nothing was stored." >&2
    exit 1
  fi
  read -rsp "New password for the .p12: " p12pass; echo
  read -rsp "Repeat it: " again; echo
  [ -n "$p12pass" ] && [ "$p12pass" = "$again" ] || { echo "Passwords are empty or differ; nothing was stored." >&2; exit 1; }
  unset again
  p12=$work/DeveloperID.p12
  # SHA-1/3DES keeps the file readable by `security import` on every macOS runner and by OpenSSL 3 without -legacy.
  printf '%s' "$p12pass" | openssl pkcs12 -export -inkey "$key" -in "$cert" -name "Developer ID Application" \
    -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1 -out "$p12" -passout stdin
else
  p12=$1
  read -rsp "Password of $(basename "$p12"): " p12pass; echo
fi

# Check the password before storing anything.
if ! printf '%s' "$p12pass" | openssl pkcs12 -in "$p12" -noout -passin stdin 2>/dev/null \
   && ! printf '%s' "$p12pass" | openssl pkcs12 -legacy -in "$p12" -noout -passin stdin 2>/dev/null; then
  echo "The password does not open $p12; nothing was stored." >&2
  echo "If you do not know it, run: $0 developer-id.key cert.pem" >&2
  exit 1
fi

read -rp "Apple ID (email used for notarization): " appleid
read -rsp "App-specific password: " apppass; echo
[ -n "$appleid" ] && [ -n "$apppass" ] || { echo "Apple ID and app-specific password are required." >&2; exit 1; }

base64 -i "$p12" | tr -d '\n' | gh secret set CSC_LINK --repo "$repo" --env "$env"
printf '%s' "$p12pass" | gh secret set CSC_KEY_PASSWORD --repo "$repo" --env "$env"
printf '%s' "$appleid" | gh secret set APPLE_ID --repo "$repo" --env "$env"
printf '%s' "$apppass" | gh secret set APPLE_APP_SPECIFIC_PASSWORD --repo "$repo" --env "$env"
unset p12pass apppass

gh secret list --repo "$repo" --env "$env"
