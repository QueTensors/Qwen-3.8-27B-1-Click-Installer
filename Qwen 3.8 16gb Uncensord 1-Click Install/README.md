# Qwen 3.8 27B — 1-Click Uncensored Install for NVIDIA boxes

Turn a plain Ubuntu machine with any NVIDIA GPU (12 GB+) into a fully local, uncensored
27B assistant in one command. No cloud, no accounts, no data leaves your box.

## The one-liner
```bash
curl -fsSL https://raw.githubusercontent.com/QueTensors/one-click-installers/main/Qwen%203.8%2016gb%20Uncensord%201-Click%20Install/install.sh | bash
```

You'll be asked for exactly three things, once each:
1. your sudo password (validated on the spot)
2. **Vision mode or text-only** (Enter accepts the default for your card)
3. **Thinking level** (none / low / medium / high)

Then it installs the GPU driver, downloads the model, serves it on
`http://127.0.0.1:1234/v1` (OpenAI-compatible), installs [Hermes Agent](https://hermes-agent.nousresearch.com)
pointed at your local GPU, and verifies with a real completion — from the GPU, with
memory-residency proof in the banner. One reboot happens mid-way (the driver needs it);
the install **resumes on your screen at next login**, no typing.

## What you get, per GPU tier (measured, not speculated — see BENCHMARKS.md)
| Card | Brain | Context | Vision | Feel |
|---|---|---|---|---|
| 2×12 GB | IQ3 27B | 64K+ | ✓ | layer-split across cards |
| 16 GB | IQ3 27B | 96K vision / 128K text | ✓ | the full demo girl |
| 12 GB | IQ2_XS 27B | 64K | — | outtypes your reading speed |
| 8 GB | IQ2_XS 27B | 8K | — | works; modest |

## Files
- `install.sh` — the whole thing, idempotent: re-run any time, completed stages skip
- `virgin.sh` — resets a demo box for a clean re-run (keeps `~/models`, wipes everything else)
- `BENCHMARKS.md` — measured decode/prefill/VRAM tables per card, incl. the 23 MiB-per-1K-context KV law

## Model files (pinned by SHA256 inside the script)
- Qwen 3.8 27B IQ3_XXS Uncensored (MTP drafts) — HuggingFace: RentedNoodle
- Vision projector — ISTA-DASLab
- IQ2_XS (12/8 GB tier) — huihui-ai abliterated build

## Requirements
Ubuntu 22.04+ (x86_64 or ARM), NVIDIA GPU with ≥8 GB VRAM, ~12 GB free disk,
internet for the downloads. CPU without AVX2? The script detects it and builds
from source instead of using the prebuilt binaries.
