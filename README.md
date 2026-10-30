# Apex Assassin

v0.5.2 — night-grade depot, bright vision cones, player-following zoom camera, Hunter Assassin-style stealth, 10 assassins, 17 knives.

Original top-down stealth action game for Godot 4.7.2, built for Raspberry Pi 5 / Ubuntu and Android.

## What is in this build

- **Two original playable assassins**
  - **Ronin** — raven-hood blade specialist, balanced speed.
  - **Nova** — teal-hood twin-blade runner, faster, unlock with gems.
- **Real node-based animations**: idle, run, attack, shoot, hurt, death.
- **Hunter Assassin-style core loop**
  - Tap floor to move.
  - Tap a guard to hunt it.
  - Auto-blade when in range.
  - Guard vision cones, patrols, investigation, alert/chase, gunfire, search.
  - Walls and crates block sight and bullets.
  - Shadows slow detection.
  - Kills drop gems; collect them to unlock Nova.
  - Clear all guards to finish the level.
- **100 validated levels** with increasing guard counts and cover density.
- Home screen, character select, upgrades, missions, daily wheel, level select, stars, local save.
- Original synthesized sound effects and mobile haptics.
- **Debug-only Android APK workflow** for GitHub Actions. No release keystore or signing secrets.

## Run on Raspberry Pi 5

```bash
"$HOME/Godot/Godot_v4.7.2-stable_linux.arm64" --path /home/aryan/apex-assassin --editor
```

Press **F5**.

## Controls

| Input | Action |
|---|---|
| Tap / click floor | Move there |
| Tap / click guard | Hunt that guard |
| Esc / Android back / II | Pause |

Stay out of flashlight cones. Use crates and walls as cover. Shadows make you harder to spot. Strike quickly and move before nearby guards investigate.

## Tests

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script tests/smoke_test.gd
```

## Push to GitHub + build APK

```bash
cd /home/aryan/apex-assassin
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
bash tools/publish_github.sh
```

Then open:

```text
https://github.com/Aryanshahx/apexassassin/actions
```

The **Android APK** workflow runs tests and uploads:

```text
apex-assassin-debug-<commit-sha>
```

Download the artifact and install the APK on an arm64 Android device.

## Rebuild original art / levels

The game ships with generated PNGs and levels, so these are optional:

```bash
python3 -m pip install pillow cairosvg
python3 tools/build_art.py
python3 tools/generate_levels.py
```

## Project layout

```text
assets/characters/   original modular character parts
assets/home/         character card portraits
assets/level/        floor, walls, crates
assets/fx/           slash, spark, gem
art_source/          editable SVG sources
scripts/game/        gameplay, rigs, save state, sound
scripts/ui/          splash + home
data/levels/         100 generated levels
tests/               headless smoke tests
tools/               art/level generators + GitHub publish helper
.github/workflows/   Android debug APK CI
```

## Notes

This is an original game inspired by the stealth-action genre. It does not use Hunter Assassin assets, code, or branding.


## v0.4 update

- Edge-to-edge phone layout with safe-area support; home, collections, HUD and levels reflow for tall/wide screens.
- 10 assassins: Ronin, Sable, Nova, Aegis, Dash, Sentinel, Sage, Crimson, Fiesta, Oni. Speed/health bonuses apply in gameplay.
- 17 special knives with level unlocks or gem purchases. Equipped knife changes damage, attack speed, reach and the player blade sprite.
- Save migration keeps existing progress and unlocks.
- Visual capture helper: `APEX_CAPTURE_DIR=/tmp/apex-shots godot --path . --resolution 720x1600 --script tests/capture_ui.gd` (use a display/Xvfb).


## v0.5 update

- **Warehouse Depot environment — the approved concept art itself.** Every container lid, hazard
  cap, corner casting, side face, crate, drain, arrow and floor tile is cut directly out of
  `art_source/environment/depot_concept.png` by `tools/extract_depot_art.py`. Nothing is redrawn.
  Containers are 9-sliced (fixed caps + tiled ribbed middle + real depth face) so runs of any
  length keep the original shading. Concrete extends past the arena so tall phones show no bars.
- **Backstab stealth**: striking an unaware guard from behind is an instant silent kill, drops bonus
  gems and makes no noise. Frontal attacks damage normally and raise the alarm.
- **Level-wide alarm**: one confirmed sighting pulls every patrolling guard into a search.
- **Drag steering**: hold and drag to walk continuously; tapping still auto-paths, tapping a guard hunts it.
- **Takedown feedback**: shock ring, gem fountain, floating "+N", micro hit-stop and screen shake.
- **Lucky Wheel** is a real spinning 8-segment wheel that decelerates onto the winning prize and
  credits cash or gems once per day.
- Home screen: VIP / No Ads / Offers removed, button stack raised.


## v0.5.2 update

- **Night-grade depot**: floor, walls, crates and props are colour-graded down so guard
  flashlight cones are clearly readable instead of washing out on bright concrete.
- **Bright vision cones**: layered beam (outer wash + hot inner core + crisp edge outline),
  colour-coded yellow / amber / red for patrol / searching / alert. Ray resolution raised to
  40 rays x 64 steps so cone edges are smooth against cover.
- **Player-following zoom camera**: the view now shows ~12 grid cells across the screen and
  follows the assassin, clamped to the arena, instead of shrinking the whole map to fit.
  The environment fills the entire phone screen and characters are much larger.
