#!/usr/bin/env python3
"""Extract sparkle:edSignature from `sign_update` stdout (one line)."""
from __future__ import annotations

import re
import sys


def main() -> None:
    text = sys.stdin.read()
    sig_m = re.search(r'sparkle:edSignature="([^"]+)"', text)
    if not sig_m:
        print("parse_sign_update: could not find sparkle:edSignature", file=sys.stderr)
        sys.exit(1)
    print(sig_m.group(1), end="")


if __name__ == "__main__":
    main()
