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
2. **Two cards is a memory upgrade you get nearly free.** We measured it on the same box, same server, same settings, minutes apart: one 3060 running the big 27B model alone = 36-41 tokens/sec, but it can only carry an 8K window (the model barely fits on one 12 GB card). The same 3060 teamed with a 2060 = 35.6 t/s at chat depth and 32.7 at 16K depth - within a few percent of the lone card - while holding a **192K window**, 24x the memory. Past 8K of conversation the single card simply has no rows left to print.

   So: want a bigger brain for the same money, mix cards - the hand-off tax is about 3% and the memory is additive. Want a faster brain, buy the newest single card you can afford, and remember generations lie: on the same test the 3060 ran ~60% faster than the 2060 despite near-identical spec sheets.

   *For the nerds:* pair-vs-lone-card tests, 2026-10-25, b11829 CUDA, MTP spec-decode on, same unit flags with CUDA_VISIBLE_DEVICES isolating GPU0: single @1772-tok prompt 36.6 t/s, @3524 40.9, ctx capped at 8192 by fit; pair @2048 35.6, @8192 34.9, @16384 32.7, ctx 196608, both cards resident (8.3+11.5 GB). The per-card generational gap is Ampere cache/kernel scheduling, not bandwidth (7% on paper, ~60% measured).
3. **One-card head-to-head, same box, same model, same 64K window, measured 2026-10-25** (IQ2_XS, MTP on, card alone with 100% of itself):

| depth | RTX 3060 | RTX 2060 | 3060 faster by |
|---|---|---|---|
| 2K (chat) | ~40 t/s | ~23 t/s | +78% |
| 8K | 21.7 | 12.9 | +68% |
| 32K | 18.1 | 11.5 | +57% |
| 64K | 15.1 | 10.2 | +48% |

   Newer generation = up to nearly 2x the writing speed at chat depth, narrowing toward equal at long depth (both cards pay the same attention bill eventually). Plain advice: **old cards to grow memory, new cards to gain speed.** First-request times after a restart include reading the model off disk (we saw 0.3 t/s on a cold first touch) - that is storage, not silicon, and it never repeats. Prefill rates for these runs are pending: measured externally by the latency monitor, since the server does not report them in-stream.

4. **A 27B dense model at IQ2 fits a 12 GB card with a real 64K agent window** — the entry point for fully-local assistants (uncensored or censored, your pick) is a ~$150 used GPU. Vision needs the 16 GB tier.
5. MoE (35B-A3B class): runs on 2 GB VRAM but CPU-expert prefill (~23 t/s, DDR3 rig) makes agent-sized prompts impractical below large-RAM systems. Measure your prefill before trusting the VRAM number alone.
