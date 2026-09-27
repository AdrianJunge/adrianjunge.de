#!/usr/bin/env python3
"""Run image checks whenever the change range cannot safely exclude them."""

import os
import re
import subprocess


IMAGE_PREFIXES = (b"scripts/images/", b"content/images/", b"app/assets/images/", b".github/workflows/")
IMAGE_FILES = {
    b".node-version",
    b"config/image_variants.json",
    b"package.json",
    b"package-lock.json",
    b"scripts/ci_image_changes.py",
}


def images_changed(base: str, head: str) -> bool:
    # A new branch or missing pre-force-push history requires the full check.
    if any(not re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", sha) or set(sha) == {"0"}
           for sha in (base, head)):
        return True
    try:
        diff = subprocess.run(
            ["git", "diff", "--no-ext-diff", "--no-textconv", "--no-renames", "--name-only", "-z", base, head, "--"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30, check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return True
    if diff.returncode != 0:
        return True
    return any(path.startswith(IMAGE_PREFIXES) or path in IMAGE_FILES for path in diff.stdout.split(b"\0"))


if __name__ == "__main__":
    changed = images_changed(os.environ.get("DIFF_BASE", ""), os.environ.get("DIFF_HEAD", ""))
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
        output.write(f"images={str(changed).lower()}\n")
