#!/bin/bash
# generate-thumbnail.sh
# Usage: generate-thumbnail.sh prompt.txt output.png

PROMPT_FILE="$1"
OUTPUT="$2"
CONFIG_DIR="$(dirname "$0")/../config"
API_KEY=$(cat "$CONFIG_DIR/openrouter.key" 2>/dev/null)

if [ -z "$API_KEY" ]; then
  echo "ERROR: OpenRouter API key not found" >&2
  exit 1
fi

PROMPT=$(cat "$PROMPT_FILE")

echo "Generating thumbnail via Gemini..."

RESPONSE=$(curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg prompt "$PROMPT" \
    '{
      model: "google/gemini-3-pro-image-preview",
      messages: [{role: "user", content: ("Generate this YouTube thumbnail image: " + $prompt)}],
      modalities: ["image", "text"],
      image_config: {
        aspect_ratio: "16:9"
      }
    }')")

# Try images array first
IMG_URL=$(echo "$RESPONSE" | jq -r '.choices[0].message.images[0].image_url.url // empty')

# Try base64 in content
if [ -z "$IMG_URL" ]; then
  IMG_URL=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty' | grep -oP 'data:image/[^;]+;base64,[A-Za-z0-9+/=]+')
fi

if [ -z "$IMG_URL" ]; then
  echo "ERROR: No image in Gemini response" >&2
  echo "$RESPONSE" | jq '.error // .choices[0] // .' >&2
  exit 1
fi

# Decode
if [[ "$IMG_URL" == data:image/* ]]; then
  echo "$IMG_URL" | sed 's/data:image\/[^;]*;base64,//' | base64 -d > "$OUTPUT"
elif [[ "$IMG_URL" == http* ]]; then
  curl -s -L -o "$OUTPUT" "$IMG_URL"
else
  echo "$IMG_URL" | base64 -d > "$OUTPUT"
fi

# Validate
if [ ! -f "$OUTPUT" ] || [ $(stat -f%z "$OUTPUT" 2>/dev/null || stat -c%s "$OUTPUT" 2>/dev/null) -lt 1000 ]; then
  echo "ERROR: Thumbnail file invalid or too small" >&2
  exit 1
fi

# Check file size < 2MB (YouTube limit)
FILE_SIZE=$(stat -f%z "$OUTPUT" 2>/dev/null || stat -c%s "$OUTPUT" 2>/dev/null)
if [ "$FILE_SIZE" -gt 2097152 ]; then
  echo "Thumbnail > 2MB, compressing..."
  ffmpeg -y -i "$OUTPUT" -vf "scale=1280:720" -q:v 85 "${OUTPUT}.tmp.png"
  mv "${OUTPUT}.tmp.png" "$OUTPUT"
fi

echo "Thumbnail generated: $OUTPUT"
