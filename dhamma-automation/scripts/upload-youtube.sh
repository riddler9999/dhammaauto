#!/bin/bash
# upload-youtube.sh
# Usage: upload-youtube.sh final.mp4 seo.json
# Outputs: video_id on stdout

VIDEO="$1"
SEO_JSON="$2"
CONFIG_DIR="$(dirname "$0")/../config"
OAUTH_FILE="$CONFIG_DIR/youtube-oauth.json"

if [ -z "$VIDEO" ] || [ -z "$SEO_JSON" ]; then
  echo "Usage: $0 <video.mp4> <seo.json>" >&2
  exit 1
fi

if [ ! -f "$OAUTH_FILE" ]; then
  echo "ERROR: YouTube OAuth config not found: $OAUTH_FILE" >&2
  exit 1
fi

# Read OAuth credentials
CLIENT_ID=$(jq -r '.client_id' "$OAUTH_FILE")
CLIENT_SECRET=$(jq -r '.client_secret' "$OAUTH_FILE")
REFRESH_TOKEN=$(jq -r '.refresh_token' "$OAUTH_FILE")

# Step 1: Refresh access token
echo "Refreshing OAuth2 token..." >&2
TOKEN_RESPONSE=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "refresh_token=$REFRESH_TOKEN" \
  -d "grant_type=refresh_token")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')

if [ -z "$ACCESS_TOKEN" ]; then
  echo "ERROR: Failed to refresh token" >&2
  echo "$TOKEN_RESPONSE" >&2
  exit 1
fi

# Step 2: Read SEO metadata
TITLE=$(jq -r '.seotitle' "$SEO_JSON")
DESCRIPTION=$(jq -r '.description' "$SEO_JSON")
TAGS=$(jq -r '.tags | join(",")' "$SEO_JSON")
CATEGORY_ID="22"  # People & Blogs

# Step 3: Create metadata JSON
METADATA=$(jq -n \
  --arg title "$TITLE" \
  --arg desc "$DESCRIPTION" \
  --arg tags "$TAGS" \
  --arg cat "$CATEGORY_ID" \
  '{
    snippet: {
      title: $title,
      description: $desc,
      tags: ($tags | split(",")),
      categoryId: $cat
    },
    status: {
      privacyStatus: "unlisted",
      selfDeclaredMadeForKids: false
    }
  }')

# Step 4: Upload via resumable upload
echo "Initiating upload..." >&2
UPLOAD_URL=$(curl -s -X POST \
  "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -H "X-Upload-Content-Type: video/mp4" \
  -H "X-Upload-Content-Length: $(stat -f%z "$VIDEO" 2>/dev/null || stat -c%s "$VIDEO" 2>/dev/null)" \
  -d "$METADATA" \
  -D - | grep -i 'location:' | sed 's/location: //i' | tr -d '\r')

if [ -z "$UPLOAD_URL" ]; then
  echo "ERROR: Failed to initiate resumable upload" >&2
  exit 1
fi

echo "Uploading video..." >&2
UPLOAD_RESPONSE=$(curl -s -X PUT "$UPLOAD_URL" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: video/mp4" \
  --data-binary @"$VIDEO")

VIDEO_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.id // empty')

if [ -z "$VIDEO_ID" ]; then
  echo "ERROR: Upload failed" >&2
  echo "$UPLOAD_RESPONSE" | jq '.' >&2
  exit 1
fi

echo "Upload complete: https://youtube.com/watch?v=$VIDEO_ID" >&2

# Output video ID for use by next script
echo "$VIDEO_ID"
