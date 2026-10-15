#!/usr/bin/env python3
"""Prepare the permanent Android release key and configure Gradle signing.

This script reads the four values from GitHub Actions Secrets. It never prints
secret values or writes them into tracked source files.
"""
from __future__ import annotations

import base64
import binascii
import os
import re
import subprocess
import sys
from pathlib import Path

PACKAGE_ID = "com.nexauren.animpro"


def fail(message: str) -> None:
    print(f"Android signing setup failed: {message}", file=sys.stderr)
    raise SystemExit(1)


values = {
    "ANDROID_KEYSTORE_BASE64": os.environ.get("ANDROID_KEYSTORE_BASE64", ""),
    "ANDROID_KEYSTORE_PASSWORD": os.environ.get("ANDROID_KEYSTORE_PASSWORD", ""),
    "ANDROID_KEY_ALIAS": os.environ.get("ANDROID_KEY_ALIAS", ""),
    "ANDROID_KEY_PASSWORD": os.environ.get("ANDROID_KEY_PASSWORD", ""),
}
missing = [name for name, value in values.items() if not value]
if missing:
    fail("missing required GitHub Actions secret(s): " + ", ".join(missing))

try:
    key_bytes = base64.b64decode(values["ANDROID_KEYSTORE_BASE64"], validate=True)
except (binascii.Error, ValueError):
    fail("ANDROID_KEYSTORE_BASE64 is not valid single-line Base64")

if len(key_bytes) < 1000:
    fail("decoded keystore is unexpectedly small; verify ANDROID_KEYSTORE_BASE64")

runner_temp = Path(os.environ.get("RUNNER_TEMP", "/tmp"))
runner_temp.mkdir(parents=True, exist_ok=True)
keystore_path = runner_temp / "animations2d-release.jks"
keystore_path.write_bytes(key_bytes)
keystore_path.chmod(0o600)

