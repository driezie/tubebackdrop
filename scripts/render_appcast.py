#!/usr/bin/env python3
"""Write a single-item Sparkle appcast for TubeBackdrop."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
from pathlib import Path


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--short-version", required=True)
    p.add_argument("--bundle-version", required=True)
    p.add_argument("--enclosure-url", required=True)
    p.add_argument("--length", type=int, required=True)
    p.add_argument("--signature", required=True)
    p.add_argument("--min-macos", default="13.0")
    p.add_argument("--github-repo", required=True, help="owner/name")
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()

    pub = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")
    link = f"https://github.com/{args.github_repo}/releases"

    xml = f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>TubeBackdrop</title>
    <link>{link}</link>
    <description>Sparkle appcast for TubeBackdrop.</description>
    <language>en</language>
    <item>
      <title>{args.short_version}</title>
      <description><![CDATA[]]></description>
      <pubDate>{pub}</pubDate>
      <sparkle:version>{args.bundle_version}</sparkle:version>
      <sparkle:shortVersionString>{args.short_version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{args.min_macos}</sparkle:minimumSystemVersion>
      <enclosure url="{args.enclosure_url}" length="{args.length}" type="application/octet-stream" sparkle:edSignature="{args.signature}" />
    </item>
  </channel>
</rss>
"""
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(xml, encoding="utf-8")


if __name__ == "__main__":
    main()
