#!/usr/bin/env python3
"""Regenerate the publication-quality benchmark summary from repository measurements."""
from pathlib import Path
import json
import matplotlib.pyplot as plt
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
OUT = HERE / "benchmark-summary"
PALETTE = {
    "blue": "#0F4D92", "blue2": "#3775BA", "green": "#8BCF8B",
    "green2": "#AADCA9", "red": "#B64342", "pink": "#E9A6A1",
    "gray": "#767676", "light": "#CFCECE", "dark": "#272727",
}
plt.rcParams.update({
    "font.family": ["Arial", "Helvetica", "DejaVu Sans", "sans-serif"],
    "font.size": 12, "axes.titlesize": 15, "axes.labelsize": 12,
    "axes.linewidth": 1.8, "axes.spines.right": False,
    "axes.spines.top": False, "legend.frameon": False,
    "svg.fonttype": "none", "pdf.fonttype": 42,
})

def label_bars(ax, bars, fmt="{:.1f}"):
    for bar in bars:
        h = bar.get_height()
        ax.annotate(fmt.format(h), (bar.get_x()+bar.get_width()/2, h),
                    xytext=(0, 4), textcoords="offset points", ha="center",
                    va="bottom", fontsize=10, fontweight="bold")

def finish(fig):
    fig.tight_layout(pad=1.5)
    fig.savefig(OUT.with_suffix(".png"), dpi=300, bbox_inches="tight", facecolor="white")
    fig.savefig(OUT.with_suffix(".pdf"), bbox_inches="tight", facecolor="white")

data = json.loads((ROOT / "bench_results.json").read_text())
h = data["headline"]
labels = ["Freeform", "Code", "JSON", "No MTP"]
vals = [h["warm_freeform_decode_tok_s"], h["structured_code_decode_tok_s"],
        h["structured_json_decode_tok_s"], h["no_mtp_baseline_tok_s"]]
fig, axes = plt.subplots(1, 2, figsize=(11.5, 4.7))
fig.suptitle("AngelSlim Hy3 IQ1_M — measured on one DGX Spark", fontsize=18, fontweight="bold")
bars=axes[0].bar(labels,vals,color=[PALETTE["blue2"],PALETTE["green"],PALETTE["blue"],PALETTE["light"]],edgecolor="black",linewidth=1.2)
label_bars(axes[0],bars); axes[0].set(title="Warm single-stream decode",ylabel="tokens/s")
axes[0].grid(axis="y",alpha=.18)
mem_labels=["4K\nno MTP","32K q8 KV\n+ MTP","100K\n+ MTP"]
mem=[90,101,109]
bars=axes[1].bar(mem_labels,mem,color=[PALETTE["light"],PALETTE["green"],PALETTE["blue"]],edgecolor="black",linewidth=1.2)
label_bars(axes[1],bars,"{:.0f}"); axes[1].axhline(121,color=PALETTE["red"],ls="--",lw=2,label="~121 GiB available")
axes[1].set(title="Measured host-memory use",ylabel="GiB used",ylim=(0,132)); axes[1].legend(loc="upper left",fontsize=9)
fig.text(.5,.005,"Source: bench_results.json and README measured configuration table",ha="center",color=PALETTE["gray"],fontsize=9)
finish(fig)