try:
    subprocess.run(
        [
            "keytool", "-list", "-keystore", str(keystore_path),
            "-storetype", "JKS", "-storepass", values["ANDROID_KEYSTORE_PASSWORD"],
            "-alias", values["ANDROID_KEY_ALIAS"],
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )
except (subprocess.CalledProcessError, FileNotFoundError):
    fail("keystore, password, or alias is invalid; check the four secrets")

properties_path = Path("android/key.properties")
properties_path.parent.mkdir(parents=True, exist_ok=True)
properties_path.write_text(
    f"storePassword={values['ANDROID_KEYSTORE_PASSWORD']}\n"
    f"keyPassword={values['ANDROID_KEY_PASSWORD']}\n"
    f"keyAlias={values['ANDROID_KEY_ALIAS']}\n"
    f"storeFile={keystore_path}\n",
    encoding="utf-8",
)
properties_path.chmod(0o600)

kts = Path("android/app/build.gradle.kts")
groovy = Path("android/app/build.gradle")
if kts.exists():
    gradle_path = kts
    text = gradle_path.read_text(encoding="utf-8")

    for imp in ("import java.util.Properties", "import java.io.FileInputStream"):
        if imp not in text:
            text = imp + "\n" + text

    namespace_pattern = r'(?m)^(\s*namespace\s*=\s*)["\'][^"\']+["\']'
    appid_pattern = r'(?m)^(\s*applicationId\s*=\s*)["\'][^"\']+["\']'
    text, namespace_count = re.subn(namespace_pattern, rf'\g<1>"{PACKAGE_ID}"', text, count=1)
    text, appid_count = re.subn(appid_pattern, rf'\g<1>"{PACKAGE_ID}"', text, count=1)
    if namespace_count != 1 or appid_count != 1:
        fail("could not standardize namespace/applicationId in build.gradle.kts")

    text, sdk_count = re.subn(
        r'(?m)^(\s*minSdk\s*=\s*)(?:flutter\.minSdkVersion|\d+)',
        r'\g<1>24',
        text,
        count=1,
    )
    if sdk_count == 0:
        text, sdk_count = re.subn(
            r'(?m)^(\s*minSdkVersion\s*=\s*)(?:flutter\.minSdkVersion|\d+)',
            r'\g<1>24',
            text,
            count=1,
        )
    if sdk_count == 0:
        fail("could not set Android minSdk to 24 in build.gradle.kts")

    if "keystorePropertiesFile" not in text:
        android_match = re.search(r'(?m)^android\s*\{', text)
        if not android_match:
            fail("could not find android { block in build.gradle.kts")
        loader = (
            'val keystoreProperties = Properties()\n'
            'val keystorePropertiesFile = rootProject.file("key.properties")\n'
            'if (keystorePropertiesFile.exists()) {\n'
            '    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n'
            '}\n\n'
        )
        text = text[:android_match.start()] + loader + text[android_match.start():]

    if 'create("release")' not in text:
        build_types_match = re.search(r'(?m)^(\s*)buildTypes\s*\{', text)
        if not build_types_match:
            fail("could not find buildTypes { block in build.gradle.kts")
        indent = build_types_match.group(1)
        signing_block = (
            f'{indent}signingConfigs {{\n'
            f'{indent}    create("release") {{\n'
            f'{indent}        keyAlias = keystoreProperties["keyAlias"] as String\n'
            f'{indent}        keyPassword = keystoreProperties["keyPassword"] as String\n'
            f'{indent}        storeFile = file(keystoreProperties["storeFile"] as String)\n'
            f'{indent}        storePassword = keystoreProperties["storePassword"] as String\n'
            f'{indent}    }}\n'
            f'{indent}}}\n\n'
        )
        text = text[:build_types_match.start()] + signing_block + text[build_types_match.start():]

    text = text.replace(
        'signingConfig = signingConfigs.getByName("debug")',
        'signingConfig = signingConfigs.getByName("release")',
    )
    build_types_start = text.find("buildTypes")
    release_match = re.search(r'(?m)^(\s*)release\s*\{', text[build_types_start:]) if build_types_start >= 0 else None
    if release_match:
        prefix_end = build_types_start + release_match.end()
        build_types_end = text.find("\n    }", prefix_end)
        release_section = text[prefix_end:build_types_end if build_types_end >= 0 else len(text)]
        if 'signingConfigs.getByName("release")' not in release_section:
            indent = release_match.group(1) + "    "
            text = text[:prefix_end] + f'\n{indent}signingConfig = signingConfigs.getByName("release")' + text[prefix_end:]

elif groovy.exists():
    gradle_path = groovy
    text = gradle_path.read_text(encoding="utf-8")

    for imp in ("import java.util.Properties", "import java.io.FileInputStream"):
        if imp not in text:
            text = imp + "\n" + text

    namespace_pattern = r'(?m)^(\s*namespace\s+)["\'][^"\']+["\']'
    appid_pattern = r'(?m)^(\s*applicationId\s+)["\'][^"\']+["\']'
    text, namespace_count = re.subn(namespace_pattern, rf'\g<1>"{PACKAGE_ID}"', text, count=1)
    text, appid_count = re.subn(appid_pattern, rf'\g<1>"{PACKAGE_ID}"', text, count=1)
    if namespace_count != 1 or appid_count != 1:
        fail("could not standardize namespace/applicationId in build.gradle")

    text, sdk_count = re.subn(
        r'(?m)^(\s*minSdkVersion\s*(?:=|\s)\s*)(?:flutter\.minSdkVersion|\d+)',
        r'\g<1>24',
        text,
        count=1,
    )
    if sdk_count == 0:
        fail("could not set Android minSdkVersion to 24 in build.gradle")

    if "keystorePropertiesFile" not in text:
        android_match = re.search(r'(?m)^android\s*\{', text)
        if not android_match:
            fail("could not find android { block in build.gradle")
        loader = (
            "def keystoreProperties = new Properties()\n"
            "def keystorePropertiesFile = rootProject.file('key.properties')\n"
            "if (keystorePropertiesFile.exists()) {\n"
            "    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n"
            "}\n\n"
        )
        text = text[:android_match.start()] + loader + text[android_match.start():]

    if not re.search(r'(?m)^\s*release\s*\{', text[text.find("buildTypes"):]):
        fail("could not find release build type in build.gradle")

    if not re.search(r'(?m)^\s*signingConfigs\s*\{', text):
        build_types_match = re.search(r'(?m)^(\s*)buildTypes\s*\{', text)
        if not build_types_match:
            fail("could not find buildTypes { block in build.gradle")
        indent = build_types_match.group(1)
        signing_block = (
            f"{indent}signingConfigs {{\n"
            f"{indent}    release {{\n"
            f"{indent}        keyAlias keystoreProperties['keyAlias']\n"
            f"{indent}        keyPassword keystoreProperties['keyPassword']\n"
            f"{indent}        storeFile file(keystoreProperties['storeFile'])\n"
            f"{indent}        storePassword keystoreProperties['storePassword']\n"
            f"{indent}    }}\n"
            f"{indent}}}\n\n"
        )
        text = text[:build_types_match.start()] + signing_block + text[build_types_match.start():]

    text = re.sub(
        r'(?m)^\s*signingConfig\s+signingConfigs\.debug\s*$',
        '            signingConfig signingConfigs.release',
        text,
    )
    if not re.search(r'(?m)^\s*signingConfig\s+signingConfigs\.release\s*$', text):
        build_types_start = text.find("buildTypes")
        release_match = re.search(r'(?m)^(\s*)release\s*\{', text[build_types_start:]) if build_types_start >= 0 else None
        if not release_match:
            fail("could not find release block for signing")
        insert_at = build_types_start + release_match.end()
        text = text[:insert_at] + "\n                signingConfig signingConfigs.release" + text[insert_at:]
else:
    fail("Flutter Android Gradle file not found (expected build.gradle.kts or build.gradle)")

gradle_path.write_text(text, encoding="utf-8")
print(f"Configured permanent release signing for {PACKAGE_ID}. Secret values were not printed.")
