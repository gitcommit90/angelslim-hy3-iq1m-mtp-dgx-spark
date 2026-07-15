#!/usr/bin/env python3
"""Short prose/code/json probe against local Hy3 llama-server."""
from __future__ import annotations

import json
import sys
import time
import urllib.request

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8088"
MODEL = sys.argv[2] if len(sys.argv) > 2 else "Hy3-IQ1_M-mtp.gguf"


def chat(prompt: str, max_tokens: int = 96) -> dict:
    url = BASE.rstrip("/") + "/v1/chat/completions"
    body = {
        "model": MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": max_tokens,
        "temperature": 0.0,
        "stream": True,
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
    )
    t0 = time.perf_counter()
    ttft = None
    n = 0
    text: list[str] = []
    with urllib.request.urlopen(req, timeout=600) as r:
        for raw in r:
            line = raw.decode("utf-8", "replace").strip()
            if not line.startswith("data:"):
                continue
            data = line[5:].strip()
            if data == "[DONE]":
                break
            try:
                obj = json.loads(data)
            except Exception:
                continue
            delta = ((obj.get("choices") or [{}])[0].get("delta") or {})
            piece = (
                delta.get("content")
                or delta.get("reasoning_content")
                or delta.get("reasoning")
                or ""
            )
            if piece:
                if ttft is None:
                    ttft = time.perf_counter() - t0
                text.append(piece)
                n += 1
    t1 = time.perf_counter()
    gen = (t1 - t0) - (ttft or 0)
    toks = max(n - 1, 0)
    rate = (toks / gen) if gen > 0 and toks > 0 else None
    return {
        "ttft_s": round(ttft or -1, 3),
        "total_s": round(t1 - t0, 3),
        "chunks": n,
        "decode_tps": round(rate, 2) if rate else None,
        "text": "".join(text)[:200],
    }


CASES = [
    ("prose", "Write two short sentences about why local LLMs matter. No bullet list.", 96),
    (
        "code",
        "Write a Python function fib(n) using iteration. Return only the code, no explanation.",
        120,
    ),
    (
        "json",
        'Return ONLY valid JSON: {"ok": true, "n": 3, "items": ["a","b","c"]}',
        64,
    ),
]


def main() -> None:
    # models probe
    with urllib.request.urlopen(BASE.rstrip("/") + "/v1/models", timeout=10) as r:
        print("models", r.status)
    for name, prompt, mt in CASES:
        res = chat(prompt, mt)
        print(
            f"{name}|ttft={res['ttft_s']}|total={res['total_s']}|"
            f"chunks={res['chunks']}|decode_tps={res['decode_tps']}|text={res['text']!r}"
        )


if __name__ == "__main__":
    main()
