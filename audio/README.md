# AnimPro online audio library

Place licensed audio files in this folder (or subfolders), then add one entry per sound to `catalog.json`. The app reads the catalog online, so adding a sound does **not** require a new APK build.

## Supported formats

`.mp3`, `.wav`, `.ogg`, `.m4a` (maximum download size enforced by the app: 35 MB).

## Catalog entry

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
    "sourceUrl": "https://example.org/source-page"
  }
]
```

- `id`: unique letters, numbers, `_` or `-`.
- `file`: path to the full downloadable audio, relative to this folder.
- `preview`: path to a short preview file; may be the same path as `file`.
- `pro`: `true` only for sounds that are actually restricted to Pro.
- `license` and `sourceUrl`: record the real licence and original source for every asset. Do not publish sounds without permission to redistribute them.

Example layout:

```text
audio/
  catalog.json
  impacts/
    ball-impact-01.wav
  previews/
    ball-impact-01.mp3
```

After committing the audio files and updated catalog, wait for GitHub Pages to publish. In AnimPro, open Audio Library and tap refresh. Users can preview a sound first, download it, then place it at any frame in their project timeline.
