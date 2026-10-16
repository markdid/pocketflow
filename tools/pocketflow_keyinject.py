#!/usr/bin/env python3
"""Read PocketFlowInject logcat lines from stdin; run input keycombination via adb."""

from __future__ import annotations

import re
import subprocess
import sys

pat = re.compile(r"keycombination\s+([0-9]+(?:\s+[0-9]+)+)")


def main() -> None:
    if len(sys.argv) != 3:
        print("usage: pocketflow_keyinject.py <adb> <serial>", file=sys.stderr)
        sys.exit(2)
    adb, dev = sys.argv[1], sys.argv[2]
    print("ready", flush=True)
    for line in sys.stdin:
        m = pat.search(line)
        if not m:
            continue
        codes = m.group(1).split()
        cmd = [adb, "-s", dev, "shell", "input", "keycombination", *codes]
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=2)
            if r.returncode == 0:
                print(f"ok {' '.join(codes)}", flush=True)
            else:
                err = (r.stderr or r.stdout or "").strip()
                print(f"fail {' '.join(codes)}: {err}", flush=True)
        except Exception as e:
            print(f"fail {' '.join(codes)}: {e}", flush=True)


if __name__ == "__main__":
    main()
