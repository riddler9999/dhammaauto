#!/bin/bash
# scrape-sayadaw-list.sh
# Fetches the main Audio in Myanmar page and extracts Sayadaw names + page URLs

curl -s "https://www.dhammadownload.com/AudioInMyanmar.htm" \
  | grep -oP 'href="([^"]+\.htm)"[^>]*>\s*([^<]+)' \
  | grep -v 'images/' \
  | grep -v 'index.htm' \
  | grep -v 'Abhidhamma' \
  | grep -v 'Audio\(In\|in\)' \
  | grep -v 'Video' \
  | grep -v 'eBook' \
  | grep -v 'news' \
  | grep -v 'Contribute' \
  | grep -v 'Suggestion' \
  | grep -v 'contact' \
  | grep -v 'usefullinks' \
  | grep -v 'live.htm' \
  | grep -v 'facebook' \
  | grep -v 'Side-button' \
  | sed 's/href="//;s/"[^>]*>/|/' \
  | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
  | grep -v '^$' \
  | sort -u
