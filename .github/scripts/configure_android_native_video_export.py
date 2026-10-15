#!/usr/bin/env python3
"""Install the tiny Android MediaCodec exporter into Flutter's generated Android host.

The project intentionally doesn't commit generated android/ platform files. This
script restores the tracked MainActivity source before every Android build.
"""
from pathlib import Path

source = Path(".github/android/MainActivity.kt")
if not source.is_file():
    raise SystemExit(f"Native Android exporter source missing: {source}")

android = Path("android/app/src/main")
android.mkdir(parents=True, exist_ok=True)
existing = list(android.rglob("MainActivity.kt"))
destination = next(
    (path for path in existing if "com/nexauren/animpro" in path.as_posix()),
    android / "kotlin/com/nexauren/animpro/MainActivity.kt",
)
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(source.read_text(encoding="utf-8"), encoding="utf-8")

# A duplicate activity would make Android compilation ambiguous.
for path in existing:
    if path != destination:
        path.unlink()

print(f"Installed MediaCodec exporter into {destination}")
