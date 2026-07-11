#!/bin/bash

# Utility to check if an i18n key or value exists.
# Checks commons by default; pass an optional [module] to also search that
# module's namespace (module matches take precedence over commons).
# Auto-syncs a local i18n cache (timestamp-gated) before looking up.

BASE_URL="https://one-static.morrison.express/i18n/prod"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/mop-i18n"
TS_FILE="$CACHE_DIR/timestamp.json"
COMMONS_FILE="$CACHE_DIR/commons.json"

# Sync the local i18n cache only when the deployed timestamp differs.
sync_i18n() {
  mkdir -p "$CACHE_DIR"

  local remote_ts
  if ! remote_ts=$(curl -fsS --max-time 15 "$BASE_URL/timestamp.json"); then
    if [ -f "$COMMONS_FILE" ]; then
      echo "Warning: could not reach i18n service; using cached data." >&2
      return 0
    fi
    echo "Error: could not reach i18n service and no local cache exists." >&2
    return 1
  fi

  local local_ts=""
  [ -f "$TS_FILE" ] && local_ts=$(cat "$TS_FILE")
  if [ "$remote_ts" = "$local_ts" ]; then
    return 0
  fi

  local tmp_dir
  tmp_dir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp_dir'" RETURN

  local modules
  if ! modules=$(curl -fsS --max-time 15 "$BASE_URL/index.json" | jq -r '.[]'); then
    echo "Error: failed to fetch i18n module index." >&2
    return 1
  fi

  local count=0
  local module
  while IFS= read -r module; do
    [ -z "$module" ] && continue
    if ! curl -fsS --max-time 15 "$BASE_URL/$module.json" -o "$tmp_dir/$module.json"; then
      echo "Error: failed to download module '$module'." >&2
      return 1
    fi
    if ! jq empty "$tmp_dir/$module.json" 2>/dev/null; then
      echo "Error: invalid JSON for module '$module'." >&2
      return 1
    fi
    count=$((count + 1))
  done <<< "$modules"

  mv "$tmp_dir"/*.json "$CACHE_DIR"/
  printf '%s' "$remote_ts" > "$TS_FILE"
  echo "i18n cache updated ($count modules)." >&2
}

INPUT="$1"
MODULE="$2"

if [ -z "$INPUT" ]; then
  echo "Usage: $0 <key_or_value> [module]" >&2
  exit 1
fi

sync_i18n || exit 1

if [ ! -f "$COMMONS_FILE" ]; then
  echo "Error: i18n cache is unavailable ($COMMONS_FILE missing)." >&2
  exit 1
fi

# Normalize input key (strip a leading 'commons.' or '<module>.' namespace prefix)
CLEAN_KEY="${INPUT#commons.}"
[ -n "$MODULE" ] && CLEAN_KEY="${CLEAN_KEY#"$MODULE".}"

# Emit one JSON array of {path,key,value} entries for a namespace inside a file.
build_entries() {
  # $1 = json file, $2 = namespace key under .enLang (also used as path prefix)
  jq -c --arg p "$2" '(.enLang[$p] // {}) | to_entries
    | map({path: ($p + "." + .key), key: .key, value: .value})' "$1"
}

# Module entries come first so they win exact-match ties over commons.
MODULE_SCOPE="commons only"
if [ -n "$MODULE" ] && [ "$MODULE" != "commons" ]; then
  if [ -f "$CACHE_DIR/$MODULE.json" ]; then
    MODULE_SCOPE="$MODULE + commons"
  else
    echo "Warning: module '$MODULE' not found in cache; searching commons only." >&2
    MODULE=""
  fi
fi

echo "Checking i18n key/value: '$INPUT' (Key check: '$CLEAN_KEY') in $MODULE_SCOPE..." >&2

ENTRIES=$(
  {
    if [ -n "$MODULE" ] && [ "$MODULE" != "commons" ]; then
      build_entries "$CACHE_DIR/$MODULE.json" "$MODULE"
    fi
    build_entries "$COMMONS_FILE" "commons"
  } | jq -sc 'add'
)

printf '%s' "$ENTRIES" | jq -r --arg input "$INPUT" --arg key "$CLEAN_KEY" '
  . as $entries |

  # 1. Exact KEY match (e.g. "submit", "commons.submit", "billing.submit" -> "submit")
  ($entries | map(select(.key == $key))) as $key_matches |
  if ($key_matches | length) > 0 then
    "EXACT_KEY_MATCH: " + $key_matches[0].path + " -> \"" + $key_matches[0].value + "\""
  else
    # 2. Exact VALUE match (e.g. "Submit")
    ($entries | map(select(.value == $input))) as $exact_matches |
    if ($exact_matches | length) > 0 then
      "EXACT_VALUE_MATCH: " + $exact_matches[0].path + " -> \"" + $exact_matches[0].value + "\""
    else
      # 3. SIMILAR values (case-insensitive substring match)
      ($entries | map(select(.value | ascii_downcase | contains($input | ascii_downcase)))) as $similar_matches |
      if ($similar_matches | length) > 0 then
        "SIMILAR_MATCHES:\n" + ($similar_matches | map("- " + .path + ": \"" + .value + "\"") | join("\n"))
      else
        "NO_MATCH"
      end
    end
  end
'
