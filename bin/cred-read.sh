#!/usr/bin/env bash
# Prints one secret from the credential store (Keychain / Secret Service).
# Tokens are not exported from ~/.zshrc, so scripts that run outside a shell
# that sourced it look them up with this, on demand.
#   cred-read.sh <service-name>   e.g. morrisonexpress.atlassian.net

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/init-lib.sh"

[ -n "${1:-}" ] || { echo "usage: cred-read.sh <service-name>" >&2; exit 2; }
cred_find "$1"
