#!/bin/bash

# Utility to check if an i18n key or value exists in commons.json

INPUT="$1"
URL="https://one-static.morrison.express/i18n/prod/commons.json"

if [ -z "$INPUT" ]; then
  echo "Usage: $0 <key_or_value>"
  exit 1
fi

# Normalize input key (strip 'commons.' prefix if present)
CLEAN_KEY="${INPUT#commons.}"

echo "Checking i18n key/value: '$INPUT' (Key check: '$CLEAN_KEY') in commons.json..."

# Fetch and check
# We use a single jq script to check both key and value
curl -s "$URL" | jq -r --arg input "$INPUT" --arg key "$CLEAN_KEY" '
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
'
