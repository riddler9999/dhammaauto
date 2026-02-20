#!/bin/bash
# generate-ai-video.sh
# Usage: generate-ai-video.sh prompt.txt output.mp4
# Generates 5-10s video clip via OpenRouter, falls back to Ken Burns

PROMPT_FILE="$1"
OUTPUT="$2"
CONFIG_DIR="$(dirname "$0")/../config"
API_KEY=$(cat "$CONFIG_DIR/openrouter.key" 2>/dev/null)

if [ -z "$API_KEY" ]; then
  echo "ERROR: OpenRouter API key not found at $CONFIG_DIR/openrouter.key" >&2
  exit 1
fi

PROMPT=$(cat "$PROMPT_FILE")

# Step 1: Check available video models
echo "Checking available video models on OpenRouter..."
MODELS=$(curl -s "https://openrouter.ai/api/v1/models" \
  -H "Authorization: Bearer $API_KEY")

# Look for video-capable models (Veo, Kling, Luma, Runway)
VIDEO_MODEL=$(echo "$MODELS" | jq -r '[.data[] | select(.id | test("veo|kling|luma|runway|video"; "i")) | .id] | first // empty')

if [ -z "$VIDEO_MODEL" ]; then
  echo "No video model available on OpenRouter. Using image + Ken Burns fallback."
  FALLBACK=1
else
  echo "Using video model: $VIDEO_MODEL"
  FALLBACK=0
fi

if [ "$FALLBACK" -eq 0 ]; then
  # Step 2: Generate video
  echo "Generating video..."
  RESPONSE=$(curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg model "$VIDEO_MODEL" \
      --arg prompt "$PROMPT" \
      '{
        model: $model,
        messages: [{role: "user", content: ("Generate a 5-10 second video: " + $prompt)}],
        modalities: ["video"]
      }')")

  # Extract video URL from response
  VIDEO_URL=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty' | grep -oP 'https://[^\s"]+\.(mp4|webm)')

  if [ -n "$VIDEO_URL" ]; then
    echo "Downloading generated video..."
    curl -s -L -o "$OUTPUT" "$VIDEO_URL"
    if [ -f "$OUTPUT" ] && [ $(stat -f%z "$OUTPUT" 2>/dev/null || stat -c%s "$OUTPUT" 2>/dev/null) -gt 1000 ]; then
      echo "Video generated: $OUTPUT"
      exit 0
    fi
  fi

  # Check for base64 video
  B64_VIDEO=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty' | grep -oP 'data:video/[^;]+;base64,[A-Za-z0-9+/=]+')
  if [ -n "$B64_VIDEO" ]; then
    echo "$B64_VIDEO" | sed 's/data:video\/[^;]*;base64,//' | base64 -d > "$OUTPUT"
    if [ -f "$OUTPUT" ] && [ $(stat -f%z "$OUTPUT" 2>/dev/null || stat -c%s "$OUTPUT" 2>/dev/null) -gt 1000 ]; then
      echo "Video generated from base64: $OUTPUT"
      exit 0
    fi
  fi

  echo "Video generation failed. Response:"
  echo "$RESPONSE" | jq '.error // .choices[0].message.content // .' | head -20
  echo "Falling back to Ken Burns..."
fi

# Fallback: Generate image + Ken Burns effect
WORK_DIR=$(dirname "$OUTPUT")
SCENE_IMG="$WORK_DIR/scene.png"

echo "Generating still image via Gemini..."
IMG_RESPONSE=$(curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --arg prompt "$PROMPT" \
    '{
      model: "google/gemini-3-pro-image-preview",
      messages: [{role: "user", content: ("Generate a wide cinematic landscape image: " + $prompt)}],
      modalities: ["image", "text"]
    }')")

# Extract base64 image
IMG_B64=$(echo "$IMG_RESPONSE" | jq -r '.choices[0].message.images[0].image_url.url // empty')
if [ -z "$IMG_B64" ]; then
  IMG_B64=$(echo "$IMG_RESPONSE" | jq -r '.choices[0].message.content // empty' | grep -oP 'data:image/[^;]+;base64,[A-Za-z0-9+/=]+')
fi

if [ -z "$IMG_B64" ]; then
  echo "ERROR: Image generation also failed" >&2
  echo "$IMG_RESPONSE" | jq '.error // .' >&2
  exit 1
fi

echo "$IMG_B64" | sed 's/data:image\/[^;]*;base64,//' | base64 -d > "$SCENE_IMG"

echo "Applying Ken Burns effect..."
bash "$(dirname "$0")/fallback-ken-burns.sh" "$SCENE_IMG" "$OUTPUT"
exit $?
