#!/usr/bin/env bash
# turnkey-llm install.sh — bare Ubuntu -> local uncensored Qwen3.8-27B + Hermes, one command.
# Viewer UX: `curl -fsSL <url>/install.sh | bash`  (sudo password is the only thing typed;
# plus two menu picks: vision mode + thinking level). Reboots once for the GPU driver and
# RESUMES ITSELF — via a login hook (you see it continue when you SSH back) and a boot
# oneshot (finishes even if nobody returns). Safe to re-run any time: completed stages skip.
set -u
VER="2.0-sam-bones-1022"
# test hook: FORCE_PROFILE=12g ./install.sh  (pre-select a tier without that hardware)
[ -n "${FORCE_PROFILE:-}" ] && echo "${FORCE_PROFILE}" > "$HOME/.install-profile"

# ---------- pins (verified live 2026-10-22; update deliberately, one place) ----------
LLAMA_REL="b11829"
M_MODEL="$HOME/models/qwen38-27b-iq3-unc-mtp.gguf"
M_MODEL_URL="https://huggingface.co/RentedNoodle/Qwen3.8-27B-GSQ-RCO-IQ3_XXS-Uncensored/resolve/main/Qwen3.8-27B-GSQ-RCO-IQ3_XXS-Uncensored-MTP.gguf"
M_MODEL_SHA="7422389f5e353ef5cd541871736823f58d029259a2f2362ef5a222ba0607c8a9"   # sha256
M_MODEL_BYTES=10442827584
M_MM="$HOME/models/mmproj-qwen38-27b.gguf"
M_MM_URL="https://huggingface.co/ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF/resolve/main/mmproj-Qwen3.8-27B-BF16.gguf"
M_MM_SHA="13cb7bebccbd04afc8f4090cb949ecf8937cdf7377c5799b1a0c594e7c0d3e16"
M_MM_BYTES=931146528
MODEL_SMALL_URL="https://huggingface.co/huihui-ai/Huihui-Qwen3.8-27B-abliterated-GGUF/resolve/main/Huihui-Qwen3.8-27B-abliterated-Swift-1.5-GSQ-RCO-IQ2_XS.gguf"
PORT=1234; ALIAS_V="qwen38-27b-unc-vision-96k"; ALIAS_P="qwen38-27b-unc-128k"
STATE="$HOME/.turnkey-llm.state"; PASSF="$HOME/.install-pass"
LOG="$HOME/install.log"; export TK="$HOME/.turnkey-llm"

say(){ echo "[installer] $*" | tee -a "$LOG"; }
die(){ say "STOP: $*"; say "Retry after fixing: re-run the same one-line command."; exit 1; }
have(){ [ -f "$STATE" ] && grep -qx "$1" "$STATE"; }
mark(){ grep -qx "$1" "$STATE" 2>/dev/null || echo "$1" >> "$STATE"; }

# ---------- resume plumbing ----------
SUDO(){ echo "$PASS" | sudo -S -p '' bash -c "$*"; }

command -v sudo >/dev/null || die "this system has no sudo - install sudo (or run as root) and re-run"
askpass(){
  local tries=0 PASS=""
  ( : </dev/tty ) 2>/dev/null || die "no terminal available for the sudo prompt - run the installer from a logged-in terminal (ssh counts)"
  while [ $tries -lt 3 ]; do
    printf "[installer] sudo password for %s (typed once, invisible as you type): " "$(id -un)" > /dev/tty
    read -rs PASS < /dev/tty
    printf "\r[installer] password accepted? checking...        \n" > /dev/tty
    ERR=$(printf '%s' "$PASS" | sudo -S -k -p '' true 2>&1 >/dev/null)
    if [ -z "$ERR" ]; then
      printf '%s' "$PASS" > "$PASSF"; chmod 600 "$PASSF"; printf "[installer] sudo password confirmed, stored 0600 for the reboot resume\n" | tee -a "$LOG"; return 0
    fi
    case "$ERR" in *"not in the sudoers file"*) die "user $(id -un) cannot use sudo - run the installer from an admin account (or add it to sudoers)";; esac
    printf "[installer] that password did not work - trying again\n" > /dev/tty
    tries=$((tries+1))
  done
  return 1
}
if [ -s "$PASSF" ]; then
  PASS=$(cat "$PASSF")
  printf '%s' "$PASS" | sudo -S -k -p '' true 2>/dev/null || { say "stored sudo password no longer works - re-asking"; askpass || die "sudo authentication failed 3 times"; }
