# AnimPro audio library assets

Put the audio files you have permission to redistribute in this folder. The app reads `catalog.json` from the repository's `main` branch and streams each listed file for preview; downloading copies it into the app's private storage.

## Folder structure

- `content/audio/catalog.json` — public catalogue used by the Android app.
- `content/audio/sfx/` — short sound effects (clicks, steps, whooshes, impacts, UI sounds).
- `content/audio/ambience/` — atmosphere and room tone.
- `content/audio/music/` — music loops.

Use lowercase filenames with no spaces where possible. Supported formats: MP3, WAV, OGG, M4A and AAC. Keep each file under 50 MB; short previews and effects load faster on mobile.

## Add one sound

Add the file, for example `content/audio/sfx/soft-whoosh.mp3`, then add a catalogue entry:

```json
{
  "schemaVersion": 1,
  "items": [
    {
      "id": "soft-whoosh",
      "title": "Soft whoosh",
      "category": "Movimento",
      "file": "sfx/soft-whoosh.mp3",
      "pro": false,
      "credit": "Creator name",
      "license": "Pixabay Content License"
    }
  ]
}
```

Use an explicit, accurate credit and license for each file. Do not assume every Pixabay download can be redistributed inside an app or re-uploaded to a public Git repository: verify the asset's current license/terms before inclusion. If a sound's terms do not permit redistribution, do not put the audio file in this repository.

For Pro sounds, set `"pro": true`. All sounds can be previewed online in AnimPro; adding/downloading a Pro sound requires the user's active Pro entitlement. After adding a new file/catalogue item to `main`, it becomes available from the audio library without a new APK update.
