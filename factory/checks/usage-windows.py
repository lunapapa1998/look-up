import json
import sys
from datetime import datetime
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
USAGE_LOG = ROOT / "factory/logs/usage-ledger.jsonl"
RUN_LOG = ROOT / "factory/logs/run-ledger.jsonl"


def bucket_key(ts: str) -> int:
    dt = datetime.strptime(ts, "%Y%m%d-%H%M%S")
    epoch = int(dt.timestamp())
    return epoch // 18000


def window_label(key: int) -> str:
    return datetime.fromtimestamp(key * 18000).strftime("%Y-%m-%d %H:%M")


def load_usage(path: Path) -> tuple[dict, dict]:
    adapter_by_window = defaultdict(lambda: defaultdict(int))
    rotations_by_window = defaultdict(int)
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            rec = json.loads(line)
            key = bucket_key(rec["ts"])
            adapter_by_window[key][rec["adapter"]] += 1
            rotated_from = rec.get("rotatedFrom")
            if isinstance(rotated_from, list) and rotated_from:
                rotations_by_window[key] += len(rotated_from)
        except Exception:
            pass
    return adapter_by_window, rotations_by_window


def load_runs(path: Path) -> dict:
    runs_by_window = defaultdict(lambda: {"total": 0, "pass": 0})
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            rec = json.loads(line)
            key = bucket_key(rec["ts"])
            runs_by_window[key]["total"] += 1
            if rec.get("ok") is True:
                runs_by_window[key]["pass"] += 1
        except Exception:
            pass
    return runs_by_window


def main():
    if not USAGE_LOG.exists():
        print(f"[info] usage-ledger.jsonl not found: {USAGE_LOG}")
        sys.exit(0)
    if not RUN_LOG.exists():
        print(f"[info] run-ledger.jsonl not found: {RUN_LOG}")
        sys.exit(0)

    usage, rotations = load_usage(USAGE_LOG)
    runs = load_runs(RUN_LOG)

    all_keys = sorted(set(usage) | set(runs) | set(rotations))

    total_calls = 0
    total_runs = 0
    total_pass = 0
    total_rotations = 0

    for key in all_keys:
        label = window_label(key)
        adapters = usage.get(key, {})
        run_stat = runs.get(key, {"total": 0, "pass": 0})

        window_calls = sum(adapters.values())
        total_calls += window_calls
        total_runs += run_stat["total"]
        total_pass += run_stat["pass"]
        window_rotations = rotations.get(key, 0)
        total_rotations += window_rotations

        adapter_str = ", ".join(f"{a}={c}" for a, c in sorted(adapters.items()))
        rotation_str = f" | rotations {window_rotations}" if window_rotations else ""
        print(
            f"[{label}] calls {window_calls} ({adapter_str})"
            f" | runs {run_stat['total']} PASS {run_stat['pass']}"
            f"{rotation_str}"
        )

    n = len(all_keys)
    print(
        f"OK: windows {n}, calls {total_calls}, runs {total_runs} "
        f"(PASS {total_pass}), rotations {total_rotations}"
    )
    sys.exit(0)


if __name__ == "__main__":
    main()
