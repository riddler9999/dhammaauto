#!/bin/bash
# create-video.sh
# Usage: create-video.sh story.mp4 enhanced.mp3 final.mp4
# Loops story video with 1s crossfade to match audio duration

STORY="$1"
AUDIO="$2"
OUTPUT="$3"
FADE=1

if [ -z "$STORY" ] || [ -z "$AUDIO" ] || [ -z "$OUTPUT" ]; then
  echo "Usage: $0 <story.mp4> <audio.mp3> <output.mp4>" >&2
  exit 1
fi

# Get durations
AUDIO_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$AUDIO")
VID_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$STORY")

AUDIO_DUR_INT=${AUDIO_DUR%.*}
VID_DUR_INT=${VID_DUR%.*}

echo "Audio duration: ${AUDIO_DUR}s"
echo "Video clip duration: ${VID_DUR}s"

# Calculate loops needed
LOOPS=$(echo "scale=0; ($AUDIO_DUR_INT / ($VID_DUR_INT - $FADE)) + 2" | bc)
[ "$LOOPS" -gt 50 ] && LOOPS=50
[ "$LOOPS" -lt 2 ] && LOOPS=2

echo "Loops needed: $LOOPS"

# If only 1-2 loops, simple stream_loop is fine (no crossfade needed for single loop)
if [ "$LOOPS" -le 2 ]; then
  echo "Simple loop (no crossfade needed)..."
  ffmpeg -y \
    -stream_loop -1 -i "$STORY" \
    -i "$AUDIO" \
    -map 0:v -map 1:a \
    -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,format=yuv420p" \
    -c:v libx264 -preset medium -crf 20 -profile:v high -level 4.1 \
    -c:a aac -b:a 192k -ar 48000 \
    -shortest -t "$AUDIO_DUR" \
    -movflags +faststart \
    -threads 0 \
    "$OUTPUT"
  exit $?
fi

# Build xfade filter chain
echo "Building crossfade filter chain..."

INPUTS=""
for i in $(seq 1 $LOOPS); do
  INPUTS="$INPUTS -i $STORY"
done

FC=""
for i in $(seq 1 $((LOOPS - 1))); do
  OFFSET=$(echo "scale=2; $i * ($VID_DUR - $FADE)" | bc)
  if [ "$i" -eq 1 ]; then
    FC="[0:v][1:v]xfade=transition=fade:duration=${FADE}:offset=${OFFSET}[xf1]"
  else
    FC="${FC};[xf$((i-1))][${i}:v]xfade=transition=fade:duration=${FADE}:offset=${OFFSET}[xf${i}]"
  fi
done

LAST_XF="xf$((LOOPS-1))"

echo "Encoding final video with crossfade..."

ffmpeg -y \
  $INPUTS \
  -i "$AUDIO" \
  -filter_complex "${FC};[${LAST_XF}]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,format=yuv420p[vout]" \
  -map "[vout]" -map ${LOOPS}:a \
  -c:v libx264 -preset medium -crf 20 -profile:v high -level 4.1 \
  -c:a aac -b:a 192k -ar 48000 \
  -t ${AUDIO_DUR} \
  -movflags +faststart \
  -threads 0 \
  "$OUTPUT"

if [ $? -ne 0 ]; then
  echo "ERROR: xfade encoding failed. Falling back to simple loop..." >&2
  ffmpeg -y \
    -stream_loop -1 -i "$STORY" \
    -i "$AUDIO" \
    -map 0:v -map 1:a \
    -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,format=yuv420p" \
    -c:v libx264 -preset medium -crf 20 -profile:v high -level 4.1 \
    -c:a aac -b:a 192k -ar 48000 \
    -shortest -t "$AUDIO_DUR" \
    -movflags +faststart \
    -threads 0 \
    "$OUTPUT"
  exit $?
fi

echo "Video assembled: $OUTPUT"
