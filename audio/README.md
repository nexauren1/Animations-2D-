# AnimPro — Online sound library

This folder is the source of the public audio catalogue served by GitHub Pages. The Android app reads `audio/catalog.json` online, so publishing a new sound and updating the catalogue does not require a new APK.

## Where to find sound effects

Use these sources to discover sounds. Check the licence of each individual asset before copying it into this repository:

- **Freesound** — https://freesound.org/ — prefer CC0 or CC BY assets. Do not use CC BY-NC in AnimPro's distributable library because AnimPro is a commercial product. Freesound's FAQ explains the per-sound licences and attribution requirements: https://freesound.org/help/faq/
- **Pixabay Sound Effects** — https://pixabay.com/sound-effects/ — review the current Pixabay Content License and restrictions for each asset. A free download does not automatically mean that re-hosting the raw file as a separate downloadable library is allowed.
- **Mixkit Sound Effects** — https://mixkit.co/free-sound-effects/ — check the item and current Mixkit licence. Do not redistribute an asset as a standalone download unless the licence explicitly permits it.
- **OpenGameArt** — https://opengameart.org/ — licences vary by asset; record the exact licence and attribution details.

**Important:** use sources to find assets, not to bypass their licences. Only put an audio file in this repository if its licence or written permission allows Nexauren to host and redistribute the original file for users to download. If the terms only permit use inside a finished project, do not put the raw file in this downloadable library. Keep a screenshot or copy of the licence/permission in the asset records.

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
- `author` and `attribution`: keep the creator credit where required.

Never invent a licence or attribution. Keep a simple asset register with the source page, creator, download date, exact licence, proof of permission to redistribute, and any required credit.

## Publish

1. Confirm that the exact asset licence permits redistribution of the downloadable audio file.
2. Put the full sound in the correct category folder.
3. Put a short preview in `previews/` (or point `preview` to the full file).
4. Add its metadata to `catalog.json`.
5. Commit the audio and catalogue together.
6. Wait for GitHub Pages to publish, then open AnimPro > Audio Library > Refresh.

The app can then preview the sound, download it on demand, and let the user place it on a chosen frame. New catalogue entries do not require a new APK.
