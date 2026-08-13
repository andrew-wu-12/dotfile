#!/bin/bash

# Utility to check if an i18n key or value exists.
# Searches ALL cached modules by default (so a reuse check doesn't need to know
# the namespace). Pass an optional [module] to scope to that module + commons
# (module matches take precedence); pass 'commons' to scope to commons only.
# Auto-syncs a local i18n cache (timestamp-gated) before looking up.
#
# Batch mode: check-i18n.sh --batch [module] <<< $'string one\nstring two\n...'
# Classifies every newline-delimited string from stdin in one process (one
# sync, one scope resolution, one jq pass) instead of one script invocation
# per string — a caller with N candidate strings gets one round trip, not N.

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

BATCH=false
if [ "$1" = "--batch" ]; then
  BATCH=true
  MODULE="$2"
  RAW_INPUTS="$(cat)"
  if [ -z "$RAW_INPUTS" ]; then
    echo "Usage: $0 --batch [module] <<< \$'string one\\nstring two'" >&2
    exit 1
  fi
else
  INPUT="$1"
  MODULE="$2"
  if [ -z "$INPUT" ]; then
    echo "Usage: $0 <key_or_value> [module]" >&2
    exit 1
  fi
fi

sync_i18n || exit 1

if [ ! -f "$COMMONS_FILE" ]; then
  echo "Error: i18n cache is unavailable ($COMMONS_FILE missing)." >&2
  exit 1
fi

# Normalize a key input: strip a leading '<namespace>.' so a full key like
# "tms.consol_no" also matches by its bare key "consol_no".
if [ "$BATCH" = false ]; then
  CLEAN_KEY="${INPUT#commons.}"
  [ -n "$MODULE" ] && CLEAN_KEY="${CLEAN_KEY#"$MODULE".}"
fi

# Emit a JSON array of {path,key,value} for every namespace in a file's .enLang.
file_entries() {
  jq -c '(.enLang // {}) | to_entries
    | map(.key as $p | ((.value // {}) | to_entries
        | map({path: ($p + "." + .key), key: .key, value: .value})))
    | add // []' "$1"
}

# Scope: a specific module (+ commons) if given; 'commons' for commons only;
# otherwise EVERY cached module (the default reuse check).
if [ -n "$MODULE" ] && [ "$MODULE" != "commons" ]; then
  if [ -f "$CACHE_DIR/$MODULE.json" ]; then
    SCOPE="$MODULE + commons"
    # Module entries first so they win exact-match ties over commons.
    ENTRIES=$( { file_entries "$CACHE_DIR/$MODULE.json"; file_entries "$COMMONS_FILE"; } | jq -sc 'add' )
  else
    echo "Warning: module '$MODULE' not found in cache; searching all modules." >&2
    MODULE=""
  fi
fi
if [ -z "${SCOPE:-}" ]; then
  if [ "$MODULE" = "commons" ]; then
    SCOPE="commons only"
    ENTRIES=$( file_entries "$COMMONS_FILE" )
  else
    SCOPE="all modules"
    ENTRIES=$(
      for f in "$CACHE_DIR"/*.json; do
        b=$(basename "$f" .json)
        if [ "$b" = "timestamp" ] || [ "$b" = "index" ]; then continue; fi
        file_entries "$f"
      done | jq -sc 'add'
    )
  fi
fi

if [ "$BATCH" = false ]; then
  echo "Checking i18n key/value: '$INPUT' (Key check: '$CLEAN_KEY') in $SCOPE..." >&2

  printf '%s' "$ENTRIES" | jq -r --arg input "$INPUT" --arg key "$CLEAN_KEY" '
    . as $entries |

    # 1. Exact KEY match: bare key ("consol_no") or full path ("tms.consol_no").
    ($entries | map(select(.key == $key or .path == $input))) as $key_matches |
    if ($key_matches | length) > 0 then
      "EXACT_KEY_MATCH: " + $key_matches[0].path + " -> \"" + $key_matches[0].value + "\""
    else
      # 2. Exact VALUE match (e.g. "Submit")
      ($entries | map(select(.value == $input))) as $exact_matches |
      if ($exact_matches | length) > 0 then
        "EXACT_VALUE_MATCH: " + $exact_matches[0].path + " -> \"" + $exact_matches[0].value + "\""
      else
        # 3. SIMILAR values (case-insensitive substring match; capped)
        ($entries | map(select(.value | type == "string" and (ascii_downcase | contains($input | ascii_downcase))))) as $similar_matches |
        if ($similar_matches | length) > 0 then
          "SIMILAR_MATCHES:\n" + ($similar_matches[0:20] | map("- " + .path + ": \"" + .value + "\"") | join("\n"))
        else
          "NO_MATCH"
        end
      end
    end
  '
  exit 0
fi

# Batch mode: pair each input with its normalized key (same stripping rule as
# single mode), then classify all pairs in one jq pass over $ENTRIES.
PAIRS=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  clean="${line#commons.}"
  [ -n "$MODULE" ] && clean="${clean#"$MODULE".}"
  PAIRS="${PAIRS}${line}"$'\t'"${clean}"$'\n'
done <<< "$RAW_INPUTS"

PAIRS_JSON=$(printf '%s' "$PAIRS" | jq -R -s -c '
  split("\n") | map(select(length > 0)) | map(split("\t"))
')

echo "Checking $(printf '%s' "$PAIRS_JSON" | jq 'length') i18n candidates in $SCOPE..." >&2

printf '%s' "$ENTRIES" | jq -r --argjson pairs "$PAIRS_JSON" '
  . as $entries |
  $pairs[] as $p |
  ($p[0]) as $input |
  ($p[1]) as $key |
  (
    ($entries | map(select(.key == $key or .path == $input))) as $key_matches |
    if ($key_matches | length) > 0 then
      "EXACT_KEY_MATCH: " + $key_matches[0].path + " -> \"" + $key_matches[0].value + "\""
    else
      ($entries | map(select(.value == $input))) as $exact_matches |
      if ($exact_matches | length) > 0 then
        "EXACT_VALUE_MATCH: " + $exact_matches[0].path + " -> \"" + $exact_matches[0].value + "\""
      else
        ($entries | map(select(.value | type == "string" and (ascii_downcase | contains($input | ascii_downcase))))) as $similar_matches |
        if ($similar_matches | length) > 0 then
          "SIMILAR_MATCHES:\n" + ($similar_matches[0:20] | map("- " + .path + ": \"" + .value + "\"") | join("\n"))
        else
          "NO_MATCH"
        end
      end
    end
  ) as $result |
  "### " + $input + "\n" + $result
'
