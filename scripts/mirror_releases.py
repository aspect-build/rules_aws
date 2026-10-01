#!/usr/bin/env python3
"""Mirror AWS CLI releases into aws/private/versions.bzl.

AWS doesn't publish checksums for the CLI installers, so this downloads each
platform's installer from awscli.amazonaws.com and computes its sha384 SRI hash.
New entries are inserted at the top of TOOL_VERSIONS; existing ones are left alone.

Usage:
    scripts/mirror_releases.py              # mirror the latest 2.x release from aws/aws-cli tags
    scripts/mirror_releases.py 2.37.7 ...   # mirror specific versions

Set GITHUB_TOKEN to avoid GitHub API rate limits.
"""

import base64
import hashlib
import json
import os
import re
import sys
import urllib.request

VERSIONS_BZL = os.path.join(os.path.dirname(__file__), "..", "aws", "private", "versions.bzl")
DOWNLOAD_HOST = "https://awscli.amazonaws.com"
FILENAMES = {
    "linux-aarch64": "awscli-exe-linux-aarch64-{}.zip",
    "linux-x86_64": "awscli-exe-linux-x86_64-{}.zip",
    "darwin": "AWSCLIV2-{}.pkg",
    "win32": "AWSCLIV2-{}.msi",
}
VERSION_RE = re.compile(r"^2\.\d+\.\d+$")


def latest_release():
    req = urllib.request.Request("https://api.github.com/repos/aws/aws-cli/tags?per_page=100")
    req.add_header("Accept", "application/vnd.github+json")
    if os.environ.get("GITHUB_TOKEN"):
        req.add_header("Authorization", "Bearer " + os.environ["GITHUB_TOKEN"])
    with urllib.request.urlopen(req) as resp:
        tags = [t["name"] for t in json.load(resp) if VERSION_RE.match(t["name"])]
    return max(tags, key=lambda v: tuple(int(p) for p in v.split(".")))


def integrity(url):
    sha = hashlib.sha384()
    with urllib.request.urlopen(url) as resp:
        for chunk in iter(lambda: resp.read(1 << 20), b""):
            sha.update(chunk)
    return "sha384-" + base64.b64encode(sha.digest()).decode()


def entry(version):
    lines = ['    "{}": {{'.format(version)]
    for platform, filename in FILENAMES.items():
        url = "/".join([DOWNLOAD_HOST, filename.format(version)])
        print("Hashing " + url, file=sys.stderr)
        lines.append('        "{}": ("{}", "{}"),'.format(platform, filename, integrity(url)))
    lines.append("    },")
    return "\n".join(lines) + "\n"


def main(versions):
    with open(VERSIONS_BZL) as f:
        content = f.read()
    known = set(re.findall(r'^    "([\d.]+)": \{', content, re.MULTILINE))
    new = [v for v in (versions or [latest_release()]) if v not in known]
    if not new:
        print("Nothing to mirror", file=sys.stderr)
        return

    marker = "TOOL_VERSIONS = {\n"
    new.sort(key=lambda v: tuple(int(p) for p in v.split(".")), reverse=True)
    content = content.replace(marker, marker + "".join(entry(v) for v in new), 1)
    with open(VERSIONS_BZL, "w") as f:
        f.write(content)
    print("Mirrored " + ", ".join(new), file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1:])