else
  askpass || die "sudo authentication failed 3 times - re-run and type carefully"
fi

# ---------- single-instance lock (boot-oneshot vs login-hook arbitration) ----------
exec 9>"$HOME/.turnkey-llm.lock"
if ! flock -n 9; then
  if [ -f "$STATE" ] && grep -qx verify "$STATE"; then
    exit 0
  fi
  echo "[installer] install already running. Showing its live log - Ctrl+C to step away, it keeps going."
  tail -n 5 -f "$LOG" & TAILPID=$!
  trap "kill $TAILPID 2>/dev/null" EXIT INT TERM
  while sleep 2; do grep -qx verify "$STATE" 2>/dev/null && break; done
  kill $TAILPID 2>/dev/null; wait 2>/dev/null
  [ -f "$STATE" ] && grep -qx verify "$STATE" && { echo; echo "[installer] >>> install COMPLETE - run:  endpoint   for connection info."; sed -i '/turnkey-llm resume hook/,+1d' "$HOME/.bashrc" 2>/dev/null; }
  exit 0
fi

MODE_FILE="$HOME/.install-mode"; THINK_FILE="$HOME/.install-think"; AGENT_FILE="$HOME/.install-agent"
if [ ! -f "$MODE_FILE" ]; then
  echo; echo "Pick ONE (you can switch any time later with:  llama-mode vision|plain )";
  echo "  1) vision + 96K context    - it can see images";
  echo "  2) no vision + 128K context - deeper text sessions, no images";
  read -rp " [1/2, Enter=1] " ans < /dev/tty || ans=1
  case "$ans" in 2*) MODE=plain;; *) MODE=vision;; esac
  echo "$MODE" > "$MODE_FILE"
else MODE=$(cat "$MODE_FILE"); fi
if [ ! -f "$AGENT_FILE" ]; then
  echo; echo "What should sit on top of your new model?";
  echo "  1) Hermes Agent (chat terminal + tools + memory) - recommended";
  echo "  2) Raw endpoint only (skip Hermes - use the OpenAI-compatible API directly)";
  read -rp " [1/2, Enter=1] " aa < /dev/tty || aa=1
  case "$aa" in 2*) AGENT=off;; *) AGENT=hermes;; esac
  echo "$AGENT" > "$AGENT_FILE"
else AGENT=$(cat "$AGENT_FILE"); fi
if [ ! -f "$THINK_FILE" ] && [ "$AGENT" = hermes ]; then
  echo; echo "Thinking level for the hidden scratchpad (switch later: llama-mode --thinking low )";
  echo "  1) off (fastest)  2) low  3) medium (recommended)  4) high (slowest, deepest)";
  read -rp " [1-4, Enter=3] " t < /dev/tty || t=3
  case "$t" in 1*) TH=none;; 2*) TH=low;; 4*) TH=high;; *) TH=medium;; esac
  echo "$TH" > "$THINK_FILE"
else TH=$(cat "$THINK_FILE"); fi
[ "$AGENT" != hermes ] && TH=none

