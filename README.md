# Spaceship

A 2D arcade game inspired by Volfied and Qix. You pilot an alien ship along the
edge of a playfield, cut lines into the uncleared space, and claim territory.
Reach the coverage target to clear the level. Rocks, invaders, and ghosts try to stop you.

Built with Godot 4.x (GDScript). No external art or sound assets: graphics and
sounds are all generated in code.

## Play in a browser

https://ran1979.github.io/spaceship/

Works on phones and tablets: a drag pad (bottom-left) moves the ship and a hold button
(bottom-right) cuts. Landscape works best.

## Requirements

- Godot 4.x with the `godot` command on your `PATH`

## Run

```sh
./run.sh
```

`run.sh` checks that `godot` is available and launches the project with
`godot --path .`. Extra arguments are passed through to Godot.

## Controls

| Action              | Keys                              | Touch                   |
|---------------------|-----------------------------------|-------------------------|
| Move                | Arrow keys or WASD                | Drag pad (bottom-left)  |
| Draw a cut          | Hold Space and move inward        | Hold cut button (bottom-right) |
| Menu: play          | Space or Enter                    | Tap PLAY                |
| Continue / restart  | Space                             | Tap cut button          |

- Move along the border with the directional keys. Corners turn automatically.
- Hold Space and move into the field to draw a cut. Return to the border to claim
  the smaller enclosed area.
- Releasing Space mid-cut cancels the cut without losing a life.
- Hitting your own cut, or being touched by an enemy, costs a life.
  A cut in progress is destroyed; on the border you respawn at the first corner.
- Enemies caught inside a claimed area explode and come back in open space after 3 seconds.
- Gift boxes are collected by touching them.

## Menu, scoring and high scores

The game opens on a start menu with a PLAY button and the high-score board (top 5).
Game over returns to the menu.

- Claiming territory scores 10 points per percent of the field, times the level number.
- Each completed level adds a bonus of 1000 times the level number.
- Scores are saved on the device or browser (`user://highscores.json`). The web version
  keeps its board in the browser, so boards are not shared between players.

## Enemies

- **Rocks** (stars and asteroids): Asteroids-style rotating outlines in three sizes.
  They bounce off the field edges.
- **Invader**: a Space Invaders crab that bounces around, then chases the nearest point
  of your cut line once you start drawing.
- **Ghosts** (Pac-Man style), from level 3 on:
  - Blinky (red) chases the nearest point of your cut line.
  - Pinky (pink) heads straight for your ship while you're drawing.
  - Clyde (orange) wanders and flees when your ship gets close.

Gift boxes (presents) are not enemies. They appear at random spots from time to time:
extra life, shield (5 s of immunity), speed boost (5 s), or slow enemies (5 s).

## Web build

The browser version lives in `docs/` and is served by GitHub Pages from that folder.
Pushing changes under `docs/` deploys it through `.github/workflows/pages.yml`.
To rebuild it after changes (needs the Godot 4.x web export templates):

```sh
godot --headless --path . --export-release "Web" docs/index.html
```

## Tests

Headless checks for movement, cutting, claiming, collisions, enemies, presents,
scores, menu flow, and touch mapping:

```sh
./run.sh --headless -s res://tests/test_perimeter.gd
```

The script prints `cut tests: PASS` on success and exits non-zero on failure.

## Project layout

```
project.godot           Godot project settings
export_presets.cfg      Web export preset
run.sh                  Launch script
scenes/Main.tscn        Main scene (field, player, enemies, presents, HUD, menu)
scripts/main.gd         Game flow, levels, scoring, win and game over
scripts/menu.gd         Start menu and high-score board
scripts/scores.gd       High-score storage
scripts/player.gd       Ship movement, cutting, claiming, crashes
scripts/hazards.gd      Rocks, invader and ghosts
scripts/presents.gd     Gift boxes
scripts/sfx.gd          Procedural sound effects
scripts/touch_controls.gd On-screen controls for touch devices
scripts/hud.gd          Top bar: score, coverage, target, lives, level
tests/test_perimeter.gd Headless test suite
docs/                   Web build served by GitHub Pages
.github/workflows/      Pages deploy workflow
```

## Status

All build steps are implemented, plus the start menu, scoring, high-score board,
touch controls and the browser build. Level 1 needs 60% coverage with 3 rocks and
no invader; the target rises 5% per level up to 75%, and enemies grow each level.
Running out of lives ends the game.
