#!/usr/bin/env python3
"""Measure one running Strata server: decode, fresh-prompt prefill, first-token logprobs.

Timings come from the server's own request history (GET /metrics), not from wall clock.
Per-request arms (--tune) are interleaved on the same engine; engine-level arms need a
restart and are driven by ab.sh, which calls this once per arm.

No two requests of one run share their text: the engine keeps recently fetched experts and
earlier answers around, and repeating an answer it just wrote measured up to 20% faster. Round r
of kind k uses subject (r + tune index) mod 6, so every engine-level arm reads the same prompts
and the per-request arms of one round never share a subject; over six rounds every per-request
arm reads all six (up to six arms), and compare.py pairs them by subject.
"""

import argparse
import json
import pathlib
import random
import statistics
import subprocess
import sys
import time
import urllib.request

DECODE_PROMPTS = {
    "code": ("Write a complete, well-commented Python module that implements {}, with type hints and a "
             "pytest test suite covering its edge cases.",
             ["a thread-safe LRU cache with per-entry TTL", "a token-bucket rate limiter with a decorator",
              "a trie supporting prefix search and deletion", "a priority task scheduler with cancellation",
              "an interval tree for overlapping-range queries", "a consistent-hashing ring with virtual nodes"]),
    "explain": ("Explain in detail how {} works. Use concrete examples and name the common pitfalls.",
                ["a CPU cache hierarchy, including MESI coherence and false sharing",
                 "TCP congestion control, from slow start to BBR", "garbage collection in G1 and ZGC",
                 "TLS certificate validation and the public-key infrastructure behind it",
                 "the Linux page cache and dirty-page writeback", "a B-tree index in a relational database"]),
    "json": ("Produce a JSON array of 25 objects describing {}. Each object has: name, category, year "
             "(integer), description (one sentence), tags (array of 3 strings) and score (0-10). Output only "
             "the JSON.",
             ["fictional open-source projects", "fictional board games", "fictional coffee shops",
              "fictional spacecraft", "fictional programming languages", "fictional mountain trails"]),
    "story": ("Write a 900-word short story about {}.",
              ["a lighthouse keeper who finds a message in a bottle in her own handwriting",
               "a clockmaker whose clocks start running backwards",
               "two rival chess players snowed in at a train station",
               "a botanist who finds a plant that remembers voices",
               "a retired astronaut who hears a signal from her old capsule",
               "a translator hired for a language nobody has heard"]),
    "nix": ("Write a NixOS module that {}, with typed options, mkEnableOption, a dedicated user, a "
            "StateDirectory and systemd hardening. Then explain each hardening setting you used.",
            ["runs a small Python web service", "runs a nightly restic backup on a timer",
             "runs a Prometheus exporter for a custom metric script", "runs a Minecraft server with world backups",
             "serves a static site with Caddy", "runs a Redis instance on a Unix socket"]),
    "refactor": ("Here is a plan: {}. Write the step-by-step refactor plan, then write the first new module "
                 "in full, with tests.",
                 ["split a 600-line Go HTTP handler file into routing, validation, persistence and rendering",
                  "replace a Python script's global state with a dependency-injected service class",
                  "turn a callback-based Node.js file walker into async iterators",
                  "move a Rust CLI's argument parsing to clap derive subcommands",
                  "extract a C++ parser's tokenizer into its own class",
                  "turn a Bash deployment script into a Python tool with retries and logging"]),
}


def decode_prompt(kind, subject_index):
    template, subjects = DECODE_PROMPTS[kind]
    return template.format(subjects[subject_index % len(subjects)])

KL_PROMPTS = [
    "The capital of Australia is",
    "In Rust, the borrow checker prevents",
    "def fibonacci(n):\n    \"\"\"Return the n-th Fibonacci number.\"\"\"\n",
    "The main difference between TCP and UDP is",
    "SELECT name, COUNT(*) FROM orders",
    "Photosynthesis converts",
    "A good commit message should",
    "The 7950X3D has two CCDs, and",
]


def http(url, body=None, timeout=1800):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


def engine_pid():
    # The engine names its main thread strata-host, so match its command line.
    r = subprocess.run(["pgrep", "-u", "strata", "-f", "/components/engine/.*/strata --serve"],
                       capture_output=True, text=True)
    pids = r.stdout.split()
    return pids[0] if pids else None


def evicted_ms(pid):
    if pid is None:
        return None
    for p in pathlib.Path(f"/sys/class/kfd/kfd/proc/{pid}").glob("stats_*/evicted_ms"):
        try:
            return int(p.read_text().strip())
        except (OSError, ValueError):
            return None
    return None