# ---------- STAGE 0: preflight (before ANY big download) ----------
if ! have preflight; then
  say "preflight v$VER"
  . /etc/os-release 2>/dev/null || die "not a recognized Linux (no /etc/os-release)"
  [ "${ID:-}" = ubuntu ] || [ "${ID_LIKE:-}" = ubuntu ] || die "this build targets Ubuntu (detected: $ID). Please run on Ubuntu 22.04+."
  command -v lspci >/dev/null 2>&1 && ! lspci 2>/dev/null | grep -qi nvidia && die "no NVIDIA GPU detected on this machine - the show build needs one"
  FREEDISK=$(df -BG --output=avail "$HOME" | tail -1 | tr -dc '0-9')
  [ "${FREEDISK:-0}" -ge 30 ] || die "need >=30 GB free disk in $HOME (have ${FREEDISK}GB)"
  VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
  [ -n "$VRAM" ] || VRAM=unknown   # no driver yet is fine - stage 1 installs it
  if   [ "${FORCE_PROFILE:-}" = 12g ]; then PROFILE=12g   # env override for testing other tiers
  elif [ "$VRAM" = unknown ]; then PROFILE=16g
  elif [ "$VRAM" -ge 14336 ]; then PROFILE=16g
  elif [ "$VRAM" -ge 10752 ]; then PROFILE=12g
  elif [ "$VRAM" -ge  7168 ]; then PROFILE=8g
  else PROFILE=small; fi
  echo "$PROFILE" > "$HOME/.install-profile"
  say "GPU: ${VRAM} MiB VRAM -> profile $PROFILE ; disk OK (${FREEDISK}GB free)"
  [ "$PROFILE" = small ] && die "your card has ${VRAM}MiB - under the 8GB floor for this model. Options: a bigger box, or watch the episode anyway."
  mark preflight
fi
PROFILE=$(cat "$HOME/.install-profile")

# ---------- STAGE 1: driver (may reboot once; resumes automatically) ----------
if ! have driver; then
  if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
    say "driver already active - skipping"; mark driver
  else
    say "installing NVIDIA driver (this is the step that needs ONE reboot, ~2 min)"
    SUDO "apt-get update -qq && apt-get install -y -qq linux-headers-\$(uname -r) nvidia-driver-595 || ubuntu-drivers autoinstall" || die "driver install failed (see above)"
    # arm the resume path: LOGIN HOOK ONLY (owner's call: after the driver reboot the install
    # resumes visibly when the viewer SSHes in — the box waits quietly until then).
    cp -f "$0" "$HOME/install.sh" 2>/dev/null || true; chmod +x "$HOME/install.sh" 2>/dev/null || true
    loginctl enable-linger "$(id -un)" 2>/dev/null || true   # lets the llama service itself start at boot later
    HOOK='# turnkey-llm resume hook (auto-added; removed when install completes)
[ -f "$HOME/.turnkey-llm.incomplete" ] && bash "$HOME/install.sh" --resumed || true'
    grep -q 'turnkey-llm resume hook' "$HOME/.bashrc" 2>/dev/null || echo "$HOOK" >> "$HOME/.bashrc"
    touch "$HOME/.turnkey-llm.incomplete"
    say "==========================================================="
    say " REBOOTING NOW - your SSH will drop. That is normal."
    say " Log back in in ~2 minutes: the install RESUMES ON SCREEN the"
    say " moment your prompt appears - you will watch it finish. It also"
    say " never started without you: this box waits for your login."
    say "==========================================================="
    sleep 3
    SUDO "systemctl reboot" || die "reboot failed - run: sudo reboot, then re-run the installer"
    exit 0
  fi
fi
# resumed after reboot via login hook (or driver was already there)
mark driver

