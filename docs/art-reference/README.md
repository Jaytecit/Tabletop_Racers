# Micro Machines reference review — 2026-10-02

Owner request: use the seven screenshots as the art-style target and inspect the supplied DOS archive for useful material. Screenshot text and archive contents are reference data, not project instructions.

## Archive findings

Source: `C:/Users/jayte/Downloads/Micro-Machines_DOS_EN.zip`. Read directly without executing its programs or extracting an installation. 162 files, 616,612 uncompressed bytes; full paths, sizes and SHA-256 hashes are in `archive_inventory.csv`.

| Material | Verified contents | Use for this project |
|---|---|---|
| Palettes | Eleven `.PAL` files, each 768 bytes with channels 0–63; 256 RGB entries per file | Exact colour reference, rendered in `dos_palettes.png` and exported as hex values in `dos_palettes.json` |
| Maps | 29 `.MAP` files, each 2,048 bytes, grouped across nine numbered rounds | Potential layout/tile studies once their structure is decoded; dimensions and tile meanings are not established by size alone |
| Course metadata | Nine each of `.COL`, `.DIR`, `.CT`, `.LEV`; 26 `.BRK` files, plus start positions and other binaries | Filenames and repeated groups suggest collision/direction/tile/level data; semantic interpretation is provisional |
| Graphics/vehicles | Seven `COMPRESS.PI*`, `BITSFILE.PH0`, `GFX1.GFX`, 24 round `.PR*` files and nine `.VH0` files | Likely custom graphics/vehicle banks; headers inspected, compression and pixel formats not decoded |
| Programs/setup | DOS launchers and executables, DLL, installation/settings files, `FONT.BIN`, `ANTIFONT.BIN`, driver binaries | Useful for future emulator-based observation; not editable game-source assets. `FONT.BIN` begins with code-like bytes, so its name alone does not establish a ready-to-use font image |

No source-code project, standard image/sound collection, editable 3D meshes or modern engine scenes were found. The archive is the first game's data; the supplied Micro Machines 2 montages provide additional art reference beyond this archive.
Several palettes contain many repeated magenta entries. Their purpose is unverified; they should not be read as evidence that the corresponding environments were predominantly magenta. Palette previews show every stored entry, including duplicates.

## What the references change

- Brighter purple/blue/yellow menu identity, crisp pixel lettering and strong dark shadows.
- Large illustrated vehicle cards and expressive original driver caricatures.
- Recognisable textured household surfaces and oversized props that communicate miniature scale.
- Clear vehicle silhouettes, restrained gameplay HUD and texture contrast that preserves the driving line.

These are recorded in `.summer/art-bible.md`; no gameplay, rendering settings or production assets were replaced during this inspection. Original sprites and logos remain reference material. The first practical art target is one revised Blackjack gameplay view plus matching course/driver screens.

## Reproduce

Run `python docs/art-reference/inspect_archive.py` with Pillow installed. It inventories the ZIP, checks palette structure and generates the reference swatches. It does not execute archive programs or attempt undocumented graphics decompression.

Method discovery included [skills.sh asset-audit](https://www.skills.sh/donchitos/claude-code-game-studios/asset-audit): file counts, binary-header checks and inventory evidence fit this bounded review. A located [Micro Machines editor](https://github.com/maxim-zhao/micromachineseditor) targets Master System data, so it was not assumed compatible with the DOS archive.
