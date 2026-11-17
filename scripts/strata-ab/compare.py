#!/usr/bin/env python3
"""Compare ab.sh arms against the base arm.

  compare.py RESULTS_DIR...

The base is the first arm whose name is 'base', else the first arm. decode is the median of
the server's decode_tok_s; paired is the mean ratio of answers to the same prompt (kind and
subject): an engine-level arm against the base, a per-request arm against the {} arm of its
own run, which is what to read for differences of a few percent. prefill is tokens read per
prompt_ms of each fresh prompt, then (after '>') the decode tok/s of the answer that follows it;
the engine's VRAM cache follows recent requests, so compare arms of one run order only. KL is the
mean first-token KL(base || arm) over top-20 logprobs,
with top-1 agreement; RSS is the engine's resident memory after the run.
"""

import json
import math
import pathlib
import statistics
import sys


def kl(p_lp, q_lp, floor=-20.0):
    """KL(p || q) over the union of two top-20 lists, each renormalised; a missing token gets `floor`."""
    keys = set(p_lp) | set(q_lp)
    p = {k: math.exp(p_lp.get(k, floor)) for k in keys}
    q = {k: math.exp(q_lp.get(k, floor)) for k in keys}
    sp, sq = sum(p.values()), sum(q.values())
    return sum((p[k] / sp) * math.log((p[k] / sp) / (q[k] / sq)) for k in keys)


def top1(d):
    return max(d, key=d.get) if d else None


def med(xs):
    xs = [x for x in xs if x is not None]
    return statistics.median(xs) if xs else float("nan")


def key(d):
    return d["kind"], d.get("subject", d.get("round"))


def by_prompt(ds):
    return {key(d): d["decode_tok_s"] for d in ds if d.get("decode_tok_s")}


def paired(ref, ds):
    """Mean % difference and wins over answers to the same prompts as `ref` (a {prompt: tok/s} map)."""
    mine = by_prompt(ds)
    diffs = [100 * (mine[k] / ref[k] - 1) for k in mine if k in ref]
    if not diffs:
        return "-"
    return f"{statistics.mean(diffs):+5.1f}% {sum(x > 0 for x in diffs)}/{len(diffs)}"


def main(dirs):
    files = sorted((f for d in dirs for f in pathlib.Path(d).glob("*.json")), key=lambda f: f.stat().st_mtime)
    runs = [r for r in (json.loads(f.read_text()) for f in files if not f.name.startswith(".")) if "decode" in r]
    if not runs:
        sys.exit("no results")
    base = next((r for r in runs if r["label"].split("-", 1)[-1] == "base"), runs[0])
    base_ds = [d for d in base["decode"] if d["tune"] == {}]
    b_rate, b_ref = med(d["decode_tok_s"] for d in base_ds), by_prompt(base_ds)
    print(f"baseline: {base['label']} ({b_rate:.1f} tok/s)")
    print(f"{'arm':38s} {'decode':>6s} {'paired':>11s} {'accept':>6s} {'hit':>5s} {'pcie':>5s} "
          f"{'prefill tok/s':>22s} {'evict ms':>11s} {'KL':>7s} {'top1':>5s} {'RSS':>5s}")
    for r in runs:
        tunes = sorted({json.dumps(d["tune"], sort_keys=True) for d in r["decode"]})
        own_ref = by_prompt([d for d in r["decode"] if d["tune"] == {}])
        for tune in tunes:
            ds = [d for d in r["decode"] if json.dumps(d["tune"], sort_keys=True) == tune]
            default = tune == "{}"
            # a per-request arm against its own run's {} arm; an engine-level arm against the base
            pr = paired(b_ref, ds) if default else paired(own_ref, ds)
            acc = med(d["drafts_accepted"] / d["drafts_offered"] for d in ds if d.get("drafts_offered"))
            hit = med(d.get("hit_rate") for d in ds)
            pcie = med(float(d["pcie_share"]) if d.get("pcie_share") is not None else None for d in ds)
            ev = f"{r.get('evicted_ms_at_start')}+{sum(d['evicted_ms_delta'] or 0 for d in ds)}"
            # prompt tok/s, then the decode of the answer that follows it (long-context decode)
            pf = " ".join(f"{p['tok_s']:.0f}" + (f">{p['decode_tok_s']:.0f}" if p.get("decode_tok_s") else "")
                          for p in r["prefill"] if p.get("tok_s")) if default else ""
            kls = agree = "-"
            if default and r.get("kl") and base.get("kl"):
                ks = [kl(p, q) for p, q in zip(base["kl"], r["kl"]) if p and q]
                kls = f"{statistics.mean(ks):.4f}" if ks else "-"
                agree = f"{sum(top1(p) == top1(q) for p, q in zip(base['kl'], r['kl']))}/{min(len(base['kl']), len(r['kl']))}"
            rss = (r.get("memory_gib") or {}).get("VmRSS", "-") if default else ""
            label = r["label"] + ("" if default else " " + tune)
            print(f"{label[:38]:38s} {med(d['decode_tok_s'] for d in ds):6.1f} {pr:>11s} {acc:6.2f} {hit:5.3f} "
                  f"{pcie:5.3f} {pf:>22s} {ev:>11s} {kls:>7s} {agree:>5s} {rss!s:>5s}")


if __name__ == "__main__":
    main(sys.argv[1:] or ["."])