# ---------- STAGE 2: llama.cpp CUDA binaries (no compile) ----------
if ! have llama; then
  ARCH=$(uname -m); case "$ARCH" in x86_64) A=x64;; aarch64) A=arm64;; *) die "unsupported arch $ARCH";; esac
  CUDA=12.8; [ "$A" = arm64 ] && CUDA=13.4
  U="https://github.com/ggml-org/llama.cpp/releases/download/$LLAMA_REL"
  mkdir -p "$TK"
  say "downloading llama.cpp $LLAMA_REL (cuda $CUDA, $A) ~50MB"
  dl(){ curl -fL --retry 5 --retry-all-errors -C - --speed-time 60 --speed-limit 1000 -o "$1" "$2" || { rm -f "$1"; die "$(basename "$1") download failed (flaky network?) - just re-run the same command, it resumes"; }; }
  dl "$TK/llama.tar.gz"  "$U/llama-$LLAMA_REL-bin-ubuntu-cuda-$CUDA-$A.tar.gz"
  dl "$TK/cudart.tar.gz" "$U/cudart-llama-$LLAMA_REL-bin-ubuntu-cuda-$CUDA-$A.tar.gz"
  tar -tzf "$TK/llama.tar.gz" >/dev/null 2>&1 || { rm -f "$TK/llama.tar.gz"; die "llama archive corrupt - re-run"; }
  tar -xzf "$TK/llama.tar.gz" -C "$TK" && tar -xzf "$TK/cudart.tar.gz" -C "$TK"
  BIN=$(find "$TK" -name llama-server -type f | head -1); [ -n "$BIN" ] || die "llama-server not found in archive"
  readlink -f "$BIN" > "$TK/bin.path"; ln -sf "$BIN" "$TK/llama-server"
  mark llama
fi
BIN=$(cat "$TK/bin.path" 2>/dev/null); LIBDIR=$(dirname "$BIN")

# ---------- STAGE 2.5: CUDA runtime libs (cublas/cudart) ----------
# The driver gives libcuda only. llama's CUDA backend ALSO needs libcublas.so.12
# (+libcublasLt, +libcudart). apt has none of these on plain Ubuntu and llama's
# cudart tarball omits cublas - without them llama SILENTLY runs everything on
# CPU (the 25-minutes-of-"thinking" trap). PyPI NVIDIA wheels: no repos, no
# toolkit, ~850MB, self-contained.
CUDA_LIBS="$TK/cuda-libs"
if ! have cuda; then
  mkdir -p "$CUDA_LIBS"
  for W in nvidia-cublas-cu12 nvidia-cuda-runtime-cu12; do
    if ! ls "$CUDA_LIBS"/lib$( [ "$W" = nvidia-cublas-cu12 ] && echo cublas || echo cudart ).so.12 >/dev/null 2>&1; then
      say "fetching CUDA runtime from $W (one-time, ~850MB)"
      U=$(curl -sf https://pypi.org/pypi/$W/json | python3 -c 'import json,sys; d=json.load(sys.stdin); us=[u["url"] for u in d["urls"] if "manylinux" in u["filename"] and "x86_64" in u["filename"]]; print(us[0])') || die "pypi lookup failed - re-run the same command"
      curl -fL --retry 3 -o "/tmp/$W.whl" "$U" || die "CUDA runtime download failed - re-run"
      python3 -m zipfile -e "/tmp/$W.whl" "/tmp/$W.x"
      find "/tmp/$W.x" \( -name "libcublas.so.12*" -o -name "libcublasLt.so.12*" -o -name "libcudart.so.12*" \) -exec cp -f {} "$CUDA_LIBS/" \;
      rm -rf "/tmp/$W.whl" "/tmp/$W.x"
    fi
  done
  ls "$CUDA_LIBS"/libcublas.so.12 >/dev/null 2>&1 || die "cublas not in place after fetch - re-run"
  mark cuda
fi
# proof it actually sees the card, BEFORE we waste 10GB of load time guessing
"$LIBDIR/llama-server" --list-devices 2>/dev/null | grep -qi cuda || \
  { LD_LIBRARY_PATH="$LIBDIR:$CUDA_LIBS" "$LIBDIR/llama-server" --list-devices 2>/dev/null | grep -qi cuda || die "CUDA backend cannot see the GPU - driver/fabric problem, not an installer problem"; }

# ---------- STAGE 3: models (verify -> skip -> resume-download -> SHA256 gate) ----------
fetch(){ # $1 path $2 url $3 sha $4 bytes ; direct-to-~/models, never the hf cache
  mkdir -p "$HOME/models"
  if [ -f "$1" ] && [ "$(stat -c%s "$1")" = "$4" ] && [ "$(sha256sum "$1" | cut -d' ' -f1)" = "$3" ]; then
    say "$(basename "$1"): present, correct - skipping"; return 0; fi
  say "downloading $(basename "$1") (~$(( $4 / 1073741824 )) GB, resumable - grab coffee)"
  curl -fL -C - --retry 5 --retry-delay 5 -o "$1.part" "$2" || { rm -f "$1.part"; die "download interrupted - re-run the same command to resume"; }
  GOT=$(sha256sum "$1.part" | cut -d' ' -f1)
  [ "$GOT" = "$3" ] || { mv "$1.part" "$1.corrupt-$GOT"; die "checksum mismatch (got $GOT) - file kept for inspection"; }
  mv "$1.part" "$1"; }
if ! have models; then
  case "$PROFILE" in
    16g) [ "$MODE" = vision ] && fetch "$M_MM" "$M_MM_URL" "$M_MM_SHA" "$M_MM_BYTES"; fetch "$M_MODEL" "$M_MODEL_URL" "$M_MODEL_SHA" "$M_MODEL_BYTES" ;;
    12g) say "12G card: IQ2_XS brain (smaller, honest), text-only, 64K context"
         fetch "$HOME/models/qwen38-27b-iq2xs-unc.gguf" "$MODEL_SMALL_URL" skip 0 ;;
    8g|small) say "profile $PROFILE: using the smaller IQ2_XS quant (fits 8GB; less context)"
         fetch "$HOME/models/qwen38-27b-iq2xs-unc.gguf" "$MODEL_SMALL_URL" skip 0 ;;
  esac
  mark models
