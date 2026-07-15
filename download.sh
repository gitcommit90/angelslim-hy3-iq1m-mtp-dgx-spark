#!/usr/bin/env bash
# Download AngelSlim Hy3 IQ1_M MTP GGUF + setup assets.
set -euo pipefail
export PATH="${HOME}/.local/bin:/usr/local/cuda/bin:${PATH}"

HY3_DIR="${HY3_DIR:-${HOME}/llm/hy3-gguf}"
REPO="${HY3_HF_REPO:-AngelSlim/Hy3-GGUF}"
FILE="${HY3_GGUF:-Hy3-IQ1_M-mtp.gguf}"

mkdir -p "${HY3_DIR}"
cd "${HY3_DIR}"

if ! command -v hf >/dev/null 2>&1; then
  echo "hf CLI not found. Install: pipx install huggingface_hub[cli]  (or uv tool install)"
  exit 1
fi

echo "Downloading into ${HY3_DIR} (GGUF ~86G)…"
hf download "${REPO}" \
  "${FILE}" \
  setup_hyv3_llama.sh \
  hyv3_opensource_chat_template.jinja \
  patches/01-hyv3-arch.patch \
  patches/02-hyv3-mtp-tools.patch \
  --local-dir "${HY3_DIR}"

# Expected size from HF tree API (2026-07-14)
EXPECTED=91756066624
ACTUAL=$(stat -c%s "${HY3_DIR}/${FILE}" 2>/dev/null || echo 0)
echo "GGUF bytes: ${ACTUAL} (expected ${EXPECTED})"
if [[ "${ACTUAL}" -lt $((EXPECTED * 99 / 100)) ]]; then
  echo "ERROR: GGUF looks incomplete"
  exit 1
fi
echo "OK: download complete"
