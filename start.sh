#!/usr/bin/env bash
# Best measured Hy3 IQ1_M MTP serve on GB10 (single stream, 100k ctx).
set -euo pipefail
export PATH="/usr/local/cuda/bin:${HOME}/.local/bin:${PATH}"

HY3_DIR="${HY3_DIR:-${HOME}/llm/hy3-gguf}"
BIN="${HY3_LLAMA_DIR:-${HY3_DIR}/llama.cpp-hyv3}/build/bin"
MODEL="${HY3_DIR}/${HY3_GGUF:-Hy3-IQ1_M-mtp.gguf}"
TMPL="${HY3_DIR}/hyv3_opensource_chat_template.jinja"
PORT="${HY3_PORT:-8088}"
LOG="${HY3_LOG:-/tmp/hy3-iq1m-mtp-server.log}"

export LD_LIBRARY_PATH="${BIN}:${LD_LIBRARY_PATH:-}"

if [[ ! -x "${BIN}/llama-server" ]]; then
  echo "Missing llama-server — run ./build.sh"
  exit 1
fi
if [[ ! -f "${MODEL}" ]]; then
  echo "Missing model ${MODEL} — run ./download.sh"
  exit 1
fi
if [[ ! -f "${TMPL}" ]]; then
  echo "Missing chat template ${TMPL}"
  exit 1
fi

if pgrep -f "llama-server.*Hy3-IQ1_M-mtp" >/dev/null 2>&1; then
  echo "Already running:"
  pgrep -af "llama-server.*Hy3-IQ1_M-mtp" || true
  exit 0
fi

if ss -tlnp 2>/dev/null | grep -q ":${PORT} "; then
  echo "Port ${PORT} already in use"
  ss -tlnp | grep ":${PORT} " || true
  exit 1
fi

echo "Starting Hy3 IQ1_M MTP on :${PORT} (100k ctx, parallel=1, n_max=2, p_min=0.6)"
echo "First load can take 6–8 minutes. Log: ${LOG}"

setsid "${BIN}/llama-server" \
  -m "${MODEL}" \
  --host 0.0.0.0 --port "${PORT}" \
  --ctx-size 100000 \
  --parallel 1 \
  --n-gpu-layers 999 \
  --flash-attn on \
  --cache-type-k q4_0 \
  --cache-type-v q4_0 \
  --spec-type draft-mtp \
  --spec-draft-n-max 2 \
  --spec-draft-n-min 1 \
  --spec-draft-p-min 0.6 \
  --cache-type-k-draft q4_0 \
  --cache-type-v-draft q4_0 \
  --jinja \
  --chat-template-file "${TMPL}" \
  --metrics \
  --no-webui \
  >"${LOG}" 2>&1 < /dev/null &

echo "PID $!"
for i in $(seq 1 180); do
  if curl -sS -m 2 "http://127.0.0.1:${PORT}/v1/models" 2>/dev/null | grep -q Hy3; then
    echo "READY after ~$((i*5))s (polls)"
    free -h | head -2
    exit 0
  fi
  if ! pgrep -f "llama-server.*Hy3-IQ1_M-mtp" >/dev/null 2>&1; then
    if [[ "${i}" -ge 3 ]]; then
      echo "Server died — tail ${LOG}:"
      tail -40 "${LOG}" || true
      exit 1
    fi
  fi
  sleep 5
done
echo "TIMEOUT waiting for /v1/models — check ${LOG}"
tail -40 "${LOG}" || true
exit 1