fi

# ---------- STAGE 4: serve (systemd, survives reboot; llama-mode switch) ----------
if ! have serve; then
  CTX_V=98304; CTX_P=131072
  unit(){ # $1 suffix $2 ctx $3 mmproj-or-empty $4 alias
    local mm=""; [ -n "$3" ] && mm="--mmproj $3 --image-min-tokens 1024"
    cat > "/tmp/llama-$1.service" <<EOS
[Unit]
Description=Qwen3.8-27B unc IQ3 ($1)
After=network.target
[Service]
Environment=LD_LIBRARY_PATH=$LIBDIR:$CUDA_LIBS
ExecStart=$BIN -m $4 $mm --spec-type draft-mtp --spec-draft-n-max 8 --alias $5 --host 0.0.0.0 --port $PORT -ngl 99 -np 1 -c $2 --cache-type-k q4_0 --cache-type-v q4_0 -n 8192 --jinja -fa on
Restart=on-failure
RestartSec=5
[Install]
WantedBy=default.target
EOS
    cp "/tmp/llama-$1.service" "$HOME/.config/systemd/user/"; }
    mkdir -p "$HOME/.config/systemd/user"
  if [ "$PROFILE" = 16g ]; then
    if [ "$MODE" = vision ]; then unit vision-96k "$CTX_V" "$M_MM" "$M_MODEL" "$ALIAS_V"; ACTIVE=vision-96k; else ACTIVE=""; fi
    unit plain-128k "$CTX_P" "" "$M_MODEL" "$ALIAS_P"; [ -z "${ACTIVE:-}" ] && ACTIVE=plain-128k
  else
    case "$PROFILE" in
      12g) unit plain "65536" "" "$HOME/models/qwen38-27b-iq2xs-unc.gguf" "$ALIAS_P" ;;
      *)   unit plain "8192"  "" "$HOME/models/qwen38-27b-iq2xs-unc.gguf" "$ALIAS_P" ;;
    esac
    ACTIVE=plain
  fi
  cat > "$TK/llama-mode" <<'EOS'
