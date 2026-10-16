# AnimPro audio library

The app reads `catalog.json` from the published GitHub Pages site. Add Pixabay audio files here and add one catalog entry for each file. Once the Pages deployment completes, the new sounds appear in the app without releasing a new APK.

## Folder layout

- `docs/audio/catalog.json` — online library catalogue.
- `docs/audio/files/` — full audio files used by the download button.
- `docs/audio/previews/` — optional short preview files; if omitted, the full file is previewed.

Use short, descriptive filenames with letters, numbers, hyphens or underscores. Supported formats are MP3, WAV, OGG and M4A. Keep individual downloads below 35 MB.

## Catalogue entry

```json
[
  {
    "id": "cartoon-pop-01",
    "name": "Cartoon Pop 01",
    "category": "Cartoon",
    "description": "Short, playful impact sound",
    "file": "files/cartoon-pop-01.mp3",
    "preview": "previews/cartoon-pop-01-preview.mp3",
    "pro": false,
    "license": "Pixabay Content License",
    "sourceUrl": "https://pixabay.com/sound-effects/..."
  }
]
```

If no separate preview exists, set `preview` to the same value as `file`. For Pro-only entries, set `pro` to `true`.

## Copyright and quality checks

Only publish audio that you downloaded under a licence that allows redistribution inside an app. Keep the original Pixabay source URL and check the current licence/terms before publishing. Do not commit private, personal or unlicensed audio. Listen to every file, trim silence, use consistent loudness and keep preview clips short.

The catalogue is intentionally empty until the owner adds verified files. The app never invents sample sounds.
