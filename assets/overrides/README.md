# Bundled overrides (creator territory)

Put replacement art/audio here **inside the project** to ship it with the game.
Mirror the template path and drop the `template_` prefix:

    assets/templates/characters/player/template_survivor_down.png
    assets/overrides/characters/player/survivor_down.png

Code and tools never write into this folder. See `docs/guides/ASSET_REPLACEMENT.md`.
For replacements that should work in an exported build without re-exporting,
use the external folder instead (Settings → "Open overrides folder").
