#!/bin/bash
# enhance-audio.sh
# Usage: enhance-audio.sh input.mp3 output.mp3
# Two-pass loudnorm with noise→EQ→compress→normalize chain

INPUT="$1"
OUTPUT="$2"

if [ -z "$INPUT" ] || [ -z "$OUTPUT" ]; then
  echo "Usage: $0 <input.mp3> <output.mp3>" >&2
  exit 1
fi

if [ ! -f "$INPUT" ]; then
  echo "ERROR: Input file not found: $INPUT" >&2
  exit 1
fi

echo "[1/3] Analyzing audio loudness..."

LOUDNORM_LOG=$(mktemp)
ffmpeg -i "$INPUT" -af loudnorm=I=-16:TP=-1.5:LRA=11:print_format=summary -f null - 2>&1 | tee "$LOUDNORM_LOG"

MEASURED_I=$(grep 'Input Integrated:' "$LOUDNORM_LOG" | awk '{print $3}')
MEASURED_TP=$(grep 'Input True Peak:' "$LOUDNORM_LOG" | awk '{print $4}')
MEASURED_LRA=$(grep 'Input LRA:' "$LOUDNORM_LOG" | awk '{print $3}')
MEASURED_THRESH=$(grep 'Input Threshold:' "$LOUDNORM_LOG" | awk '{print $3}')

# Validate measurements
for VAR_NAME in MEASURED_I MEASURED_TP MEASURED_LRA MEASURED_THRESH; do
  VAL=$(eval echo \$$VAR_NAME)
  if [ -z "$VAL" ]; then
    echo "ERROR: Failed to parse $VAR_NAME from loudnorm analysis" >&2
    cat "$LOUDNORM_LOG" >&2
    rm -f "$LOUDNORM_LOG"
    exit 1
  fi
done

rm -f "$LOUDNORM_LOG"

echo "[2/3] Processing: noise→EQ→compression→normalization..."

ffmpeg -y -i "$INPUT" -af "\
highpass=f=80,\
lowpass=f=15000,\
afftdn=nf=-20,\
equalizer=f=300:t=h:width=200:g=-3,\
equalizer=f=3000:t=h:width=1500:g=2,\
equalizer=f=5500:t=h:width=1000:g=-4,\
acompressor=threshold=0.089:ratio=3:attack=5:release=50:knee=6,\
loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=${MEASURED_I}:measured_TP=${MEASURED_TP}:measured_LRA=${MEASURED_LRA}:measured_thresh=${MEASURED_THRESH}:linear=true,\
aresample=48000\
" -ar 48000 -ac 2 -c:a libmp3lame -b:a 256k "$OUTPUT"

if [ $? -ne 0 ]; then
  echo "ERROR: FFmpeg enhancement failed" >&2
  exit 1
fi

echo "[3/3] Validating output..."
VALIDATION=$(ffmpeg -i "$OUTPUT" -af loudnorm=I=-16:TP=-1.5:LRA=11:print_format=summary -f null - 2>&1)
echo "$VALIDATION" | tail -8

OUTPUT_LUFS=$(echo "$VALIDATION" | grep 'Output Integrated:' | awk '{print $3}')
OUTPUT_TP=$(echo "$VALIDATION" | grep 'Output True Peak:' | awk '{print $4}')

echo ""
echo "RESULT: LUFS=${OUTPUT_LUFS} TP=${OUTPUT_TP}"

# Quality gate
LUFS_OK=$(echo "$OUTPUT_LUFS >= -18 && $OUTPUT_LUFS <= -14" | bc -l 2>/dev/null)
TP_OK=$(echo "$OUTPUT_TP <= -1.0" | bc -l 2>/dev/null)

if [ "$LUFS_OK" != "1" ] || [ "$TP_OK" != "1" ]; then
  echo "WARNING: Audio quality outside target range" >&2
  echo "  LUFS: $OUTPUT_LUFS (target: -18 to -14)" >&2
  echo "  TP: $OUTPUT_TP (target: ≤ -1.0)" >&2
fi

echo "Audio enhanced: $OUTPUT"
