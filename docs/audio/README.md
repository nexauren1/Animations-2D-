# AnimPro online audio library

The Android app reads `catalog.json` from GitHub Pages at runtime. The catalogue is small; full audio files stay in `docs/audio/files/` and are transferred only when a user chooses a sound. Nothing in this folder is bundled into the APK.

## First sound collection

The generator publishes original procedural effects made for AnimPro:

- **Movement:** air whoosh and light footsteps.
- **Cartoon:** playful pop.
- **Environment:** forest birds and rain on a window.
- **Combat:** stylized impact for animation timing (non-graphic).
- **Fantasy:** magical sparkle.
- **Home:** wooden door creak.

The generated WAV files are mono, 16 kHz and intentionally short to keep downloads small. The effects are generated from synthesis/noise formulas in `.github/scripts/generate_resource_library.py`; they are not copied from stock libraries.

## Online files and catalogue

- `docs/audio/catalog.json` — public catalogue.
- `docs/audio/files/` — full sounds used for preview and on-demand download.
- `audio/catalog.json` — mirrored source catalogue for maintainers.

Each catalogue entry includes:
- `id`, `name`, `category`, `description`
- `file` and optional `preview`, both relative to `/audio/`
- `sizeBytes`, `durationSeconds` and `sha256`
- `pro`, `license` and `sourceUrl`

The mobile app validates the file extension, declared size and SHA-256 before saving a download. A sound can be previewed from Pages without downloading it; tapping Download saves it into the app's private audio folder for offline use. The same sound is reused if its local hash still matches the current catalogue.

## Adding a sound

1. Use an original sound or a file whose exact licence explicitly permits redistribution as a separate downloadable file inside a commercial app.
2. Add the file under `docs/audio/files/`.
3. Add catalogue metadata with the exact size, duration and SHA-256.
4. Run `python3 .github/scripts/generate_resource_library.py` when changing the generated starter collection; otherwise add the new metadata and asset together.
5. Open a Pull Request. The Pages workflow validates JSON, file sizes and hashes before it publishes.
6. After Pages deploys, open AnimPro → Audio Library → Refresh.

Do not re-host Pixabay or Mixkit files unless the exact licence and terms permit redistribution of the raw file. For third-party sounds, keep the original asset page, creator, licence version, date acquired, evidence of redistribution permission and required attribution. Never invent a licence or credit.

New audio catalogue entries do not require a new APK.
