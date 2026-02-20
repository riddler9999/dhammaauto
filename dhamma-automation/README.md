# Dhamma Automation

Automates a Dhamma video production pipeline:
- scrape audio from dhammadownload.com
- enhance audio with FFmpeg
- generate prompts/metadata
- generate AI video + thumbnail with OpenRouter
- upload final video to YouTube

## Deploy with Docker (recommended)

### 1) Prepare secrets

```bash
cp config/openrouter.key.example config/openrouter.key
cp config/youtube-oauth.example.json config/youtube-oauth.json
```

Then edit both files with real values.

### 2) Build and start container

```bash
docker compose build
docker compose run --rm dhamma-auto
```

This opens a shell in the container at `/app` with all scripts ready.

### 3) Run the pipeline

Inside container shell:

```bash
# 1) scrape Sayadaw list
bash scripts/scrape-sayadaw-list.sh

# 2) scrape selected audio list
bash scripts/scrape-audio-list.sh "<sayadaw_page_url>"

# 3) continue using steps documented in CLAUDE.md
```

## Deploy on a VPS with systemd (optional)

If you want scheduled runs, create a wrapper script and run it with a systemd timer or cron.

## Notes

- Output files are stored in `workspace/` (bind-mounted from host)
- `config/` is bind-mounted so credentials stay on the host
- Secrets are ignored via `.gitignore`
