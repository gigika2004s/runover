from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", *args])


def main() -> int:
    root = Path(git("rev-parse", "--show-toplevel").decode().strip())
    staged = git("diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z")
    paths = [Path(item.decode()) for item in staged.split(b"\0") if item]
    if not paths:
        return 0

    key_properties = root / "app" / "android" / "key.properties"
    signing_values: list[bytes] = []
    if key_properties.is_file():
        for line in key_properties.read_text(encoding="utf-8").splitlines():
            key, separator, value = line.partition("=")
            if separator and key.strip() in {"storePassword", "keyPassword"}:
                value = value.strip()
                if value:
                    signing_values.append(value.encode())

    forbidden_suffixes = {".jks", ".keystore", ".p12", ".pfx"}
    private_key_marker = re.compile(
        rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----", re.IGNORECASE
    )
    blocked: list[tuple[str, str]] = []

    for path in paths:
        name = path.name.lower()
        if name == "key.properties" or path.suffix.lower() in forbidden_suffixes:
            blocked.append((path.as_posix(), "signing file"))
            continue

        staged_content = git("show", f":{path.as_posix()}")
        if private_key_marker.search(staged_content):
            blocked.append((path.as_posix(), "private key material"))
            continue
        if any(value in staged_content for value in signing_values):
            blocked.append((path.as_posix(), "local signing password"))

    if blocked:
        print("Commit blocked: signing secrets must not be staged:", file=sys.stderr)
        for path, reason in blocked:
            print(f"  {path} ({reason})", file=sys.stderr)
        print("Remove the secret from the index; keep it in ignored local files.", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
