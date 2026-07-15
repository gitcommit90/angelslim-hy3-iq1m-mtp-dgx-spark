#!/usr/bin/env bash
# Build AngelSlim-patched llama.cpp with CUDA (hy_v3 + MTP).
set -euo pipefail
export PATH="/usr/local/cuda/bin:${HOME}/.local/bin:${PATH}"
export CUDACXX="${CUDACXX:-/usr/local/cuda/bin/nvcc}"

HY3_DIR="${HY3_DIR:-${HOME}/llm/hy3-gguf}"
TARGET="${HY3_LLAMA_DIR:-${HY3_DIR}/llama.cpp-hyv3}"
JOBS="${JOBS:-$(nproc)}"

if [[ ! -f "${HY3_DIR}/setup_hyv3_llama.sh" ]]; then
  echo "Missing ${HY3_DIR}/setup_hyv3_llama.sh — run ./download.sh first"
  exit 1
fi
if ! command -v nvcc >/dev/null 2>&1; then
  echo "nvcc not on PATH. On Spark: export PATH=/usr/local/cuda/bin:\$PATH"
  exit 1
fi

# Fresh or dirty tree: prefer clean re-run of setup when clone missing.
if [[ ! -x "${TARGET}/build/bin/llama-server" ]]; then
  if [[ -d "${TARGET}/.git" ]]; then
    echo "Existing clone without binary — resetting to clean pin + rebuild"
    # setup script refuses dirty tree; reset hard to unpatched pin if present
    (
      cd "${TARGET}"
      git reset --hard 19bba67c1f4db723c60a0d421aa0788bf4ddc699 2>/dev/null || true
      git clean -fd
    )
  fi
  CUDA=1 JOBS="${JOBS}" bash "${HY3_DIR}/setup_hyv3_llama.sh" "${TARGET}" || {
    # setup may fail if patches already applied; fall through to cmake rebuild
    echo "setup script failed or partial — attempting cmake rebuild on existing tree"
  }
fi

if [[ ! -x "${TARGET}/build/bin/llama-server" ]]; then
  cd "${TARGET}"
  cmake -B build -DCMAKE_BUILD_TYPE=Release \
    -DGGML_CUDA=ON -DLLAMA_BUILD_SERVER=ON -DLLAMA_OPENSSL=OFF -DGGML_NATIVE=OFF
  cmake --build build --config Release -j "${JOBS}" \
    --target llama llama-quantize llama-imatrix llama-server llama-cli
fi

test -x "${TARGET}/build/bin/llama-server"
echo "OK: ${TARGET}/build/bin/llama-server"
