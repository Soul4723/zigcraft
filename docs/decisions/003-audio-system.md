# Decision 003: Procedural Audio Synthesis via ALSA Backend

## Status
Accepted (2026-10-02, Session 020)

## Context
Milestone 28 requires sound and audio effects for player footsteps, block breaking, and block placement. We need an audio solution that integrates cleanly with Zig 0.16.0 without introducing massive binary dependencies or fragile asset loading paths.

## Options Considered

1. **External Audio Assets (WAV/OGG) + Miniaudio/OpenAL**
   - Requires external audio asset files and loaders.
   - External asset paths add runtime file-lookup failure modes.

2. **Procedural Audio Synthesizer + ALSA PCM Backend**
   - Directly generate sound effects via software DSP oscillators, noise generators, and exponential decay envelopes.
   - Non-blocking ALSA PCM playback (`asound` system library standard on Linux).
   - Zero asset files needed: 100% self-contained code.
   - Multi-voice channel mixer for concurrent sound playback.

## Decision
Adopt procedural audio synthesis with an ALSA backend:
- `src/audio/synth.zig`: Multi-voice mixer supporting footsteps (grass, stone, wood, dirt), block destruction crunch, and block placement snap.
- `src/audio/audio.zig`: ALSA PCM non-blocking playback interface. Gracefully falls back to muted operation if no sound card is available.
