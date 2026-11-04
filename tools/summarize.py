#!/usr/bin/env python3
"""Summarize tools/sim.sh output (stdin) into per-class balance numbers."""
import sys, re, collections, statistics
runs = collections.defaultdict(list)
for line in sys.stdin:
    m = re.match(r"(\w+) seed=(\d+) (\w+) floor=(\d+) turn=(\d+) lvl=(\d+) kills=(\d+) cause=(.*?) illegal=(\d+)", line)
    if m:
        runs[m[1]].append(dict(state=m[3], floor=int(m[4]), turn=int(m[5]), lvl=int(m[6]), cause=m[8], illegal=int(m[9])))
for c, rs in runs.items():
    n = len(rs)
    wins = sum(r["state"] == "won" for r in rs)
    dark = sum(r["cause"] == "the dark" for r in rs)
    stuck = sum(r["state"] == "playing" for r in rs)
    floors = collections.Counter(r["floor"] for r in rs)
    causes = collections.Counter(r["cause"] for r in rs if r["state"] == "dead")
    print(f"{c:9} n={n} win={100*wins/n:.1f}% median_floor={statistics.median(r['floor'] for r in rs)} "
          f"median_turns={statistics.median(r['turn'] for r in rs)} dark_deaths={100*dark/n:.1f}% stuck={stuck} illegal={sum(r['illegal'] for r in rs)}")
    print("   death floor:", [floors.get(f, 0) for f in range(1, 11)])
    print("   killers:", ", ".join(f"{k} {v}" for k, v in causes.most_common(6)))
