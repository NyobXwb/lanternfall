# Lanternfall

A turn-based dungeon roguelike made in Godot 4.5.1. Descend ten generated floors and defeat the Warden. Your lantern oil burns every turn: it is your light, your vision and your clock.

Design doc: https://claude.ai/artifact/AxediD5syxZYcwXJrhP7QQ

## Run it

Open the folder in Godot 4.5.1 and press Play, or run `godot --path .`.

## Project layout

| Folder | What lives there |
| --- | --- |
| `core/` | All game rules (`game.gd`), map generation, save and profile. No scene nodes. |
| `data/defs.gd` | Classes, monsters, items, blessings. Balance changes go here. |
| `bot/` | A bot that plays through the same `act()` API as a human. |
| `ui/` | Screens, HUD, map rendering, input, sound. |
| `tools/` | Headless tests, balance simulator, placeholder art script. |
| `assets/` | Kenney art and audio (CC0) plus the old placeholder sheet. |

## Checks

```sh
godot --headless --path . -s tools/test.gd                 # rules tests
GODOT=godot tools/sim.sh 300 | python3 tools/summarize.py   # bot balance, 300 runs per class
```

Balance target for the careful bot: 15 to 35% wins per class, classes within 10 points of each other.

## Builds

`export_presets.cfg` has Web, Windows and Linux presets, for example `godot --headless --path . --export-release Windows`.

## Credits

Art, sound effects and music by Kenney (www.kenney.nl), CC0. Licenses are in `assets/kenney/`.
