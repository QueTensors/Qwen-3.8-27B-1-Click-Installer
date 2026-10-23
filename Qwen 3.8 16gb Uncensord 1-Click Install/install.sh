1|#!/usr/bin/env bash
2|# turnkey-llm install.sh — bare Ubuntu -> local uncensored Qwen3.8-27B + Hermes, one command.
3|# Viewer UX: `curl -fsSL <url>/install.sh | bash`  (sudo password is the only thing typed;
4|# plus two menu picks: vision mode + thinking level). Reboots once for the GPU driver and
5|# RESUMES ITSELF — via a login hook (you see it continue when you SSH back) and a boot
6|# oneshot (finishes even if nobody returns). Safe to re-run any time: completed stages skip.
7|set -u
8|VER="2.0-sam-bones-1022"
9|# test hook: FORCE_PROFILE=12g ./install.sh  (pre-select a tier without that hardware)
10|[ -n "${FORCE_PROFILE:-}" ] && echo "${FORCE_PROFILE}" > "$HOME/.install-profile"
11|
12|# ---------- pins (verified live 2026-10-22; update deliberately, one place) ----------
13|LLAMA_REL="b11829"
14|M_MODEL="$HOME/models/qwen38-27b-iq3-unc-mtp.gguf"
15|M_MODEL_URL="https://huggingface.co/RentedNoodle/Qwen3.8-27B-GSQ-RCO-IQ3_XXS-Uncensored/resolve/main/Qwen3.8-27B-GSQ-RCO-IQ3_XXS-Uncensored-MTP.gguf"
16|M_MODEL_SHA="7422389f5e353ef5cd541871736823f58d029259a2f2362ef5a222ba0607c8a9"   # sha256
17|M_MODEL_BYTES=10442827584
18|M_MM="$HOME/models/mmproj-qwen38-27b.gguf"
19|M_MM_URL="https://huggingface.co/ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF/resolve/main/mmproj-Qwen3.8-27B-BF16.gguf"
20|M_MM_SHA="13cb7bebccbd04afc8f4090cb949ecf8937cdf7377c5799b1a0c594e7c0d3e16"
21|M_MM_BYTES=931146528
22|MODEL_SMALL_URL="https://huggingface.co/huihui-ai/Huihui-Qwen3.8-27B-abliterated-GGUF/resolve/main/Huihui-Qwen3.8-27B-abliterated-Swift-1.5-GSQ-RCO-IQ2_XS.gguf"
23|PORT=1234; ALIAS_V="qwen38-27b-unc-vision-96k"; ALIAS_P="qwen38-27b-unc-128k"
24|STATE="$HOME/.turnkey-llm.state"; PASSF="$HOME/.install-pass"
25|LOG="$HOME/install.log"; export TK="$HOME/.turnkey-llm"
26|
27|say(){ echo "[installer] $*" | tee -a "$LOG"; }
28|die(){ say "STOP: $*"; say "Retry after fixing: re-run the same one-line command."; exit 1; }
29|have(){ [ -f "$STATE" ] && grep -qx "$1" "$STATE"; }
30|mark(){ echo "$1" >> "$STATE"; }
31|
32|# ---------- resume plumbing ----------
33|SUDO(){ echo "$PASS" | sudo -S -p '' bash -c "$*"; }
34|
35|askpass(){
36|  local tries=0
37|  while [ $tries -lt 3 ]; do
38|    printf "[installer] sudo password for %s (typed once, invisible as you type): " "$(id -un)" > /dev/tty
39|    read -rs PASS < /dev/tty
40|    printf "\r[installer] password accepted? checking...        \n" > /dev/tty
41|    if printf '%s' "$PASS" | sudo -S -k -p '' true 2>/dev/null; then
42|      printf '%s' "$PASS" > "$PASSF"; chmod 600 "$PASSF"; printf "[installer] sudo password confirmed, stored 0600 for the reboot resume\n" | tee -a "$LOG"; return 0
43|    fi
44|    printf "[installer] that password did not work - trying again\n" > /dev/tty
45|    tries=$((tries+1))
46|  done
47|  return 1
48|}
49|if [ -s "$PASSF" ]; then
50|  PASS=$(cat "$PASSF")
51|  printf '%s' "$PASS" | sudo -S -k -p '' true 2>/dev/null || { say "stored sudo password no longer works - re-asking"; askpass || die "sudo authentication failed 3 times"; }
52|else
53|  askpass || die "sudo authentication failed 3 times - re-run and type carefully"
54|fi
55|
56|# ---------- single-instance lock (boot-oneshot vs login-hook arbitration) ----------
57|exec 9>"$HOME/.turnkey-llm.lock"
58|if ! flock -n 9; then
59|  if [ -f "$STATE" ] && grep -qx verify "$STATE"; then
60|    exit 0
61|  fi
62|  echo "[installer] install already running. Showing its live log - Ctrl+C to step away, it keeps going."
63|  tail -n 5 -f "$LOG" & TAILPID=$!
64|  trap "kill $TAILPID 2>/dev/null" EXIT INT TERM
65|  while sleep 2; do grep -qx verify "$STATE" 2>/dev/null && break; done
66|  kill $TAILPID 2>/dev/null; wait 2>/dev/null
67|  [ -f "$STATE" ] && grep -qx verify "$STATE" && { echo; echo "[installer] >>> install COMPLETE - run:  hermes   to talk to her."; sed -i '/turnkey-llm resume hook/,+1d' "$HOME/.bashrc" 2>/dev/null; }
68|  exit 0
69|fi
70|
71|MODE_FILE="$HOME/.install-mode"; THINK_FILE="$HOME/.install-think"
72|if [ ! -f "$MODE_FILE" ]; then
73|  echo; echo "Pick ONE (you can switch any time later with:  llama-mode vision|plain )";
74|  echo "  1) vision + 96K context    - she can see images";
75|  echo "  2) no vision + 128K context - deeper text sessions, no images";
76|  read -rp " [1/2, Enter=1] " ans < /dev/tty || ans=1
77|  case "$ans" in 2*) MODE=plain;; *) MODE=vision;; esac
78|  echo "$MODE" > "$MODE_FILE"
79|else MODE=$(cat "$MODE_FILE"); fi
80|if [ ! -f "$THINK_FILE" ]; then
81|  echo; echo "Thinking level for her hidden scratchpad (switch later: llama-mode --thinking low )";
82|  echo "  1) off (fastest)  2) low  3) medium (recommended)  4) high (slowest, deepest)";
83|  read -rp " [1-4, Enter=3] " t < /dev/tty || t=3
84|  case "$t" in 1*) TH=none;; 2*) TH=low;; 4*) TH=high;; *) TH=medium;; esac
85|  echo "$TH" > "$THINK_FILE"
86|else TH=$(cat "$THINK_FILE"); fi
87|
88|# ---------- STAGE 0: preflight (before ANY big download) ----------
89|if ! have preflight; then
90|  say "preflight v$VER"
91|  . /etc/os-release 2>/dev/null || die "not a recognized Linux (no /etc/os-release)"
92|  [ "${ID:-}" = ubuntu ] || [ "${ID_LIKE:-}" = ubuntu ] || die "this build targets Ubuntu (detected: $ID). Please run on Ubuntu 22.04+."
93|  command -v lspci >/dev/null 2>&1 && ! lspci 2>/dev/null | grep -qi nvidia && die "no NVIDIA GPU detected on this machine - the show build needs one"
94|  FREEDISK=$(df -BG --output=avail "$HOME" | tail -1 | tr -dc '0-9')
95|  [ "${FREEDISK:-0}" -ge 30 ] || die "need >=30 GB free disk in $HOME (have ${FREEDISK}GB)"
96|  VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
97|  [ -n "$VRAM" ] || VRAM=unknown   # no driver yet is fine - stage 1 installs it
98|  if   [ "${FORCE_PROFILE:-}" = 12g ]; then PROFILE=12g   # env override for testing other tiers
99|  elif [ "$VRAM" = unknown ]; then PROFILE=16g
100|  elif [ "$VRAM" -ge 14336 ]; then PROFILE=16g
101|  elif [ "$VRAM" -ge 10752 ]; then PROFILE=12g
102|  elif [ "$VRAM" -ge  7168 ]; then PROFILE=8g
103|  else PROFILE=small; fi
104|  echo "$PROFILE" > "$HOME/.install-profile"
105|  say "GPU: ${VRAM} MiB VRAM -> profile $PROFILE ; disk OK (${FREEDISK}GB free)"
106|  [ "$PROFILE" = small ] && die "your card has ${VRAM}MiB - under the 8GB floor for this model. Options: a bigger box, or watch the episode anyway."
107|  mark preflight
108|fi
109|PROFILE=$(cat "$HOME/.install-profile")
110|
111|# ---------- STAGE 1: driver (may reboot once; resumes automatically) ----------
112|if ! have driver; then
113|  if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
114|    say "driver already active - skipping"; mark driver
115|  else
116|    say "installing NVIDIA driver (this is the step that needs ONE reboot, ~2 min)"
117|    SUDO "apt-get update -qq && apt-get install -y -qq linux-headers-\$(uname -r) nvidia-driver-595 || ubuntu-drivers autoinstall" || die "driver install failed (see above)"
118|    # arm the resume path: LOGIN HOOK ONLY (owner's call: after the driver reboot the install
119|    # resumes visibly when the viewer SSHes in — the box waits quietly until then).
120|    cp -f "$0" "$HOME/install.sh" 2>/dev/null || true; chmod +x "$HOME/install.sh" 2>/dev/null || true
121|    loginctl enable-linger "$(id -un)" 2>/dev/null || true   # lets the llama service itself start at boot later
122|    HOOK='# turnkey-llm resume hook (auto-added; removed when install completes)
123|[ -f "$HOME/.turnkey-llm.incomplete" ] && bash "$HOME/install.sh" --resumed || true'
124|    grep -q 'turnkey-llm resume hook' "$HOME/.bashrc" 2>/dev/null || echo "$HOOK" >> "$HOME/.bashrc"
125|    touch "$HOME/.turnkey-llm.incomplete"
126|    say "==========================================================="
127|    say " REBOOTING NOW - your SSH will drop. That is normal."
128|    say " Log back in in ~2 minutes: the install RESUMES ON SCREEN the"
129|    say " moment your prompt appears - you will watch it finish. It also"
130|    say " never started without you: this box waits for your login."
131|    say "==========================================================="
132|    sleep 3
133|    SUDO "systemctl reboot" || die "reboot failed - run: sudo reboot, then re-run the installer"
134|    exit 0
135|  fi
136|fi
137|# resumed after reboot via login hook (or driver was already there)
138|mark driver
139|
140|# ---------- STAGE 2: llama.cpp CUDA binaries (no compile) ----------
141|if ! have llama; then
142|  ARCH=$(uname -m); case "$ARCH" in x86_64) A=x64;; aarch64) A=arm64;; *) die "unsupported arch $ARCH";; esac
143|  CUDA=12.8; [ "$A" = arm64 ] && CUDA=13.4
144|  U="https://github.com/ggml-org/llama.cpp/releases/download/$LLAMA_REL"
145|  mkdir -p "$TK"
146|  say "downloading llama.cpp $LLAMA_REL (cuda $CUDA, $A) ~50MB"
147|  curl -fL --retry 3 -o "$TK/llama.tar.gz" "$U/llama-$LLAMA_REL-bin-ubuntu-cuda-$CUDA-$A.tar.gz" || die "llama download failed - re-run the same command"
148|  curl -fL --retry 3 -o "$TK/cudart.tar.gz"  "$U/cudart-llama-$LLAMA_REL-bin-ubuntu-cuda-$CUDA-$A.tar.gz" || die "cudart download failed - re-run"
149|  tar -xzf "$TK/llama.tar.gz" -C "$TK" && tar -xzf "$TK/cudart.tar.gz" -C "$TK"
150|  BIN=$(find "$TK" -name llama-server -type f | head -1); [ -n "$BIN" ] || die "llama-server not found in archive"
151|  readlink -f "$BIN" > "$TK/bin.path"; ln -sf "$BIN" "$TK/llama-server"
152|  mark llama
153|fi
154|BIN=$(cat "$TK/bin.path" 2>/dev/null); LIBDIR=$(dirname "$BIN")
155|
156|# ---------- STAGE 2.5: CUDA runtime libs (cublas/cudart) ----------
157|# The driver gives libcuda only. llama's CUDA backend ALSO needs libcublas.so.12
158|# (+libcublasLt, +libcudart). apt has none of these on plain Ubuntu and llama's
159|# cudart tarball omits cublas - without them llama SILENTLY runs everything on
160|# CPU (the 25-minutes-of-"thinking" trap). PyPI NVIDIA wheels: no repos, no
161|# toolkit, ~850MB, self-contained.
162|CUDA_LIBS="$TK/cuda-libs"
163|if ! have cuda; then
164|  mkdir -p "$CUDA_LIBS"
165|  for W in nvidia-cublas-cu12 nvidia-cuda-runtime-cu12; do
166|    if ! ls "$CUDA_LIBS"/lib$( [ "$W" = nvidia-cublas-cu12 ] && echo cublas || echo cudart ).so.12 >/dev/null 2>&1; then
167|      say "fetching CUDA runtime from $W (one-time, ~850MB)"
168|      U=$(curl -sf https://pypi.org/pypi/$W/json | python3 -c 'import json,sys; d=json.load(sys.stdin); us=[u["url"] for u in d["urls"] if "manylinux" in u["filename"] and "x86_64" in u["filename"]]; print(us[0])') || die "pypi lookup failed - re-run the same command"
169|      curl -fL --retry 3 -o "/tmp/$W.whl" "$U" || die "CUDA runtime download failed - re-run"
170|      python3 -m zipfile -e "/tmp/$W.whl" "/tmp/$W.x"
171|      find "/tmp/$W.x" \( -name "libcublas.so.12*" -o -name "libcublasLt.so.12*" -o -name "libcudart.so.12*" \) -exec cp -f {} "$CUDA_LIBS/" \;
172|      rm -rf "/tmp/$W.whl" "/tmp/$W.x"
173|    fi
174|  done
175|  ls "$CUDA_LIBS"/libcublas.so.12 >/dev/null 2>&1 || die "cublas not in place after fetch - re-run"
176|  mark cuda
177|fi
178|# proof it actually sees the card, BEFORE we waste 10GB of load time guessing
179|"$LIBDIR/llama-server" --list-devices 2>/dev/null | grep -qi cuda || \
180|  { LD_LIBRARY_PATH="$LIBDIR:$CUDA_LIBS" "$LIBDIR/llama-server" --list-devices 2>/dev/null | grep -qi cuda || die "CUDA backend cannot see the GPU - driver/fabric problem, not an installer problem"; }
181|
182|# ---------- STAGE 3: models (verify -> skip -> resume-download -> SHA256 gate) ----------
183|fetch(){ # $1 path $2 url $3 sha $4 bytes ; direct-to-~/models, never the hf cache
184|  mkdir -p "$HOME/models"
185|  if [ -f "$1" ] && [ "$(stat -c%s "$1")" = "$4" ] && [ "$(sha256sum "$1" | cut -d' ' -f1)" = "$3" ]; then
186|    say "$(basename "$1"): present, correct - skipping"; return 0; fi
187|  say "downloading $(basename "$1") (~$(( $4 / 1073741824 )) GB, resumable - grab coffee)"
188|  curl -fL -C - --retry 5 --retry-delay 5 -o "$1.part" "$2" || { rm -f "$1.part"; die "download interrupted - re-run the same command to resume"; }
189|  GOT=$(sha256sum "$1.part" | cut -d' ' -f1)
190|  [ "$GOT" = "$3" ] || { mv "$1.part" "$1.corrupt-$GOT"; die "checksum mismatch (got $GOT) - file kept for inspection"; }
191|  mv "$1.part" "$1"; }
192|if ! have models; then
193|  case "$PROFILE" in
194|    16g) [ "$MODE" = vision ] && fetch "$M_MM" "$M_MM_URL" "$M_MM_SHA" "$M_MM_BYTES"; fetch "$M_MODEL" "$M_MODEL_URL" "$M_MODEL_SHA" "$M_MODEL_BYTES" ;;
195|    12g) say "12G card: IQ2_XS brain (smaller, honest), text-only, 64K context"
196|         fetch "$HOME/models/qwen38-27b-iq2xs-unc.gguf" "$MODEL_SMALL_URL" skip 0 ;;
197|    8g|small) say "profile $PROFILE: using the smaller IQ2_XS quant (fits 8GB; less context)"
198|         fetch "$HOME/models/qwen38-27b-iq2xs-unc.gguf" "$MODEL_SMALL_URL" skip 0 ;;
199|  esac
200|  mark models
201|fi
202|
203|# ---------- STAGE 4: serve (systemd, survives reboot; llama-mode switch) ----------
204|if ! have serve; then
205|  CTX_V=98304; CTX_P=131072
206|  unit(){ # $1 suffix $2 ctx $3 mmproj-or-empty $4 alias
207|    local mm=""; [ -n "$3" ] && mm="--mmproj $3 --image-min-tokens 1024"
208|    cat > "/tmp/llama-$1.service" <<EOS
209|[Unit]
210|Description=Qwen3.8-27B unc IQ3 ($1)
211|After=network.target
212|[Service]
213|Environment=LD_LIBRARY_PATH=$LIBDIR:$CUDA_LIBS
214|ExecStart=$BIN -m $4 $mm --spec-type draft-mtp --spec-draft-n-max 8 --alias $5 --host 127.0.0.1 --port $PORT -ngl 99 -np 1 -c $2 --cache-type-k q4_0 --cache-type-v q4_0 -n 8192 --jinja -fa on
215|Restart=on-failure
216|RestartSec=5
217|[Install]
218|WantedBy=default.target
219|EOS
220|    cp "/tmp/llama-$1.service" "$HOME/.config/systemd/user/"; }
221|    mkdir -p "$HOME/.config/systemd/user"
222|  if [ "$PROFILE" = 16g ]; then
223|    if [ "$MODE" = vision ]; then unit vision-96k "$CTX_V" "$M_MM" "$M_MODEL" "$ALIAS_V"; ACTIVE=vision-96k; else ACTIVE=""; fi
224|    unit plain-128k "$CTX_P" "" "$M_MODEL" "$ALIAS_P"; [ -z "${ACTIVE:-}" ] && ACTIVE=plain-128k
225|  else
226|    case "$PROFILE" in
227|      12g) unit plain "65536" "" "$HOME/models/qwen38-27b-iq2xs-unc.gguf" "$ALIAS_P" ;;
228|      *)   unit plain "8192"  "" "$HOME/models/qwen38-27b-iq2xs-unc.gguf" "$ALIAS_P" ;;
229|    esac
230|    ACTIVE=plain
231|  fi
232|  cat > "$TK/llama-mode" <<'EOS'
233|#!/bin/bash
234|# switch between installed modes:  llama-mode vision | llama-mode plain
235|[ -z "${1:-}" ] && { echo "usage: llama-mode vision|plain"; exit 1; }
236|systemctl --user stop llama-vision-96k.service llama-plain-128k.service llama-plain.service 2>/dev/null
237|systemctl --user start "llama-$1.service" 2>/dev/null || systemctl --user start llama-plain.service
238|echo "$1" > "$HOME/.install-mode"
239|echo "now serving: $1 mode"
240|EOS
241|  chmod +x "$TK/llama-mode"
242|  ln -sf "$TK/llama-mode" "$HOME/.local/bin/llama-mode" 2>/dev/null || true
243|  cat > "$TK/install-status" <<'EOS'
244|#!/bin/bash
245|S="$HOME/.turnkey-llm.state"
246|if [ ! -f "$S" ]; then echo "install not started"; exit 0; fi
247|ALL="preflight driver llama models serve hermes verify"
248|DONE=$(cat "$S"); for st in $ALL; do grep -qx "$st" <<<"$DONE" && echo "  [x] $st" || echo "  [ ] $st ($([ "$st" = models ] && echo 'next: resume download by re-running the installer')$(systemctl --user is-active llama-"$(cat "$HOME/.install-active" 2>/dev/null)".service 2>/dev/null | grep -q active && [ "$st" = serve ] && echo ' - server RUNNING'))"; done
249|curl -s -m 5 "http://127.0.0.1:1234/v1/models" >/dev/null 2>&1 && echo "  server: answering on :1234" || echo "  server: not responding yet"
250|EOS
251|  chmod +x "$TK/install-status"
252|  ln -sf "$TK/install-status" "$HOME/.local/bin/install-status" 2>/dev/null || true
253|  echo "$ACTIVE" > "$HOME/.install-active"
254|  systemctl --user daemon-reload
255|  systemctl --user enable --now "llama-$ACTIVE.service"
256|  loginctl enable-linger "$(id -un)" 2>/dev/null || true
257|  mark serve
258|fi
259|
260|# ---------- STAGE 5: hermes + point it at her ----------
261|if ! have hermes; then
262|  export PATH="$HOME/.local/bin:$PATH"
263|  HR="$(command -v hermes || true)"; [ -n "$HR" ] || HR="$HOME/.local/bin/hermes"
264|  if [ -x "$HR" ]; then say "hermes present"; else
265|    say "installing Hermes Agent (official installer)"
266|    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup || die "hermes install failed - check network, re-run the same command"
267|    hash -r 2>/dev/null || true
268|  fi
269|  [ -x "$HR" ] || die "hermes binary not found after install (~/.local/bin/hermes missing)"
270|  alias_use=$([ "$MODE" = vision ] && [ "$PROFILE" = 16g ] && echo "$ALIAS_V" || echo "$ALIAS_P")
271|  "$HR" config set model.provider custom \
272|    && "$HR" config set model.base_url "http://127.0.0.1:$PORT/v1" \
273|    && "$HR" config set model.default "$alias_use" \
274|    && "$HR" config set model.api_key 'local' \
275|    && "$HR" config set model.reasoning_effort "$TH" \
276|    || die "failed to write hermes model config"
277|  mark hermes
278|fi
279|
280|# ---------- STAGE 5.5: prefill hermes first-run state ----------
281|# The first-run wizard is what "configured" checks custom_providers in auth for.
282|# Write the same block it would have written (verified live on the 16 GB demo rig 10/23:
283|# hermes -z answers with zero prompts after this exists), so `hermes` on the
284|# viewer's box goes straight to chat. Non-fatal by design: worst case the
285|# wizard appears as tonight, and the values it asks for are already defaults.
286|if ! have prefill; then
287|  USE_ALIAS=$([ "$MODE" = vision ] && [ "$PROFILE" = 16g ] && echo "$ALIAS_V" || echo "$ALIAS_P")
288|  if ! grep -q "^custom_providers:" "$HOME/.hermes/config.yaml" 2>/dev/null; then
289|    say "prefilling hermes first-run state (skips the setup wizard)"
290|    cat >> "$HOME/.hermes/config.yaml" <<EOC
291|custom_providers:
292|  - name: Local ($PORT)
293|    base_url: http://127.0.0.1:$PORT/v1
294|    model: $USE_ALIAS
295|    api_mode: chat_completions
296|    models:
297|      $USE_ALIAS: {}
298|    models_discovered: true
299|EOC
300|  fi
301|  mark prefill
302|fi
303|
304|# ---------- STAGE 6: verify with a real completion ----------
305|if ! have verify; then
306|  say "warming her up (first read is cold; up to ~2 min on small cards)"
307|  USE_ALIAS=$([ "$MODE" = vision ] && [ "$PROFILE" = 16g ] && echo "$ALIAS_V" || echo "$ALIAS_P")
308|  T=$(date +%s)
309|  R=$(curl -sf -m 300 "http://127.0.0.1:$PORT/v1/chat/completions" -H 'Content-Type: application/json' \
310|      -d "{\"model\":\"$USE_ALIAS\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: TURKEY-READY\"}],\"max_tokens\":200}" || echo '{}')
311|  DT=$(( $(date +%s) - T ))
312|  echo "$R" | grep -q "TURKEY-READY\|TURKEY" || die "verification completion failed - check: systemctl --user status llama-*"
313|  # the answer alone can lie: a CPU-fallback server answers too, just 100x slower.
314|  # GPU-resident check: card must hold several GB, and the reply must have been quick.
315|  USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
316|  [ "${USED:-0}" -gt 6000 ] || die "she answered but NOT from the GPU (card holds only ${USED:-?} MiB - cublas/cudart problem, see stage 2.5)"
317|  [ "$DT" -le 120 ] || say "WARN: first reply took ${DT}s - slower than GPU-resident speeds; check nvidia-smi power draw"
318|  say "VERIFIED: she answers FROM GPU (${USED} MiB resident) in ${DT}s on port $PORT."; mark verify
319|fi
320|rm -f "$HOME/.turnkey-llm.incomplete"
321|sed -i '/turnkey-llm resume hook/,+1d' "$HOME/.bashrc" 2>/dev/null || true
322|echo; say "DONE. her name is live at http://127.0.0.1:$PORT/v1 (mode: $MODE, thinking: $TH)."
323|say "switch modes: llama-mode vision|plain    check status: install-status    or just run: hermes"