#!/bin/bash
# switch between installed modes:  llama-mode vision | llama-mode plain
[ -z "${1:-}" ] && { echo "usage: llama-mode vision|plain"; exit 1; }
systemctl --user stop llama-vision-96k.service llama-plain-128k.service llama-plain.service 2>/dev/null
systemctl --user start "llama-$1.service" 2>/dev/null || systemctl --user start llama-plain.service
echo "$1" > "$HOME/.install-mode"
echo "now serving: $1 mode"
EOS
  chmod +x "$TK/llama-mode"
  ln -sf "$TK/llama-mode" "$HOME/.local/bin/llama-mode" 2>/dev/null || true
  cat > "$TK/install-status" <<'EOS'
#!/bin/bash
S="$HOME/.turnkey-llm.state"
if [ ! -f "$S" ]; then echo "install not started"; exit 0; fi
ALL="preflight driver llama models serve hermes verify"
DONE=$(cat "$S"); for st in $ALL; do grep -qx "$st" <<<"$DONE" && echo "  [x] $st" || echo "  [ ] $st ($([ "$st" = models ] && echo 'next: resume download by re-running the installer')$(systemctl --user is-active llama-"$(cat "$HOME/.install-active" 2>/dev/null)".service 2>/dev/null | grep -q active && [ "$st" = serve ] && echo ' - server RUNNING'))"; done
curl -s -m 5 "http://127.0.0.1:1234/v1/models" >/dev/null 2>&1 && echo "  server: answering on :1234" || echo "  server: not responding yet"
EOS
  chmod +x "$TK/install-status"
  ln -sf "$TK/install-status" "$HOME/.local/bin/install-status" 2>/dev/null || true
  echo "$ACTIVE" > "$HOME/.install-active"
  systemctl --user daemon-reload
  systemctl --user enable --now "llama-$ACTIVE.service"
  loginctl enable-linger "$(id -un)" 2>/dev/null || true
  mark serve
fi

# ---------- STAGE 5: optional agent layer (Hermes) ----------
if [ "$AGENT" = hermes ] && ! have hermes; then
  export PATH="$HOME/.local/bin:$PATH"
  HR="$(command -v hermes || true)"; [ -n "$HR" ] || HR="$HOME/.local/bin/hermes"
  if [ -x "$HR" ]; then say "hermes present"; else
    say "installing Hermes Agent (official installer)"
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup || die "hermes install failed - check network, re-run the same command"
    hash -r 2>/dev/null || true
  fi
  [ -x "$HR" ] || die "hermes binary not found after install (~/.local/bin/hermes missing)"
  alias_use=$([ "$MODE" = vision ] && [ "$PROFILE" = 16g ] && echo "$ALIAS_V" || echo "$ALIAS_P")
  "$HR" config set model.provider custom \
    && "$HR" config set model.base_url "http://127.0.0.1:$PORT/v1" \
    && "$HR" config set model.default "$alias_use" \
    && "$HR" config set model.api_key 'local' \
    && "$HR" config set model.reasoning_effort "$TH" \
    || die "failed to write hermes model config"
  mark hermes
fi

# ---------- STAGE 5.5: prefill hermes first-run state ----------
# The first-run wizard is what "configured" checks custom_providers in auth for.
# Write the same block it would have written (verified live on the 16 GB demo rig 10/23:
# hermes -z answers with zero prompts after this exists), so `hermes` on the
# viewer's box goes straight to chat. Non-fatal by design: worst case the
# wizard appears as tonight, and the values it asks for are already defaults.
if [ "$AGENT" = hermes ] && ! have prefill; then
  USE_ALIAS=$([ "$MODE" = vision ] && [ "$PROFILE" = 16g ] && echo "$ALIAS_V" || echo "$ALIAS_P")
  if ! grep -q "^custom_providers:" "$HOME/.hermes/config.yaml" 2>/dev/null; then
    say "prefilling hermes first-run state (skips the setup wizard)"
    cat >> "$HOME/.hermes/config.yaml" <<EOC
custom_providers:
  - name: Local ($PORT)
    base_url: http://127.0.0.1:$PORT/v1
    model: $USE_ALIAS
    api_mode: chat_completions
    models:
      $USE_ALIAS: {}
    models_discovered: true
