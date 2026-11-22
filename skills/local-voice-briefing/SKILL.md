---
name: local-voice-briefing
description: Listen and speak fully offline — run local STT/TTS, generate a spoken morning digest, and test the voice loop end to end
license: MIT
metadata:
  openjarvis:
    version: "0.1.0"
    author: jarvis
    tags: [voice, stt, tts, offline]
---

# Local voice (STT + TTS)

Goal: Jarvis listens and answers without any cloud speech service.

## Configuration

`config/config.toml` already ships a fully local `[speech]` block:

```toml
[speech]
backend = "faster-whisper"   # local STT
model = "base"               # tiny | base | small | medium | large-v3
device = "auto"              # cpu | cuda
tts_backend = "kokoro"       # local TTS
voice_id = "bm_george"       # bf_emma, bm_lewis, af_*, am_* …
```

Tune `model`/`device` to the machine: CPU-only boxes should stay at
`base`/`tiny` with `compute_type = "int8"`.

## Plug-and-play alternative: Speaches

One container, both directions (Faster-Whisper + Kokoro), on port **8001**
so it never collides with `jarvis serve` on 8000:

```bash
# CPU-only machines:
docker run -d --name speaches -p 8001:8000 ghcr.io/speaches-ai/speaches:latest-cpu
# NVIDIA GPUs: use the GPU image + NVIDIA Container Toolkit instead.
```

Point OpenJarvis's OpenAI-compatible speech endpoints at
`http://localhost:8001/v1` (env: `OPENAI_BASE_URL`) when using Speaches;
otherwise the in-process backends above need no server at all.

## Verification

```bash
# 1. STT: transcribe a short local recording
jarvis voice transcribe sample.wav          # or use the voice chat entry point

# 2. TTS: synthesize one sentence with the local voice
#    (digest generation exercises the same path)

# 3. End-to-end spoken digest
jarvis digest --fresh --text-only           # text first, then drop --text-only
```

## Rules

- Offline first: never enable cloud TTS/STT backends (`cartesia`,
  `elevenlabs`, `deepgram`, `openai_*`) unless explicitly asked.
- The morning digest inherits `tts_backend` / `voice_id` from `[digest]` —
  keep them aligned with `[speech]`.
- If audio devices are missing (headless box), generate the audio file and
  skip playback instead of failing the whole digest.
