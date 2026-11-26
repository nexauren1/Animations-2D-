# AnimPro online scene packs

The Android app loads `catalog.json` from GitHub Pages at runtime. The catalogue lists the available scene packs; the vector data for each pack is downloaded only after the user taps Download. These files are not declared in Flutter assets and are not included in the APK.

## Starter collection

The generator creates the first editable vector packs:

| Pack | Contents |
|---|---|
| Ceus e clima | Day sky, sunset and starry night |
| Florestas e natureza | Pine forest, forest stream and enchanted grove |
| Casas e interiores | Cottage exterior, living room and kitchen |
| Cidades e ruas | Modern skyline, commercial street and night rooftops |
| Personagens e acao | Eight-frame sparring sequence, dojo duel and combat poses |
| Fantasia e aventura | Castle, dragon cave and magic portal |
| Starter imports | Existing space and expressive-character packs |

The vector shapes are stored as editable frame/layer/stroke JSON, not flattened pictures. A downloaded pack can be used to create a project; removing the downloaded pack later does not delete projects created from it.

## Paths and manifest

- `docs/packs/catalog.json` — online manifest.
- `docs/packs/files/*.json` — downloadable vector packs.
- `.github/scripts/generate_resource_library.py` — deterministic pack generator.

The manifest records `sizeBytes`, `sha256`, `templateCount`, `category` and tags. The app rejects unsafe paths, duplicate IDs, unexpected sizes, invalid pack structure and checksum mismatches. A last-known good manifest is cached for browsing offline; pack downloads require the network.

## Publish

Run:

```bash
python3 .github/scripts/generate_resource_library.py
```

The same generator runs in GitHub Actions before Pages deployment. Pull Requests run the generator and verify catalogues and file hashes without publishing Pages. New packs do not require an APK update.
