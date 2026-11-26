# AnimPro — Online sound library

The starter collection is generated from original procedural sound designs by `.github/scripts/generate_resource_library.py`. The generated WAV assets and public manifest are written to `docs/audio/` during the GitHub Pages build, so audio is not bundled into the Android APK.

This folder contains maintainer notes and a mirrored catalogue source. The public catalogue and sounds are generated under `docs/audio/`; the Android app reads `https://nexauren1.github.io/Animations-2D-/audio/catalog.json`. Publishing a new sound and updating the catalogue does not require a new APK.

## Where to find sound effects

Use these sources to discover sounds. They are not all suitable for a downloadable in-app library; the rules below distinguish project-use sources from redistributable sources:

- **Freesound** — https://freesound.org/ — prefer CC0 or CC BY assets. Do not use CC BY-NC in AnimPro's distributable library because AnimPro is a commercial product. Freesound's FAQ explains the per-sound licences and attribution requirements: https://freesound.org/help/faq/
- **Pixabay Sound Effects** — https://pixabay.com/sound-effects/ — useful for sounds that users incorporate into finished animations. The current Pixabay terms prohibit distributing the unmodified asset on a standalone basis, so do **not** copy its raw audio file into this downloadable catalogue: https://pixabay.com/service/terms/.
- **Mixkit Sound Effects** — https://mixkit.co/free-sound-effects/ — the Free SFX licence permits use in finished projects, including video games, but explicitly prohibits redistributing the sound by itself or inside a tool/template. Do **not** put raw Mixkit files in this downloadable catalogue: https://mixkit.co/license/modal/sfxFree/.
- **OpenGameArt** — https://opengameart.org/ — licences vary by asset; check whether the exact licence permits re-hosting and redistribution of the source file, not merely using it inside a game.
- **OpenGameArt** — https://opengameart.org/ — licences vary by asset; record the exact licence and attribution details.

**Important:** Pixabay and Mixkit can be used as sources for a user's finished animation, but their current terms do not permit Nexauren to re-host the unchanged audio as a separate downloadable asset in AnimPro's library. For the shared downloadable library, prioritize Freesound CC0/CC BY and OpenGameArt assets only when the exact asset licence permits redistribution. Freesound CC BY requires creator attribution; CC BY-NC is unsuitable for a commercial app/library. Keep a screenshot or copy of the licence/permission in the asset records.

## Folder structure

```text
audio/
  catalog.json
  impacts/
  movement/
  nature/
  ui/
  ambience/
  previews/
```

Supported catalogue extensions: `.mp3`, `.wav`, `.ogg`, `.m4a`. The app currently rejects downloads larger than 35 MB.

## Catalogue format

`catalog.json` is a JSON array. Add one object for every sound:

```json
[
  {
    "id": "ball-impact-01",
    "name": "Ball impact",
    "category": "Impacts",
    "description": "Short soft bounce impact",
    "file": "impacts/ball-impact-01.wav",
    "preview": "previews/ball-impact-01.mp3",
    "pro": false,
    "license": "CC0-1.0",
    "sourceUrl": "https://freesound.org/s/123456/",
    "sizeBytes": 12000,
    "durationSeconds": 1.25,
    "sha256": "64-character-lowercase-sha256-digest",
    "author": "Creator username",
    "attribution": "Sound name by Creator username, CC BY 4.0"
  }
]
```

Fields:
- `id`: unique letters, numbers, underscores or hyphens.
- `name`, `category`, `description`: visible catalogue information.
- `file`: full audio path relative to this folder.
- `preview`: short preview path; can be the same as `file`.
- `pro`: set true only when the sound is intentionally Pro-only.
- `license`: exact licence identifier or written-permission reference.
- `sourceUrl`: original asset page, not merely the platform homepage.
- `sizeBytes`, `durationSeconds`, `sha256`: exact file size, duration and SHA-256 digest. The app validates all three before accepting a download.
- `author` and `attribution`: keep the creator credit where required.

Never invent a licence or attribution. Keep a simple asset register with the source page, creator, download date, exact licence, proof of permission to redistribute, and any required credit.

## Publish

1. Confirm that the exact asset licence permits redistribution of the downloadable audio file.
2. Put the full sound in the correct category folder.
3. Put a short preview in `previews/` (or point `preview` to the full file).
4. Add its metadata to `catalog.json`.
5. Commit the audio and catalogue together.
6. Wait for GitHub Pages to publish, then open AnimPro > Audio Library > Refresh.

The app validates the declared size and SHA-256 before downloading, previews online, and saves a sound locally only after the user chooses it. The user can then place it at any frame in one of the six audio lanes. New catalogue entries do not require a new APK.
