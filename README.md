# Spaceship

A 2D arcade game inspired by Volfied and Qix. You pilot an alien ship along the
edge of a playfield, cut lines into the uncleared space, and claim territory.
Reach 75% coverage to clear the level. Stars, asteroids, and a chaser alien try
to stop you.

Built with Godot 4.x (GDScript). No external art or sound assets: everything is
drawn with code.

## Requirements

- Godot 4.x with the `godot` command on your `PATH`

## Run

```sh
./run.sh
```

`run.sh` checks that `godot` is available and launches the project with
`godot --path .`. Extra arguments are passed through to Godot.

## Controls

| Action            | Keys                 |
|-------------------|----------------------|
| Move              | Arrow keys or WASD   |
| Start / draw cut  | Hold Space and move inward |

- Move along the border with the directional keys. Corners turn automatically.
- Hold Space and move into the field to draw a cut. Return to the border to claim
  the smaller enclosed area.
- Releasing Space mid-cut cancels the cut without losing a life.
- Hitting your own cut, or being touched by a star, asteroid, or the alien, costs a life.
  A cut in progress is destroyed; on the border you respawn at the first corner.
- Hazards caught inside a claimed area are moved to open space.

## Tests

Headless checks for movement, cutting, claiming, collisions, and hazards:

```sh
./run.sh --headless -s res://tests/test_perimeter.gd
```

The script prints `cut tests: PASS` on success and exits non-zero on failure.

## Project layout

```
project.godot           Godot project settings
run.sh                  Launch script
scenes/Main.tscn        Main scene (field, player, hazards, HUD)
scripts/main.gd         Field, coverage tracking, win condition
scripts/player.gd       Ship movement, cutting, claiming, crashes
scripts/hazards.gd      Stars, asteroids, chaser alien
scripts/hud.gd          Top bar: coverage, target, lives, level
tests/test_perimeter.gd Headless test suite
```

## Status

Playable through Step 5 of the build plan: movement, cutting, territory claiming,
coverage HUD, and hazards. Levels, game over, and transition screens are not
implemented yet.