def newest_since(base, t0):
    """GET /metrics lists the last 12 requests newest first; the newest one started after t0 is ours."""
    reqs = http(base + "/metrics").get("requests") or []
    rec = reqs[0] if reqs else {}
    return rec if (rec.get("time") or 0) >= t0 - 1 else {}


def chat(base, model, content, max_tokens, tune, thinking, logprobs=False):
    body = {
        "model": model,
        "messages": [{"role": "user", "content": content}],
        "max_tokens": max_tokens,
        "temperature": 0,
        "top_k": 1,
        "seed": 42,
        "stream": False,
        "chat_template_kwargs": {"enable_thinking": thinking},
    }
    if tune:
        body["strata_tune"] = tune
    if logprobs:
        body["logprobs"] = True
        body["top_logprobs"] = 20
    return http(base + "/v1/chat/completions", body)


def corpus_text(paths, chars):
    out, n = [], 0
    for p in paths:
        for f in sorted(pathlib.Path(p).rglob("*.py")):
            t = f.read_text(errors="replace")
            out.append(f"# file: {f.name}\n{t}")
            n += len(t)
            if n >= chars:
                return "".join(out)[:chars]
    return "".join(out)[:chars]


def run_one(base, model, kind, content, max_tokens, tune, thinking, pid):
    e0 = evicted_ms(pid)
    t0 = time.time()
    resp = chat(base, model, content, max_tokens, tune, thinking)
    wall = time.time() - t0
    e1 = evicted_ms(pid)
    rec = newest_since(base, t0)
    usage = resp.get("usage") or {}
    return {
        "kind": kind,
        "tune": tune or {},
        "wall_s": round(wall, 2),
        "completion_tokens": usage.get("completion_tokens"),
        "prompt_tokens": usage.get("prompt_tokens"),
        "decode_tok_s": rec.get("decode_tok_s"),
        "prompt_ms": rec.get("prompt_ms"),
        "prompt_read": rec.get("prompt_read"),
        "reused": rec.get("reused"),
        "hit_rate": rec.get("hit_rate"),
        "pcie_share": rec.get("pcie_share"),
        "drafts_offered": rec.get("drafts_offered"),
        "drafts_accepted": rec.get("drafts_accepted"),
        "evicted_ms_delta": None if e0 is None or e1 is None else e1 - e0,
        "text_head": ((resp.get("choices") or [{}])[0].get("message") or {}).get("content", "")[:80],
    }


