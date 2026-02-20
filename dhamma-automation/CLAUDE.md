# Dhamma Video Automation — Claude Code Project

You are an automated Dhamma video production system. You scrape audio from dhammadownload.com, enhance it, generate SEO metadata, create AI video and thumbnail, assemble the final video, and upload to YouTube.

## Environment

- You are running on the same server that has FFmpeg installed
- You have bash access for all file operations, FFmpeg, curl commands
- You generate SEO and thumbnail prompts natively (no API call needed)
- OpenRouter API is used ONLY for Gemini image generation and AI video generation
- YouTube uploads use OAuth2 via curl

## Config Files

- `config/openrouter.key` — OpenRouter API key (single line, no newline)
- `config/youtube-oauth.json` — YouTube OAuth2 credentials with refresh_token, client_id, client_secret

## Execution Flow

Run the following steps in order. Stop and report errors clearly at any step.

### Step 0: Scrape & Select (Interactive)

1. Run `bash scripts/scrape-sayadaw-list.sh` to get list of Sayadaws
2. Display numbered list to user
3. User picks a Sayadaw number
4. Run `bash scripts/scrape-audio-list.sh "{sayadaw_page_url}"` to get audio list
5. Display numbered list with Disc groupings
6. User picks an audio number
7. Extract: `title`, `sayadaw_name`, `audio_url`

### Step 1: Audio Pipeline

```bash
WORK_DIR=~/dhamma-automation/workspace/$(date +%s)
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Download
curl -L -o original.mp3 "{audio_url}"

# Enhance
bash ~/dhamma-automation/scripts/enhance-audio.sh original.mp3 enhanced.mp3

# Duration
DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 enhanced.mp3)
echo "Duration: $DURATION seconds"
```

If enhance-audio.sh exits non-zero, stop and report the error.

### Step 2: SEO Generation (Native)

Read `prompts/seo-system.md` for your system instructions.

Generate SEO metadata as JSON with these exact keys:
- seotitle (under 60 chars, Myanmar primary)
- description (800-1200 words, with chapters based on $DURATION)
- tags (5-8 strings)
- shorts_moments (3-5 objects with timestamp_estimate, hook, standalone_teaching)
- thumbnail_text (2-3 Myanmar words)
- emotional_theme (one word)
- target_audience (one sentence)

Save to `$WORK_DIR/seo.json`

### Step 3: Video Prompt (Native)

Read `prompts/video-prompt-system.md` for your system instructions.

Based on `emotional_theme` from seo.json, generate a single-paragraph video generation prompt for a 5-10 second Buddhist temple/pagoda scene.

Save prompt to `$WORK_DIR/video_prompt.txt`

### Step 4: AI Video Generation

```bash
bash ~/dhamma-automation/scripts/generate-ai-video.sh "$WORK_DIR/video_prompt.txt" "$WORK_DIR/story.mp4"
```

If video generation fails, fall back to image-based Ken Burns:
```bash
bash ~/dhamma-automation/scripts/fallback-ken-burns.sh "$WORK_DIR/scene.png" "$WORK_DIR/story.mp4"
```

### Step 5: Thumbnail Prompt (Native)

Read `prompts/thumbnail-system.md` for your system instructions.

Using title, sayadaw_name, thumbnail_text, emotional_theme from seo.json, generate a Gemini-optimized image prompt. Include exact Burmese text to render.

Save prompt to `$WORK_DIR/thumbnail_prompt.txt`

### Step 6: Thumbnail Image

```bash
bash ~/dhamma-automation/scripts/generate-thumbnail.sh "$WORK_DIR/thumbnail_prompt.txt" "$WORK_DIR/thumbnail.png"
```

### Step 7: Video Assembly

```bash
bash ~/dhamma-automation/scripts/create-video.sh "$WORK_DIR/story.mp4" "$WORK_DIR/enhanced.mp3" "$WORK_DIR/final.mp4"
```

### Step 8: YouTube Upload

```bash
VIDEO_ID=$(bash ~/dhamma-automation/scripts/upload-youtube.sh "$WORK_DIR/final.mp4" "$WORK_DIR/seo.json")
echo "Uploaded: https://youtube.com/watch?v=$VIDEO_ID"
```

### Step 9: Set Thumbnail

```bash
bash ~/dhamma-automation/scripts/set-thumbnail.sh "$VIDEO_ID" "$WORK_DIR/thumbnail.png"
```

### Step 10: Cleanup

```bash
rm -rf "$WORK_DIR"
```

## Error Handling

- If any bash script exits non-zero, stop and show stderr to user
- If FFmpeg fails, show the full FFmpeg error output
- If OpenRouter returns error, show the response body
- If YouTube upload fails, check OAuth token refresh first, retry once
- Never silently continue past errors

## Quality Gates

- Audio: LUFS must be between -18 and -14, True Peak ≤ -1.0 dBTP
- Video: final.mp4 must exist and be > 1MB
- Thumbnail: thumbnail.png must exist and be < 2MB (YouTube limit)
- SEO: seotitle must be under 100 chars, description must contain chapters
