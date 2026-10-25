# Qwen 3.8 27B — 1-Click Uncensored Local AI for NVIDIA PCs

**TL;DR — who this is for:** anyone with an Ubuntu machine and an NVIDIA GPU with **12 GB or more of VRAM**. One command installs the driver, a fully local uncensored 27B language model, and (optionally) the Hermes agent on top. No cloud, no accounts, nothing phones home. Your card size decides exactly what you get — see the tables.

## What YOU get, by graphics card

### 16 GB cards (e.g. RTX 4060 Ti 16G, 3080-class, 16G laptop GPUs)
| with the agent (recommended) | raw endpoint (skip the agent) |
|---|---|
| Qwen 3.8 27B IQ3_XXS uncensored + MTP drafts, 96K context WITH vision or 128K text-only, ~16-22 t/s steady (bursts 40-70 on code), chat terminal + OpenAI-compatible API at `http://YOUR-IP:1234/v1` | same model/server, API only — the agent row's numbers apply to the engine itself |

### 12 GB cards (e.g. RTX 3060 12G, RTX 2060 12G)
| with the agent | raw endpoint |
|---|---|
| Qwen 3.8 27B IQ2_XS uncensored (same brain, denser compression), **64K context** (the agent's own start-up prompt uses ~30K of it), 11-22 t/s measured depending on card generation — faster than reading speed, no vision | same, and you can dial context up to **96K-112K** (verified) since the agent prompt isn't competing for it; no vision |

### 8 GB cards
IQ2_XS at 8K — supported, honest but modest; the agent's prompt barely fits. Not the showcase.

## What the install asks you (complete list)
1. sudo password — validated as you type, stored locally, never leaves the machine
2. vision or text-only (16 GB cards; Enter takes the default)
3. agent layer: Hermes or raw endpoint (Enter takes Hermes)
4. thinking level off/low/medium/high (Enter takes medium)
One reboot mid-way (driver); the installer resumes on your screen when you log back in.

## The one command
```bash
curl -fsSL "https://raw.githubusercontent.com/QueTensors/one-click-installers/main/Qwen%203.8%2016gb%20Uncensord%201-Click%20Install/install.sh" | bash
```

## After install
- `endpoint` — prints your URL, model name, and a ready-to-paste test command, any time
- `llama-mode vision|plain` — switch later (16 GB cards) · `install-status` — stage check
- The server binds **0.0.0.0:1234** (whole LAN can reach it), no API key by default — perfect for a home network, think twice on shared/campus LANs.

## Benchmarks
BENCHMARKS.md carries the measured tables behind every claim above (RTX 3060 12G + RTX 2060 12G, full ladders, the 23 MiB-per-1K-context memory formula so you can predict your own card).

## Files
install.sh (idempotent — re-run anytime, completed stages skip) · virgin.sh (reset a demo box, keeps downloads) · BENCHMARKS.md
