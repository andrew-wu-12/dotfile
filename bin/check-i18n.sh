#!/bin/bash

# Utility to check if an i18n key or value exists in commons.json.
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

if [ -z "$INPUT" ]; then
  echo "Usage: $0 <key_or_value>" >&2
  exit 1
fi

sync_i18n || exit 1

if [ ! -f "$COMMONS_FILE" ]; then
  echo "Error: i18n cache is unavailable ($COMMONS_FILE missing)." >&2
  exit 1
fi

# Normalize input key (strip 'commons.' prefix if present)
CLEAN_KEY="${INPUT#commons.}"

echo "Checking i18n key/value: '$INPUT' (Key check: '$CLEAN_KEY') in commons.json..." >&2

# We use a single jq script to check both key and value
jq -r --arg input "$INPUT" --arg key "$CLEAN_KEY" '
  .enLang.commons as $dict |

  # 1. Check if input is an exact KEY (e.g. "submit" or "commons.submit" -> "submit")
  if ($dict[$key] != null) then
    "EXACT_KEY_MATCH: commons." + $key + " -> \"" + $dict[$key] + "\""
  else
    # 2. Check if input is an exact VALUE (e.g. "Submit")
    ($dict | to_entries | map(select(.value == $input))) as $exact_matches |

    if ($exact_matches | length) > 0 then
      "EXACT_VALUE_MATCH: commons." + $exact_matches[0].key + " -> \"" + $exact_matches[0].value + "\""
    else
      # 3. Check for SIMILAR VALUES (Case-insensitive fuzzy match)
      ($dict | to_entries | map(select(.value | ascii_downcase | contains($input | ascii_downcase)))) as $similar_matches |

      if ($similar_matches | length) > 0 then
        "SIMILAR_MATCHES:\n" + ($similar_matches | map("- commons." + .key + ": \"" + .value + "\"") | join("\n"))
      else
        "NO_MATCH"
      end
    end
  end
' "$COMMONS_FILE"
