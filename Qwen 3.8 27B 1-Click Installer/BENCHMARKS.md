# Measured benchmarks — 12 GB tier (two cards)
Rigs: same machine, same OS, same source-built llama.cpp b11829 (CUDA 12.4), q4_0 KV cache, swapping only the GPU. Model A = Qwen 3.8 27B IQ3_XXS (10.4 GB file). Model B = Qwen 3.8 27B IQ2_XS (8.4 GB file). decode = output tokens/sec once answering; TTFT = time to first token; prefill = prompt-processing speed. Dates: 2026-10-23.

## Card 1: RTX 3060 12 GB
| load | VRAM used | decode by context depth (2K/8K/16K/32K/64K/90K tokens) | prefill |
|---|---|---|---|
| IQ3 @ 32K | 10,367 MB | 20.5 / 19.6 / 18.6 / 17.0 | 370-934 t/s |
| IQ3 @ 48K | 10,735 MB | fits (ladder not re-run) | - |
| IQ2 @ 64K | 9,633 MB | 22.6 / 20.4 / 18.5 / 15.7 / 15.6 | 485-898 t/s |
| IQ2 @ 96K | 10,369 MB | 22.3 / 21.2 / 20.0 / 18.3 / 15.6 / 14.1 | up to 1,220 t/s |
| IQ2 @ 112K | 10,737 MB | fits, context fully granted (verified via /props) | - |
Agent layer (Hermes): cold first reply 45-92 s (its ~30K-token start-up prompt), warm turns sub-second; endpoint cache proof 10.3 s -> 0.72 s.

## Card 2: RTX 2060 12 GB (Turing)
| load | VRAM used | decode by depth | prefill |
|---|---|---|---|
| IQ3 @ 32K | 10,346 MB | 12.8 / 12.4 / 12.0 / 11.3 | 306-615 t/s |
| IQ3 @ 48K | 10,714 MB | fits | - |
| IQ2 @ 96K | 10,348 MB | 13.2 / 12.9 / 12.4 / 11.7 / 10.4 / 9.7 | 241-755 t/s |
| IQ2 @ 112K | 10,716 MB | fits | - |
Agent layer: cold 63 s / warm 26 s; cache proof 11.9 s -> 0.59 s.

## The laws that generalize (any card, any model size)
1. **KV cost = ~23 MB per 1,000 context tokens** (q4_0 cache, measured linear to the MiB across both cards and four window sizes). Weights + KV + ~1.2 GB overhead = what you need. Plug in your card's VRAM and solve.
2. **Two cards is first and foremost about MEMORY.** Splitting the model across a pair doubles the room you can grow into — our 2060+3060 box holds a 192K window no single card here could. What it does for speed is real but harder to pin down: with both cards reading from their own memory at once, the pair answered at 30-34 tokens/sec in our runs, faster than either card managed alone on an older test setup (different settings, so we're re-running that comparison apples-to-apples now — the honest number will land here). What the tables above DO prove cleanly: on this same workload a 3060 alone is about 60% faster than a 2060 alone, despite near-identical spec sheets. Newer generations quietly beat their paper numbers. If speed is the goal, buy one newer card; if a bigger brain is the goal, buy two whatever-cards.

   *For the nerds:* the per-card gap is Ampere's cache and kernel scheduling, not bandwidth (7% on paper, ~60% measured). Pair speed is bounded by pipeline hand-off, per-card slice size, and speculative-decode acceptance, which is why "runs at the slower card's pace" is a rough rule, not a law — verification run pending.
3. **A 27B dense model at IQ2 fits a 12 GB card with a real 64K agent window** — the entry point for fully-local uncensored assistants is a ~$150 used GPU. Vision needs the 16 GB tier.
4. MoE (35B-A3B class): runs on 2 GB VRAM but CPU-expert prefill (~23 t/s, DDR3 rig) makes agent-sized prompts impractical below large-RAM systems. Measure your prefill before trusting the VRAM number alone.
