#!/usr/bin/env python3
"""Bump MARKETING_VERSION (semver) and increment CURRENT_PROJECT_VERSION in App/project.yml."""
from __future__ import annotations

import argparse
import re
from pathlib import Path


def parse_semver(s: str) -> tuple[int, int, int]:
    parts = s.strip().split(".")
    if len(parts) != 3:
        raise SystemExit(f"Expected X.Y.Z, got: {s!r}")
    return int(parts[0]), int(parts[1]), int(parts[2])


def bump_semver(v: str, part: str) -> str:
    major, minor, patch = parse_semver(v)
    if part == "major":
        return f"{major + 1}.0.0"
    if part == "minor":
        return f"{major}.{minor + 1}.0"
    if part == "patch":
        return f"{major}.{minor}.{patch + 1}"
    raise SystemExit(f"Unknown bump part: {part}")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "part",
        choices=("major", "minor", "patch"),
        nargs="?",
        default="patch",
        help="Which semver segment to bump (default: patch)",
    )
    p.add_argument(
        "--set-version",
        metavar="X.Y.Z",
        help="Set exact MARKETING_VERSION instead of bumping",
    )
    p.add_argument(
        "--file",
        type=Path,
        default=Path("App/project.yml"),
        help="Path to XcodeGen project.yml",
    )
    args = p.parse_args()
    path = args.file
    text = path.read_text(encoding="utf-8")

    m_ver = re.search(r'^(\s*MARKETING_VERSION:\s*")([^"]+)(")', text, re.MULTILINE)
    m_build = re.search(r'^(\s*CURRENT_PROJECT_VERSION:\s*")(\d+)(")', text, re.MULTILINE)
    if not m_ver or not m_build:
        raise SystemExit(f"Could not find MARKETING_VERSION / CURRENT_PROJECT_VERSION in {path}")

    current = m_ver.group(2)
    if args.set_version:
        new_ver = args.set_version.strip()
        parse_semver(new_ver)
    else:
        new_ver = bump_semver(current, args.part)

    new_build = str(int(m_build.group(2)) + 1)

    text = re.sub(
        r'^(\s*MARKETING_VERSION:\s*")([^"]+)(")',
        rf"\g<1>{new_ver}\g<3>",
        text,
        count=1,
        flags=re.MULTILINE,
    )
    text = re.sub(
        r'^(\s*CURRENT_PROJECT_VERSION:\s*")(\d+)(")',
        rf"\g<1>{new_build}\g<3>",
        text,
        count=1,
        flags=re.MULTILINE,
    )
    path.write_text(text, encoding="utf-8")
    print(new_ver)
    print(new_build)


if __name__ == "__main__":
    main()
