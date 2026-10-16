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

# Replace the default Flutter launcher tile with the AnimPro frame/play logo.
res = Path("android/app/src/main/res")
values = res / "values"
values.mkdir(parents=True, exist_ok=True)
(values / "animpro_icon_colors.xml").write_text(
    """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="animpro_icon_bg">#111426</color>
</resources>
""",
    encoding="utf-8",
)

foreground = """<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:fillColor="#FF5D54E8"
        android:pathData="M28,18 L74,18 Q82,18 82,26 L82,68 Q82,76 74,76 L28,76 Q20,76 20,68 L20,26 Q20,18 28,18 Z" />
    <path android:fillColor="#FF64D8E6"
        android:pathData="M19,31 L62,31 Q68,31 68,37 L68,80 Q68,86 62,86 L19,86 Q13,86 13,80 L13,37 Q13,31 19,31 Z" />
    <path android:fillColor="#FF171A2A"
        android:pathData="M23,41 L58,41 L58,81 L23,81 Z" />
    <path android:fillColor="#FFFFD166"
        android:pathData="M39,48 L39,73 L59,60.5 Z" />
    <path android:fillColor="#FFFFFFFF"
        android:pathData="M66,25 L84,7 L92,15 L74,33 Z" />
    <path android:fillColor="#FF9F8BFF"
        android:pathData="M63,28 L70,35 L63,42 L56,35 Z" />
</vector>
"""
(res / "drawable").mkdir(parents=True, exist_ok=True)
(res / "drawable" / "animpro_icon_foreground.xml").write_text(foreground, encoding="utf-8")

adaptive = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/animpro_icon_bg" />
    <foreground android:drawable="@drawable/animpro_icon_foreground" />
</adaptive-icon>
"""
for folder_name in ("mipmap-anydpi-v26",):
    folder = res / folder_name
    folder.mkdir(parents=True, exist_ok=True)
    for icon_name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        (folder / icon_name).write_text(adaptive, encoding="utf-8")

# A single vector also serves launchers on Android versions without adaptive icons.
legacy_vector = """<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="48dp"
    android:height="48dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:fillColor="#FF111426" android:pathData="M0,0 L108,0 L108,108 L0,108 Z" />
    <path android:fillColor="#FF5D54E8"
        android:pathData="M28,18 L74,18 Q82,18 82,26 L82,68 Q82,76 74,76 L28,76 Q20,76 20,68 L20,26 Q20,18 28,18 Z" />
    <path android:fillColor="#FF64D8E6"
        android:pathData="M19,31 L62,31 Q68,31 68,37 L68,80 Q68,86 62,86 L19,86 Q13,86 13,80 L13,37 Q13,31 19,31 Z" />
    <path android:fillColor="#FF171A2A" android:pathData="M23,41 L58,41 L58,81 L23,81 Z" />
    <path android:fillColor="#FFFFD166" android:pathData="M39,48 L39,73 L59,60.5 Z" />
    <path android:fillColor="#FFFFFFFF" android:pathData="M66,25 L84,7 L92,15 L74,33 Z" />
</vector>
"""
legacy = res / "mipmap-anydpi"
legacy.mkdir(parents=True, exist_ok=True)
for icon_name in ("ic_launcher.xml", "ic_launcher_round.xml"):
    (legacy / icon_name).write_text(legacy_vector, encoding="utf-8")

print("Installed custom AnimPro launcher icons")
