#!/bin/bash
# set-thumbnail.sh
# Usage: set-thumbnail.sh VIDEO_ID thumbnail.png

VIDEO_ID="$1"
THUMBNAIL="$2"
CONFIG_DIR="$(dirname "$0")/../config"
OAUTH_FILE="$CONFIG_DIR/youtube-oauth.json"

if [ -z "$VIDEO_ID" ] || [ -z "$THUMBNAIL" ]; then
  echo "Usage: $0 <video_id> <thumbnail.png>" >&2
  exit 1
fi

# Refresh token
CLIENT_ID=$(jq -r '.client_id' "$OAUTH_FILE")
CLIENT_SECRET=$(jq -r '.client_secret' "$OAUTH_FILE")
REFRESH_TOKEN=$(jq -r '.refresh_token' "$OAUTH_FILE")

ACCESS_TOKEN=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "refresh_token=$REFRESH_TOKEN" \
  -d "grant_type=refresh_token" | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ]; then
  echo "ERROR: Failed to refresh token" >&2
  exit 1
fi

# Upload thumbnail
RESPONSE=$(curl -s -X POST \
  "https://www.googleapis.com/upload/youtube/v3/thumbnails/set?videoId=$VIDEO_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: image/png" \
  --data-binary @"$THUMBNAIL")

SUCCESS=$(echo "$RESPONSE" | jq -r '.kind // empty')

if [ "$SUCCESS" = "youtube#thumbnailSetResponse" ]; then
  echo "Thumbnail set successfully for video: $VIDEO_ID"
else
  echo "ERROR: Failed to set thumbnail" >&2
  echo "$RESPONSE" | jq '.' >&2
  exit 1
fi
