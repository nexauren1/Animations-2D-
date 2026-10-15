#!/usr/bin/env python3
"""Wire an optional root google-services.json into the generated Flutter Android project.

This repository generates its android/ directory in GitHub Actions. To avoid
committing generated platform files, keep google-services.json at repository root.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import sys
from pathlib import Path

PACKAGE_ID = "com.nexauren.animpro"
source = Path("google-services.json")
env_file = os.environ.get("GITHUB_ENV")


def set_native_config(value: bool) -> None:
    if env_file:
        with open(env_file, "a", encoding="utf-8") as stream:
            stream.write(f"FIREBASE_NATIVE_CONFIG={'true' if value else 'false'}\n")


if not source.exists():
    set_native_config(False)
    print("No root google-services.json found; using Firebase Dart defines if configured.")
    raise SystemExit(0)

try:
    data = json.loads(source.read_text(encoding="utf-8"))
except (json.JSONDecodeError, UnicodeDecodeError) as exc:
    raise SystemExit(f"google-services.json is invalid JSON: {exc}")

clients = data.get("client", [])
matching = [
    item for item in clients
    if item.get("client_info", {}).get("android_client_info", {}).get("package_name") == PACKAGE_ID
]
if not matching:
    raise SystemExit(
        f"google-services.json has no Android client for {PACKAGE_ID}. "
        "Register that exact package in Firebase and download the matching file."
    )

app_dir = Path("android/app")
app_dir.mkdir(parents=True, exist_ok=True)
shutil.copyfile(source, app_dir / "google-services.json")

settings_path = Path("android/settings.gradle.kts")
settings_groovy = Path("android/settings.gradle")
app_kts = app_dir / "build.gradle.kts"
app_groovy = app_dir / "build.gradle"

if settings_path.exists() and app_kts.exists():
    settings = settings_path.read_text(encoding="utf-8")
    if "com.google.gms.google-services" not in settings:
        match = re.search(r"(?m)^plugins\s*\{", settings)
        if not match:
            raise SystemExit("Cannot configure Google Services: plugins block missing in settings.gradle.kts")
        settings = settings[:match.end()] + '\n    id("com.google.gms.google-services") version "4.4.4" apply false' + settings[match.end():]
        settings_path.write_text(settings, encoding="utf-8")

    app_gradle = app_kts.read_text(encoding="utf-8")
    if "com.google.gms.google-services" not in app_gradle:
        match = re.search(r"(?m)^plugins\s*\{", app_gradle)
        if not match:
            raise SystemExit("Cannot configure Google Services: plugins block missing in app/build.gradle.kts")
        app_gradle = app_gradle[:match.end()] + '\n    id("com.google.gms.google-services")' + app_gradle[match.end():]
        app_kts.write_text(app_gradle, encoding="utf-8")
elif settings_groovy.exists() and app_groovy.exists():
    settings = settings_groovy.read_text(encoding="utf-8")
    if "com.google.gms.google-services" not in settings:
        match = re.search(r"(?m)^plugins\s*\{", settings)
        if not match:
            raise SystemExit("Cannot configure Google Services: plugins block missing in settings.gradle")
        settings = settings[:match.end()] + "\n    id 'com.google.gms.google-services' version '4.4.4' apply false" + settings[match.end():]
        settings_groovy.write_text(settings, encoding="utf-8")

    app_gradle = app_groovy.read_text(encoding="utf-8")
    if "com.google.gms.google-services" not in app_gradle:
        match = re.search(r"(?m)^plugins\s*\{", app_gradle)
        if not match:
            raise SystemExit("Cannot configure Google Services: plugins block missing in app/build.gradle")
        app_gradle = app_gradle[:match.end()] + "\n    id 'com.google.gms.google-services'" + app_gradle[match.end():]
        app_groovy.write_text(app_gradle, encoding="utf-8")
else:
    raise SystemExit("Generated Android Gradle files were not found.")

set_native_config(True)
print(f"Installed google-services.json for {PACKAGE_ID} and enabled the Google Services Gradle plugin.")
