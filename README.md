# Qwen 3.8 27B — 1-Click Installer

Your own AI brain — uncensored or censored, your pick at install — running locally on your Linux box. No cloud, no account, no subscription. One copy-paste and it installs everything: GPU driver, model, chat agent.

**Built by Blackwell Bytes.**

---

## What you need

- A computer running **Ubuntu 22.04 or newer** (any flavor, desktop or headless)
- An **NVIDIA graphics card with at least 8 GB** of VRAM — older GTX cards work too (see the table below)
- About **30 GB of free disk space**
- 15 minutes and your password (the one you'd type for `sudo`)

Don't know your card? Open a terminal and type `nvidia-smi`. It'll print it. No output? The installer will detect your GPU and offer to install the driver — that's normal and included.

## Where the model comes from (sources & credit)

We don't train models — we fetch them from the people who did the work and run them on your GPU. Every file the installer downloads, from these exact pages, no middleman:

| What it is | Source | Exact file downloaded |
|---|---|---|
| **Big brain** (16 GB+ cards) — uncensored | [RentedNoodle — Qwen3.8-27B-GSQ-RCO-IQ3_XXS-Uncensored](https://huggingface.co/RentedNoodle/Qwen3.8-27B-GSQ-RCO-IQ3_XXS-Uncensored) | `Qwen3.8-27B-GSQ-RCO-IQ3_XXS-Uncensored-MTP.gguf` (10.4 GB, IQ3_XXS + MTP drafter) |
| **Vision projector** (16 GB cards, optional) | [ISTA-DASLab — Qwen3.8-27B-GSQ-RCO-GGUF](https://huggingface.co/ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF) | `mmproj-Qwen3.8-27B-BF16.gguf` |
| **Compact brain** (12 GB and under) | [huihui-ai — Huihui-Qwen3.8-27B-abliterated-GGUF](https://huggingface.co/huihui-ai/Huihui-Qwen3.8-27B-abliterated-GGUF) | `Huihui-Qwen3.8-27B-abliterated-Swift-1.5-GSQ-RCO-IQ2_XS.gguf` |

All three sit on top of the base **Qwen 3.8 27B** open-weights model from the [Qwen team at Alibaba](https://huggingface.co/Qwen) (Apache 2.0). The "uncensored" builds are community ablation work — the refusal behavior is surgically removed, the knowledge is untouched; the huihui-ai build doubles as the censored-style alternative lineage. The engine underneath is [llama.cpp](https://github.com/ggml-org/llama.cpp) (ggml-org), with prebuilt CUDA binaries pinned per release, plus NVIDIA's official cuBLAS/CUDA-runtime wheels from PyPI and the GPU driver from your distro's package.

Weight licenses belong to their authors — check each page above (all MIT/Apache-family here); our installer script is MIT. Everything on your machine after install stays on your machine: we download from Hugging Face and PyPI once, then nothing phones home.

## Install

Open a terminal and paste this ONE line, then press Enter:

```
curl -fsSL "https://raw.githubusercontent.com/QueTensors/Qwen-3.8-27B-1-Click-Installer/main/Qwen%203.8%2027B%201-Click%20Installer/install.sh" | bash
```

It will ask you a few simple questions — every one has a safe default, so **you can press Enter through all of them** and get a great setup. On a fresh machine, the screen will say "REBOOTING NOW" and your terminal disconnects. That's normal! Just log back in within a couple of minutes and the install continues on-screen by itself.

### What it figures out on its own

The installer counts your graphics cards (even several **mixed** cards together), adds up their memory, and picks the best brain + longest memory your machine can genuinely run — then **shows you its work on screen** before asking you to choose. No guessing, no config files.

| Your cards | What you get |
|---|---|
| 1x 16 GB (typical gaming laptop) | The big model, 96K context (about a whole novel), or 128K text-only |
| 2x 12 GB used cards (any mix) | The big model with **192K context** — the full memory window |
| 3-4 cards, 26 GB+ combined | Everything above **plus** hi-fi conversation memory (q8) |
| 2x 8 GB | The big model, 32K context — the cheapest way in |
| 1x 12 GB | The compact model, 64K context, text-only |
| 1x 8 GB | The compact model — works, but slow (add one more card!) |

More cards = a bigger brain, not a faster one. Any single 16 GB card beats the same total split across smaller ones.

## When it's done

You'll see a green box with your address, something like `http://192.168.x.x:1234/v1`. That's it — your personal AI endpoint. On that machine you can now type:

| Command | What it does |
|---|---|
| `hermes` | Start chatting with your AI (if you installed the agent) |
| `endpoint` | Re-print your connection info anytime |
| `llama-mode vision` / `llama-mode plain` | Switch between image-capable and deep-text modes |
| `llama-style censored` / `llama-style uncensored` | Workplace-appropriate answers, or nothing-held-back |
| `install-status` | Show what's installed and whether the server is answering |

Anything that speaks the OpenAI format (apps, scripts, other agents) can connect to that address from anywhere on your home network — no password needed.

## Common questions

**Do I need the internet after installing?** No. The model lives on your disk and runs on your GPU. The internet is only used once, to download them.

**Can I re-run the command?** Yes, anytime. It picks up exactly where it left off — a broken download resumes, and a new installer version re-runs cleanly. It never deletes your models.

**Will it phone home?** It doesn't phone at all. After install, nothing you type ever leaves your machine.

**Is it really uncensored?** The model weights themselves are a pre-ablated build by their authors (linked under "Where the brain comes from" in the shelf README) — the refusal filter is already gone. Prefer polite? One command: `llama-style censored`.

**Multiple GPUs?** Fully automatic: 1-4 cards in any mix of sizes, weights sharded across all of them at load, smaller junk cards (like an old display card) detected, named, and left to drive your monitor in peace.

**Will bolting on more cards make it faster?** No — more cards = a bigger brain, not a quicker one. Layer-sharding means every card computes its slice one after another on every single token, so four old cards still can't out-run one new one (we measured a matched card-vs-card duel: same model, same flags, newer card won by 48-78%). What extra VRAM genuinely buys you: longer context, higher-fidelity quants of the model (smarter answers, never faster ones), and room to run vision plus hi-fi conversation memory at the same time. Want more tokens per second? That's a newer-card purchase, not an extra-card one.

**Uninstall?** `systemctl --user disable --now 'llama-*'` and delete `~/models` plus `~/.turnkey-llm*` — it's all just files.

---

*The model files belong to their authors and this script is MIT-licensed. No affiliation with Nous Research or the Qwen team - just a garage-tested installer: every number in these docs came off real machines in this house, including one very strange box with two mismatched GPUs.*