def memory_snapshot(pid):
    """GiB: the engine's resident and locked memory, the service cgroup's peak, and what the host has left."""
    def gib(kib):
        return round(kib / 2**20, 1)
    out = {}
    try:
        for line in pathlib.Path(f"/proc/{pid}/status").read_text().splitlines():
            key, _, val = line.partition(":")
            if key in ("VmRSS", "VmLck", "RssAnon", "RssFile"):
                out[key] = gib(int(val.split()[0]))
        cg = pathlib.Path("/sys/fs/cgroup") / pathlib.Path(f"/proc/{pid}/cgroup").read_text().split("::", 1)[1].strip().lstrip("/")
        out["cgroup_peak"] = gib(int((cg / "memory.peak").read_text()) // 1024)
        for line in pathlib.Path("/proc/meminfo").read_text().splitlines():
            if line.startswith("MemAvailable:"):
                out["MemAvailable"] = gib(int(line.split()[1]))
    except (OSError, ValueError, IndexError, TypeError):
        pass
    return out


def first_token_dists(base, model, corpus):
    """First-token top-20 logprobs: the short prompts, then four ~4K-token prompts that the prompt path
    reads in batches (the matrix-core prompt switches only act on those). Identical text in every arm."""
    probes = list(KL_PROMPTS)
    if corpus:
        text = corpus_text(corpus, 4 * 13500)
        probes += [text[i * 13500:(i + 1) * 13500] + "\n\nSummarise the code above in one sentence." for i in range(4)]
    dists = []
    for p in probes:
        resp = chat(base, model, p, 1, None, False, logprobs=True)
        lp = (((resp.get("choices") or [{}])[0].get("logprobs") or {}).get("content") or [{}])[0]
        dists.append({a["token"]: a["logprob"] for a in lp.get("top_logprobs", [])})
    return dists


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="http://127.0.0.1:8081")
    ap.add_argument("--label", required=True)
    ap.add_argument("--out", required=True, help="directory for <label>.json")
    ap.add_argument("--rounds", type=int, default=3,
                    help="rounds of every kind; with N per-request arms, N rounds rotate each through N subjects")
    ap.add_argument("--kinds", default="", help="comma list of prompt kinds (default: all)")
    ap.add_argument("--max-tokens", type=int, default=512)
    ap.add_argument("--thinking", action="store_true", help="leave the model's thinking on")
    ap.add_argument("--tune", action="append", default=[],
                    help='per-request arm as JSON, e.g. \'{"pcie_frac": 0.2}\'; repeatable. "{}" is the default arm')
    ap.add_argument("--prefill", default="16000,64000", help="fresh prompt sizes in tokens, comma list, '' for none")
    ap.add_argument("--long-tokens", type=int, default=256, help="answer length after each fresh long prompt")
    ap.add_argument("--corpus", action="append", default=[], help="directory of .py files for long prompts")
    args = ap.parse_args()

    base = args.url.rstrip("/")
    model = http(base + "/v1/models")["data"][0]["id"]
    pid = engine_pid()
    arms = [json.loads(t) for t in args.tune] or [{}]
    rnd = random.Random(1234)
    results = {"label": args.label, "model": model, "engine_pid": pid, "decode": [], "prefill": [], "kl": None,
               "evicted_ms_at_start": evicted_ms(pid)}
    print(f"{args.label}: engine {pid}, GPU queues evicted {results['evicted_ms_at_start']} ms since start", flush=True)

    # Warm-up: the first request after a start pays one-time costs.
    run_one(base, model, "warmup", "Say hello in five words.", 32, None, args.thinking, pid)

    kinds = [k for k in args.kinds.split(",") if k] if args.kinds else list(DECODE_PROMPTS)
    for r in range(args.rounds):
        for kind in kinds:
            order = list(enumerate(arms))
            rnd.shuffle(order)
            for ti, tune in order:
                subject = r + ti
                rec = run_one(base, model, kind, decode_prompt(kind, subject), args.max_tokens, tune or None,
                              args.thinking, pid)
                rec["round"] = r
                rec["subject"] = subject % len(DECODE_PROMPTS[kind][1])
                results["decode"].append(rec)
                print(f"{args.label} r{r} {kind:8s} {json.dumps(tune):24s} "
                      f"{rec['decode_tok_s']} tok/s  {rec['completion_tokens']} tok  hit {rec['hit_rate']}  "
                      f"pcie {rec['pcie_share']}  evict+{rec['evicted_ms_delta']} ms", flush=True)

    sizes = [int(s) for s in args.prefill.split(",") if s.strip()]
    if sizes and args.corpus:
        for n in sizes:
            text = corpus_text(args.corpus, int(n * 3.3))
            # The answer after a long prompt is decode at long context, right after the prompt path
            # borrowed expert-cache slots: the case larger prompt chunks can slow down.
            content = (f"[fresh {args.label} {time.time_ns()}]\nExplain what this code does, file by file, "
                       f"in detail.\n\n{text}")
            rec = run_one(base, model, f"prefill{n}", content, args.long_tokens, None, False, pid)
            rec["tok_s"] = (round(rec["prompt_read"] / (rec["prompt_ms"] / 1000), 1)
                            if rec.get("prompt_read") and rec.get("prompt_ms") else None)
            results["prefill"].append(rec)
            print(f"{args.label} prefill {rec['prompt_read']} tok in {rec['prompt_ms']} ms -> {rec['tok_s']} tok/s, "
                  f"then {rec['completion_tokens']} tok at {rec['decode_tok_s']} tok/s  "
                  f"evict+{rec['evicted_ms_delta']} ms", flush=True)

    results["kl"] = first_token_dists(base, model, args.corpus)
    results["memory_gib"] = memory_snapshot(pid)
    print(f"{args.label}: memory GiB {json.dumps(results['memory_gib'])}", flush=True)

    for tune in arms:
        rates = [d["decode_tok_s"] for d in results["decode"] if d["tune"] == tune and d["decode_tok_s"]]
        acc = [d["drafts_accepted"] / d["drafts_offered"] for d in results["decode"]
               if d["tune"] == tune and d.get("drafts_offered")]
        if rates:
            print(f"SUMMARY {args.label} {json.dumps(tune)}: median {statistics.median(rates):.1f} tok/s "
                  f"(min {min(rates):.1f}, max {max(rates):.1f}, n={len(rates)})"
                  + (f", draft acceptance {statistics.median(acc):.2f}" if acc else ""))

    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    (out / f"{args.label}.json").write_text(json.dumps(results, indent=1))


if __name__ == "__main__":
    sys.exit(main())
