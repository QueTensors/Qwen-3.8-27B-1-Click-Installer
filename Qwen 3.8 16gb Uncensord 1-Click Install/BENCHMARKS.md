1|# 12 GB Card Tier Report — Qwen 3.8 Girls on RTX 3060 12G
2|*Ran 2026-10-23 on testbench (i5-2500, 15 GB DDR3, RTX 3060 12 GB, driver 595.99.02). Suite: run4 matrix + hermes live tests. Card under test #2 (RTX 2060 12 GB): pending swap; same script, same two SHA-pinned GGUFs, same ladders — sections marked PENDING fill in next.*
3|
4|## The girls (identical files on both cards)
5|| File | Model | Size | SHA256 (full) |
6||---|---|---|---|
7|| qwen38-27b-iq3-unc-mtp.gguf | Qwen 3.8-27B dense, IQ3_XXS, MTP drafts | 9.72 GiB | 7422389f5e353ef5cd541871736823f58d029259a2f2362ef5a222ba0607c8a9 |
8|| qwen38-27b-iq2xs-unc.gguf | Qwen 3.8-27B dense, IQ2_XS (huihui abliterated) | 7.84 GiB | 1401ac507622a2b685efcbb0e44a44cb725dee326094df805b0b2de00cceeb14 |
9|| qwen36-35b-a3b-abl-q2k.gguf | Qwen 3.6-35B-A3B MoE (eliminated from this tier — see verdict) | 12.3 GiB | 85f446fff19406aa81bd8333433fa11921038ba1b80523c2432d82623b73fb73 |
10|
11|Serving build: llama.cpp b11829 built **from source on the bench** (CPU lacks AVX2 → GitHub prebuilts SIGILL), CUDA 12.4, `-ngl 99 -np 1 --cache-type-k q4_0 --cache-type-v q4_0 --jinja -fa on`.
12|Measured KV cost: **23 MiB per 1K context tokens** (q4_0 KV, verified linear across 32K→48K and 96K→112K probes; VRAM deltas matched to the MiB).
13|
14|## WITH HERMES (the agent stack; its boot prompt measured ~30K tokens = 46% of a 64K window)
15|| Metric | 3060 12G | 2060 12G |
16||---|---|---|
17|| Profile chosen by installer | 12g: IQ2_XS text-only, 64K | same (sm_75 kernel rebuild was the only extra step) |
18|| VRAM resident | 9,633 MiB (measured) | 9,6xx MiB (112K server, ~10.3 GB granted) |
19|| hermes cold one-shot | 45–92 s | 63.5 s cold / 25.9 s warm |
20|| Server cache proof (same payload ×2) | 10.3 s → 0.72 s (14×) | 11.9 s → 0.59 s (20×) |
21|| Verdict | works; boot cost is the tax | works identically; boots ~same, chats ~35% slower |
22|
23|## BAREBACK (raw API, no agent prompt)
24|### IQ3_XXS 27B
25|| ctx | VRAM | decode t/s @ 2K / 8K / 16K / 32K depth | 2060 VRAM | 2060 t/s |
26||---|---|---|---|---|
27|| 32,768 | 10,367 MiB | 20.5 / 19.6 / 18.6 / 17.0 | 10,346 MiB | 12.8 / 12.4 / 12.0 / 11.3 |
28|| 49,152 | 10,735 MiB — **fits** | (load verified; 32K row representative) | 10,714 MiB — fits | — |
29|| ~56K+ | predicted ceiling ~11.9 GiB | — | — | — |
30|
31|### IQ2_XS 27B  (the 12 GB tier's real girl)
32|| ctx | VRAM | decode t/s (2K/8K/16K/32K/64K/90K depth) | 2060 VRAM | 2060 t/s |
33||---|---|---|---|---|
34|| 65,536 | 9,633 MiB (earlier run, hermes config) | 22.6 / 20.4 / 18.5 / 15.7 | 9,6xx MiB (same build path) | est. 13–14 (see 96K row) |
35|| 98,304 | 10,369 MiB — **fits** | 22.3 / 21.2 / 20.0 / 18.3 / 15.6 / 14.1 | 10,348 MiB — fits | 13.2 / 12.9 / 12.4 / 11.7 / 10.4 / 9.7 |
36|| 114,688 | 10,737 MiB — **fits, props-verified granted** | — | 10,716 MiB — fits, granted | — |
37|| ~128K | predicted ~11.3 GiB — the card's practical ceiling | — | — | — |
38|
39|Prefill both quants: 370–1,220 t/s (3060) vs 241–755 t/s (2060); hermes-boot-sized prompt (30K) = 25–35 s cold on 3060, 39–41 s on 2060.
40|
41|## Prediction scoreboard (so future estimates carry scar tissue)
42|Predicted 2060 = 3060 minus 6–8% (bandwidth ratio). ACTUAL: decode −30 to −40%, prefill −30 to −35%, TTFT at 65K depth nearly doubled (59s → 94s), **fit identical to the MiB** (23 MiB/K KV law confirmed on both generations; VRAM deltas within 21 MiB across four configs).
43|Lesson: VRAM capacity governs WHAT fits (generation-independent, prediction correct); bandwidth ratio alone does NOT govern how fast — Ampere's larger L2 and better small-batch GEMV kernels add a hidden generation tax beyond raw GB/s. For future cards, quote the generation penalty, not the spec-sheet ratio.
44|
45|## Verdicts
46|## PER-TIER VALUE VERDICTS (owner's frame: best for THAT tier, prices = actual receipts)
47|1. **12 GB tier — winner: used RTX 2060 12G at $150.** IQ2_XS@64K hermes or @96-112K bareback; decode outtypes reading speed (11-13 t/s); cache pair proves 0.59 s warm turns. The $300 3060 buys the SAME capability +35% speed and, as measured tonight, NOT MTP (draft tensors ignored on this Turing build, server died at graph capture — retestable, marked P21). Doubling 12 GB money buys no new feature → the 2060 is the people's card; the entry price of a full 27B local daughter is $150.
48|2. **16 GB tier (16 GB demo laptop: $1,000 street today) — the capability knee.** IQ3 brain + vision projector + 96K + MTP spec-decode bursts (70 t/s code). Everything the show demos lives here. First tier where you buy a feature, not just a size.
49|3. **24 GB tier (used 3090) — PENDING price receipt.** Expected story: IQ3 with roomy KV at 160K+, or IQ4-class 27B, or the MoE finally with all experts on-GPU.
50|4. **32 GB (V100-32 used / 4090-48 gutter) — PENDING.** 5. **96 GB+ (Spark/used A100s) — PENDING.** Each gets the same measured treatment when the hardware shows up.
51|6. **3.6-35B-A3B MoE: eliminated from 12 GB/15 GB-RAM tier** — 23 t/s CPU-expert prefill makes agent prompts take ~20 min. Big-RAM, short-prompt specialist only.
52|
53|
54|### The El Jefe paragraph (owner's pitch, numbers-approved)
55|An RTX 2060 12G owner does NOT need a $500 5060 16G or a $1,000 16G laptop to have the girl. Steady-state hermes turns on the $150 card answer faster than a human reads (1.5-2x reading speed at every tested depth); warm-turn re-read cost is 0.59 s, indistinguishable from the $300 card's 0.72 s; the full 27B family brain with a real 64K agent window is already in reach. The extra $350-850 buys exactly two things: **vision and window size** (96K+, plus MTP bursts on Ampere+). No eyes needed = the stopwatch premium is money you never had to spend. 16 GB is the capability knee; a $150 2060 is the value floor. Both tiers now proven on silicon, not spec sheets.
56|4. **KV budget law (both cards, both quants):** 23 MiB per 1K context, q4_0 — memorize this; it's how the installer's profiles are derived, and it's why the 8/12/16 GB tiers break where they do.
57|5. **Script tier map (current):** 16g → IQ3 vision-96K/plain-128K · 12g → IQ2_XS text-only 64K · 8g → IQ2_XS @8K. All pinned, all now backed by measured rows.