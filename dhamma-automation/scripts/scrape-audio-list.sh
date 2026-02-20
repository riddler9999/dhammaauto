#!/bin/bash
# scrape-audio-list.sh
# Usage: scrape-audio-list.sh "Ashin-Sandadika-mp3.htm"
# Output: mp3_url|title (one per line)

SAYADAW_PAGE="$1"
if [ -z "$SAYADAW_PAGE" ]; then
  echo "Usage: $0 <sayadaw-page.htm>" >&2
  exit 1
fi

# Handle both relative and absolute URLs
if [[ "$SAYADAW_PAGE" != http* ]]; then
  URL="https://www.dhammadownload.com/${SAYADAW_PAGE}"
else
  URL="$SAYADAW_PAGE"
fi

curl -s "$URL" \
  | grep -oP 'href="(https?://[^"]+\.mp3)"[^>]*title="[^"]*">\s*([^<]+)' \
  | sed 's/href="//;s/"[^>]*title="[^"]*">/|/' \
  | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
  | grep -v '^$'

# Fallback: some pages don't have title attr
if [ $? -ne 0 ] || [ -z "$(curl -s "$URL" | grep -oP 'href="(https?://[^"]+\.mp3)"')" ]; then
  curl -s "$URL" \
    | grep -oP '<a[^>]+href="(https?://[^"]+\.mp3)"[^>]*>[^<]+</a>' \
    | sed 's/<a[^>]*href="//;s/"[^>]*>/|/;s/<\/a>//' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | grep -v '^$'
fi
