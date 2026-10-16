#!/usr/bin/env python3
"""Fail a release build when its signing certificate is not registered for Google sign-in."""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

PACKAGE_ID = "com.nexauren.animpro"
CONFIG = Path("android/app/google-services.json")
PROPERTIES = Path("android/key.properties")


def fail(message: str) -> None:
    print(f"Google OAuth release check failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    if not CONFIG.exists():
        print("::warning::No Android google-services.json; cannot verify Google OAuth signing fingerprint.")
        return
    if not PROPERTIES.exists():
        fail("Android release key properties are missing.")

    properties = {}
    for line in PROPERTIES.read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            properties[key.strip()] = value.strip()
    store_file = properties.get("storeFile")
    store_password = properties.get("storePassword")
    alias = properties.get("keyAlias")
    if not store_file or not store_password or not alias:
        fail("The release keystore configuration is incomplete.")

    try:
        result = subprocess.run(
            [
                "keytool", "-list", "-v", "-keystore", store_file,
                "-storepass", store_password, "-alias", alias,
            ],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        fail("Could not inspect the release signing certificate.")

    match = re.search(r"SHA1:\s*([0-9A-F:]+)", result.stdout, flags=re.IGNORECASE)
    if not match:
        fail("Could not read the release certificate SHA-1 fingerprint.")
    release_sha1 = re.sub(r"[^0-9A-F]", "", match.group(1).upper())

    try:
        config = json.loads(CONFIG.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        fail(f"google-services.json is invalid: {exc}")

    registered = set()
    for client in config.get("client", []):
        info = client.get("client_info", {})
        android = info.get("android_client_info", {})
        if android.get("package_name") != PACKAGE_ID:
            continue
        for oauth in client.get("oauth_client", []):
            if oauth.get("client_type") != 1:
                continue
            oauth_android = oauth.get("android_info", {})
            if oauth_android.get("package_name") == PACKAGE_ID:
                fingerprint = re.sub(
                    r"[^0-9A-F]",
                    "",
                    str(oauth_android.get("certificate_hash", "")).upper(),
                )
                if fingerprint:
                    registered.add(fingerprint)

    if release_sha1 not in registered:
        fail(
            "The release keystore SHA-1 is not listed for com.nexauren.animpro in "
            "google-services.json. Add this release certificate in Firebase Project "
            "settings > Your apps > SHA certificate fingerprints, then download the "
            "updated google-services.json and commit it. The fingerprint was not printed "
            "to protect the release configuration."
        )
    print("Google OAuth SHA-1 matches the configured AnimPro release certificate.")


if __name__ == "__main__":
    main()
