#!/usr/bin/env python3
"""Global window economics report for shared subscription windows across projects.

Reads ~/.factory/{usage,run}-ledger.jsonl, where each record includes a project field,
and reports calls/runs/PASS/rotations by 5-hour window and project.
Use each repo's `just usage-windows` for the per-project view; this report is for
account-level budget visibility.

Usage: usage-global.py [--global-dir DIR]
Default directory: ~/.factory, overridable with FACTORY_GLOBAL_DIR.
"""

import json
import os
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

WINDOW_SEC = 18000  # 5-hour subscription window


def bucket(ts: str) -> int:
    return int(datetime.strptime(ts, "%Y%m%d-%H%M%S").timestamp()) // WINDOW_SEC


def label(key: int) -> str:
    return datetime.fromtimestamp(key * WINDOW_SEC).strftime("%Y-%m-%d %H:%M")


def load(path: Path):
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            yield json.loads(line)
        except Exception:
            pass


def main() -> int:
    global_dir = Path(os.environ.get("FACTORY_GLOBAL_DIR", Path.home() / ".factory"))
    if "--global-dir" in sys.argv:
        global_dir = Path(sys.argv[sys.argv.index("--global-dir") + 1])

    usage_path = global_dir / "usage-ledger.jsonl"
    run_path = global_dir / "run-ledger.jsonl"
    if not usage_path.exists() and not run_path.exists():
        print(f"[info] global ledger not found: {global_dir} - no project has written records yet")
        return 0

    # window -> project -> aggregate
    calls = defaultdict(lambda: defaultdict(lambda: {"calls": 0, "fail": 0, "rot": 0}))
    runs = defaultdict(lambda: defaultdict(lambda: {"total": 0, "ok": 0}))

    for rec in load(usage_path):
        w = bucket(rec["ts"])
        p = rec.get("project", "?")
        calls[w][p]["calls"] += 1
        if rec.get("ok") is not True:
            calls[w][p]["fail"] += 1
        calls[w][p]["rot"] += len(rec.get("rotatedFrom") or [])

    for rec in load(run_path):
        w = bucket(rec["ts"])
        p = rec.get("project", "?")
        runs[w][p]["total"] += 1
        if rec.get("ok") is True:
            runs[w][p]["ok"] += 1

    total_calls = total_runs = total_pass = total_rot = 0
    for w in sorted(set(calls) | set(runs)):
        projects = sorted(set(calls.get(w, {})) | set(runs.get(w, {})))
        print(f"[{label(w)}] window")
        for p in projects:
            c = calls.get(w, {}).get(p, {"calls": 0, "fail": 0, "rot": 0})
            r = runs.get(w, {}).get(p, {"total": 0, "ok": 0})
            extra = ""
            if c["fail"]:
                extra += f" failures {c['fail']}"
            if c["rot"]:
                extra += f" rotations {c['rot']}"
            print(f"  {p}: calls {c['calls']}{extra} | runs {r['total']} PASS {r['ok']}")
            total_calls += c["calls"]
            total_runs += r["total"]
            total_pass += r["ok"]
            total_rot += c["rot"]

    print(
        f"OK: global calls {total_calls}, runs {total_runs} (PASS {total_pass}), "
        f"rotations {total_rot} - {global_dir}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