EOC
  fi
  mark prefill
fi

# ---------- STAGE 5.75: endpoint info command (every mode) ----------
if ! have endpoint; then
  cat > "$TK/endpoint" <<'EOE'
#!/bin/bash
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "=================================================================="
echo " YOUR LOCAL MODEL ENDPOINT"
echo "   base URL : http://__IP__:__PORT__/v1        (also: 127.0.0.1 from this box)"
echo "   model    : __ALIAS__"
echo "   api key  : none required"
echo "   try it   :"
echo "     curl http://__IP__:__PORT__/v1/chat/completions \\"
echo "       -H 'Content-Type: application/json' \\"
BODY="-d '{"model":"__ALIAS__","messages":[{"role":"user","content":"hello"}]}'"
echo "       $BODY"
echo "   status   : $(curl -sf -m 4 http://127.0.0.1:__PORT__/health || echo 'server not running - check: systemctl --user status llama-*')"
echo "=================================================================="
EOE
  UA=$([ "$MODE" = vision ] && [ "$PROFILE" = 16g ] && echo "$ALIAS_V" || echo "$ALIAS_P")
  sed -i "s|__IP__|$(hostname -I 2>/dev/null | awk '{print $1}')|g; s|__PORT__|$PORT|g; s|__ALIAS__|$UA|g" "$TK/endpoint"
  chmod +x "$TK/endpoint"
  SUDO "cp $TK/endpoint /usr/local/bin/endpoint" 2>/dev/null || cp "$TK/endpoint" "$HOME/.local/bin/" 2>/dev/null || true
  mark endpoint
fi

# ---------- STAGE 6: verify with a real completion ----------
if ! have verify; then
  say "warming the model up (first read is cold; up to ~3 min on small cards)"
  for i in $(seq 1 36); do curl -sf -m 5 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && break; sleep 5; done   # wait for weights to finish loading before the proof shot
  USE_ALIAS=$([ "$MODE" = vision ] && [ "$PROFILE" = 16g ] && echo "$ALIAS_V" || echo "$ALIAS_P")
  T=$(date +%s)
  R=$(curl -sf -m 300 "http://127.0.0.1:$PORT/v1/chat/completions" -H 'Content-Type: application/json' \
      -d "{\"model\":\"$USE_ALIAS\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: TURKEY-READY\"}],\"max_tokens\":200}" || echo '{}')
  DT=$(( $(date +%s) - T ))
  echo "$R" | grep -q "TURKEY-READY\|TURKEY" || die "verification completion failed - check: systemctl --user status llama-*"
  # the answer alone can lie: a CPU-fallback server answers too, just 100x slower.
  # GPU-resident check: card must hold several GB, and the reply must have been quick.
  USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
  [ "${USED:-0}" -gt 6000 ] || die "the model answered but NOT from the GPU (card holds only ${USED:-?} MiB - cublas/cudart problem, see stage 2.5)"
  [ "$DT" -le 120 ] || say "WARN: first reply took ${DT}s - slower than GPU-resident speeds; check nvidia-smi power draw"
  say "VERIFIED: model answers FROM GPU (${USED} MiB resident) in ${DT}s on port $PORT."; mark verify
fi
rm -f "$HOME/.turnkey-llm.incomplete"
sed -i '/turnkey-llm resume hook/,+1d' "$HOME/.bashrc" 2>/dev/null || true
echo; say "DONE. your model is live on ALL network interfaces (mode: $MODE)."
SAY_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "  =================================================================="
echo "   ENDPOINT : http://$SAY_IP:$PORT/v1"
echo "   MODEL    : $([ "$MODE" = vision ] && [ "$PROFILE" = 16g ] && echo "$ALIAS_V" || echo "$ALIAS_P")"
echo "   anytime  : run the command:  endpoint"
echo "  =================================================================="
[ "${AGENT:-hermes}" = hermes ] && say "agent ready: run  hermes   to start talking" || say "raw endpoint mode: point any OpenAI-compatible app at the URL above"
