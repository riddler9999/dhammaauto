#!/bin/bash
# fallback-ken-burns.sh
# Usage: fallback-ken-burns.sh scene.png output.mp4
# Creates 10s video with slow zoom/pan effect from still image

INPUT="$1"
OUTPUT="$2"

if [ -z "$INPUT" ] || [ -z "$OUTPUT" ]; then
  echo "Usage: $0 <image.png> <output.mp4>" >&2
  exit 1
fi

ffmpeg -y -loop 1 -i "$INPUT" \
  -vf "scale=8000:-1,zoompan=z='min(zoom+0.0005,1.5)':d=250:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1920x1080:fps=30" \
  -c:v libx264 -preset medium -crf 20 \
  -t 10 -pix_fmt yuv420p \
  "$OUTPUT"

if [ $? -ne 0 ]; then
  echo "ERROR: Ken Burns effect failed" >&2
  exit 1
fi

echo "Ken Burns video created: $OUTPUT"
