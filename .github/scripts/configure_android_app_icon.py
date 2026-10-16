#!/usr/bin/env python3
"""Install the AnimPro vector launcher icon into the generated Android project."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
ICON = ROOT / "android" / "app" / "src" / "main" / "res" / "drawable" / "ic_animpro_launcher.xml"

VECTOR = """<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:fillColor="#0B0D18" android:pathData="M0,0h108v108h-108z" />
    <path android:fillColor="#6957FF" android:pathData="M54,8 C79.4,8 100,28.6 100,54 C100,79.4 79.4,100 54,100 C28.6,100 8,79.4 8,54 C8,28.6 28.6,8 54,8 Z" />
    <path
        android:fillColor="#00000000"
        android:strokeColor="#FFFFFFFF"
        android:strokeWidth="7"
        android:strokeLineCap="round"
        android:strokeLineJoin="round"
        android:pathData="M30,76 L54,27 L78,76 M40,57 L68,57" />
    <path android:fillColor="#52E0E8" android:pathData="M55,64 L72,75 L55,86 Z" />
</vector>
"""

def main() -> None:
    if not MANIFEST.exists():
        raise SystemExit(f"Android manifest not found: {MANIFEST}")
    manifest = MANIFEST.read_text(encoding="utf-8")
    match = re.search(r"<application\b[^>]*>", manifest, flags=re.DOTALL)
    if not match:
        raise SystemExit("Could not find the Android application element.")
    tag = match.group(0)
    if re.search(r'android:icon="[^"]+"', tag):
        tag = re.sub(r'android:icon="[^"]+"', 'android:icon="@drawable/ic_animpro_launcher"', tag, count=1)
    else:
        tag = tag[:-1] + ' android:icon="@drawable/ic_animpro_launcher">'
    manifest = manifest[:match.start()] + tag + manifest[match.end():]
    MANIFEST.write_text(manifest, encoding="utf-8")
    ICON.parent.mkdir(parents=True, exist_ok=True)
    ICON.write_text(VECTOR, encoding="utf-8")
    print("Installed AnimPro launcher icon.")
    
if __name__ == "__main__":
    main()
