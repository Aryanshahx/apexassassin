# Apex Assassin

v0.6.3 — traversable routes, long L-shaped cover, faster bullets and alerted guards, money and rare diamonds, and your own button tap audio.

Original top-down stealth action game for Godot 4.7.2, built for Raspberry Pi 5 / Ubuntu and Android.

## What is in this build

- **12 reference characters**, immediately available in the character selector, with the
  speed/health bonuses shown in the supplied screenshot. You play as one at a time.
- The twelve v0.5.6 `new01`–`new12` designs have been removed from the game.
  Saves that selected one fall back to Ronin; other progress is preserved.
- **10 legacy character IDs**, costs, bonuses, selected state and unlocks remain supported.
  Their visuals now use the reference art style.
- **17 knives**, with their existing damage, speed, reach and unlock rules.
- **Reconstructed movement**: separate boot pivots for player and guards, smoothed
  facing, idle, run, attack, shoot, hurt and death. The shader/node animation is recreated
  from single still images, not original animation frames.
- **Smoother steering**: route replans do not pull actors back to their current
  cell centre; touch-emulated mouse events are de-duplicated, flashlight rays
  use exact obstacle intersections, and the remaining walkable path is highlighted.
  A small arrowhead marks the end of that actual route; there is no tap ring.
  Taps on cover resolve to nearby reachable floor.
- **Improved guards** roam across reachable map regions and avoid one another
  and cover with wider spacing and stable passing. Flashlight contact causes
  an immediate shot; gunfire alerts nearby guards, which investigate the last
  known location and still require line of sight to shoot. Boots and rifle aim
  are approximations rebuilt from stills.
- **Three enemy types** (tunable defaults): scout deals 65 damage every 0.65 s,
  standard guard deals 100 every 1.00 s, and heavy deals 160 every 1.45 s.
  They have distinct tints, speeds and heavy armour. Gunshots can alert guards
  within 480 world units; a red `?` marks alert, investigation and search.
- **Visible health**: the player starts at 1,000 base health, shown in a thinner
  green bar above the character. Existing character health bonuses and saved
  health upgrades continue to apply (+100 per upgrade).
- **Long L-shaped cover** replaces most of the scattered small obstacles: four
  joined L groups and up to two large accents per map, with safe connected
  routes on all 100 levels. All 1,064 guards and the existing spawns remain.
  The seeded level generator reproduces the maps deterministically.
- **Faster threats**: bullets travel at 660 units/s; alerted pursuit is 1.8×
  patrol speed and investigation 1.45×. The first shot is still immediate.
- **Money and rare diamonds**: each kill immediately saves +10 cash (+20 for a
  heavy, plus +5 for a silent kill). Some levels have one diamond carrier; a
  carrier awards one diamond on defeat. Floating loot and top HUD totals show
  the result. Existing saved gems retain their value and are shown as diamonds.
- **Button tap feedback**: buttons briefly compress and play the player's own
  `assets/audio/ui_tap_audio.mp3`, respecting the existing sound setting.
- **Chosen character logo** is used for the Android launcher. The original splash
  artwork is retained, with its bottom labels changed to “Loading...” and
  “Hyper Tech Labs”.
- **Functional warehouse selector** based on the chosen demo: browse the full
  roster, preview stats, then explicitly select or unlock a legacy character.
- **Hunter Assassin-style core loop**
  - Tap floor to move.
  - Tap a guard to hunt it.
  - Auto-blade when in range.
  - Guard vision cones, patrols, investigation, alert/chase, gunfire, search.
  - Walls and crates block sight and bullets.
  - Light touching the player is detected immediately, even in shadows.
  - Kills award money and, rarely, diamonds; unlocks use the existing wallet.
  - Clear all guards to finish the level.
- **100 validated levels** with increasing guard counts and cover density.
- User-selected **classic-style home**: the old top-down warehouse backdrop,
  purple character/knife cards, three mission rows and a large gold Start button.
  Resources, selected character portrait, progress, mission claims, wheel,
  settings, upgrades, level select, stars and local save are all live controls;
  the example numbers from the design are not baked into the game.
- Level and depot resources are cached; static map layers are retained, and
  off-screen/near-cover guard beams are culled or cached to reduce work.
- Existing sound effects and mobile haptics, plus the locally supplied button-tap MP3.
- **Debug-only Android APK workflow** for GitHub Actions. No release keystore or signing secrets.

## Update on Raspberry Pi 5

Put your `ui_tap_audio.mp3` in `~/Downloads/` before running the separate
`apex_v063_update.sh` on your existing v0.6.2 project. The installer copies the
MP3 **without modification**, checks the existing project, protects local edits,
and creates a rollback backup. It does not automatically publish to GitHub.
The code-only source ZIP does not include your MP3 or the project's art assets.

```bash
bash ~/Downloads/apex_v063_update.sh /home/aryan/apex-assassin
```

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

Stay out of flashlight cones: guards shoot immediately on contact. Use crates and walls as cover, and move before nearby guards investigate gunfire.

## Tests

```bash
godot --headless --path . --import
# Tests write save files; always use isolated, temporary user-data directories.
SMOKE_DATA="$(mktemp -d)"; REF_DATA="$(mktemp -d)"; MOVE_DATA="$(mktemp -d)"
ROAM_DATA="$(mktemp -d)"; TRANS_DATA="$(mktemp -d)"; HOME_DATA="$(mktemp -d)"
COMBAT_DATA="$(mktemp -d)"; COLLISION_DATA="$(mktemp -d)"; SPLASH_DATA="$(mktemp -d)"
LAYOUT_DATA="$(mktemp -d)"; GATE_DATA="$(mktemp -d)"; ENEMY_DATA="$(mktemp -d)"
PATH_DATA="$(mktemp -d)"; LOOT_DATA="$(mktemp -d)"; BTN_DATA="$(mktemp -d)"; AUDIO_DATA="$(mktemp -d)"
XDG_DATA_HOME="$SMOKE_DATA" godot --headless --path . --script tests/smoke_test.gd
XDG_DATA_HOME="$REF_DATA" godot --headless --path . --script tests/reference_test.gd
XDG_DATA_HOME="$MOVE_DATA" godot --headless --path . --script tests/movement_test.gd
XDG_DATA_HOME="$ROAM_DATA" godot --headless --path . --script tests/roaming_test.gd
XDG_DATA_HOME="$TRANS_DATA" godot --headless --path . --script tests/transition_test.gd
XDG_DATA_HOME="$HOME_DATA" godot --headless --path . --script tests/home_test.gd
XDG_DATA_HOME="$COMBAT_DATA" godot --headless --path . --script tests/combat_test.gd
XDG_DATA_HOME="$COLLISION_DATA" godot --headless --path . --script tests/collision_test.gd
XDG_DATA_HOME="$SPLASH_DATA" godot --headless --path . --script tests/splash_test.gd
XDG_DATA_HOME="$LAYOUT_DATA" godot --headless --path . --script tests/layout_test.gd
XDG_DATA_HOME="$GATE_DATA" godot --headless --path . --script tests/gate_test.gd
XDG_DATA_HOME="$ENEMY_DATA" godot --headless --path . --script tests/enemy_types_test.gd
XDG_DATA_HOME="$PATH_DATA" godot --headless --path . --script tests/player_path_test.gd
XDG_DATA_HOME="$LOOT_DATA" godot --headless --path . --script tests/loot_speed_test.gd
XDG_DATA_HOME="$BTN_DATA" godot --headless --path . --script tests/button_feedback_test.gd
XDG_DATA_HOME="$AUDIO_DATA" godot --headless --path . --script tests/tap_audio_import_test.gd
rm -rf "$SMOKE_DATA" "$REF_DATA" "$MOVE_DATA" "$ROAM_DATA" "$TRANS_DATA" "$HOME_DATA" "$COMBAT_DATA" "$COLLISION_DATA" "$SPLASH_DATA" "$LAYOUT_DATA" "$GATE_DATA" "$ENEMY_DATA" "$PATH_DATA" "$LOOT_DATA" "$BTN_DATA" "$AUDIO_DATA"
```

## Push to GitHub + build APK

```bash
cd /home/aryan/apex-assassin
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
bash tools/publish_github.sh
```

The script fetches `origin/main`, refuses to overwrite a newer remote or other
staged changes, stages only the update paths, shows the proposed commit and asks
for confirmation. Authenticate Git with GitHub first (for example, `gh auth
login`); never put access tokens in the script. Check `ASSETS_LICENSE.md` and
make sure you have permission to publish the tap audio before publishing. It does not force-push or automatically resolve divergent history.

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
# Optional: rebuild the shipped screenshot-derived player and guard images.
python3 -m pip install pillow numpy opencv-python
python3 tools/build_reference_assets.py
# Optional: regenerate the reconstructed boot layers and selector background.
python3 tools/build_reference_gait.py
python3 tools/build_guard_layers.py
python3 tools/build_home_v59_background.py
python3 tools/build_selector_background.py
```

## Project layout

```text
assets/characters/   original modular character parts
assets/home/         home artwork
assets/reference/    screenshot-derived player/guard poses and selectable cards
assets/ui/selector/  chosen concept's reconstructed warehouse background
assets/level/        floor, walls, crates
assets/fx/           slash, spark, gem
art_source/          editable SVGs, original concept images and source stills
scripts/game/        gameplay, rigs, save state, sound
scripts/ui/          splash + home
data/levels/         100 generated levels
tests/               headless smoke tests
tools/               art/level generators + GitHub publish helper
.github/workflows/   Android debug APK CI
```

## Notes

The gameplay code is an original project inspired by the stealth-action genre.
The v0.5.5 character and guard images are derived from user-supplied game
screenshots, and the original rights are not established. Review
`ASSETS_LICENSE.md` and obtain any required permissions before publication or
distribution. No original source animation frames were supplied.


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
- **Historical v0.5 alarm**: sightings once alerted the whole level; v0.6.1 replaces this with nearby gunshot alerts.
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


## v0.5.3 camera refinement

- The player-following camera now shows **15 grid cells across** instead of 12: 25% more
  visible world width, with actors 20% smaller. The phone's safe-area width determines zoom.
- Existing arena-edge clamping, night lighting, real depot pixels and bright flashlight cones
  are unchanged. Four camera checks bring the smoke suite to **244 checks**.
- Character concepts are being reviewed separately; this patch does not change the existing
  roster, character bonuses, save data or player/enemy animation rigs.


## v0.5.4 — larger depot cover, unchanged actors

- Walls and crates grow by **3 world units on each edge**. A one-cell-wide
  obstacle grows from 32 to 38 units (18.75% thicker); larger rectangles
  receive the same modest 3-unit expansion per edge. The approved depot pixels,
  original colour assignment, night grade and vision-cone styling are retained.
- The 15-cell follow camera, player and enemy rig scales, actor animations and
  speeds remain unchanged. Shadows and line-of-sight/bullet blocking use the
  enlarged cover. Because the 7-unit maximum margin is below half a grid cell,
  the centre-based walkability grid stays unchanged; all 100 levels are tested.
- Reference character selection is separate; this patch does not change the
  roster or claim to reproduce the reference animations.


## v0.5.5 — all 12 reference characters

- All 12 reference characters are immediately selectable without spending gems.
  Their cards show the supplied screenshot art with the lock icons retouched,
  and their speed/health bonuses match the reference. Only one is active at a time.
- All 10 previous character IDs, stats, unlocks and save progress remain. Their
  gameplay and home portraits map to the new reference visual style.
- Player and both guard appearances use screenshot-derived pixels. Their idle,
  running, attack, shooting, hurt and death motion is newly approximated from
  one still pose each; it is not the original animation. All 17 knives retain
  their existing mechanics and display when equipped.
- The existing 15-cell follow camera and player/guard root scales are retained.
  Screenshot-art bounds are capped at 55 world units for the player and 60 for
  guards; enlarged cover, depot pixels, night grade and cones are unchanged.
- Two isolated suites cover the game plus all 12 characters, both guards, all
  knives, UI selection, animation playback and v2/v3 save migration.
- The screenshots may contain third-party game artwork. Review `ASSETS_LICENSE.md`
  and confirm distribution rights. The Android workflow exports a **debug APK
  only**, not a release build.


## v0.5.6 — historical additional roster + motion and steering

- At that time twelve new designs were added; they were removed in v0.5.8. The 12 screenshot
  choices, 10 legacy IDs, their save data and 17 knives remain intact.
- Replanning now skips a safe current-cell centre behind the actor; a 90-frame
  regression reproduces 45 backward frames on v0.5.5 and zero on this build.
  Guard seek receives the same correction. Tap, drag, hunt and attack remain.
- Hand and foot pixels sway in counterphase, knife swings while moving, and
  generated sprites use mipmaps to avoid shimmer at the unchanged 55-unit extent.
  Guard extent remains 60; root scales, 15-cell camera and enlarged cover remain.
- Flashlight beams retain 40 rays, but exact rectangle intersections replace the
  former 64 point samples per ray. The same enlarged cover blocks cones, LOS and
  bullets; dense collision-sampling and movement tests cover the change.
- The tap destination has a high-contrast pulsing ring and arrow; duplicate
  emulated mouse events are ignored. The screenshot concept is a source image,
  while the warehouse selector's controls and stats are fully interactive.
- Headless suites use isolated saves and cover smoke, roster/animation/UI and
  movement/LOS. Android export is debug-only. No device test is implied.

## v0.5.7 — historical path highlight and guard improvements

- Replaces the destination arrow, ring and tap mark with a line following the
  remaining actual path. Touching cover or outside the arena routes to a nearby
  reachable cell rather than showing a line through the obstacle.
- Separately animated screenshot-derived guard boot and gun layers make patrol
  motion steadier. The gun raises and follows the player while visible, and
  the muzzle flash stays attached to the gun.
- These are reconstructed motions, not original source animation frames.

## v0.5.8 — home, movement, roaming and performance

- Removes the twelve additional designs; keeps 12 reference characters, 10
  legacy IDs and 17 knives. Removed selections safely fall back on load.
- At that time implemented a different home concept with live currency and
  controls; this was replaced by the user's selected classic style in v0.5.9.
- Player and guard boot motion is reconstructed from stills; guards roam the
  reachable map, avoid each other and keep aiming at visible players.
- Adds an arrowhead to the remaining actual route, no tap/destination ring, and
  coalesces drag repathing for more responsive touch.
- Shares level/depot data, retains static floor and cover, limits off-screen
  light work and caches clipped light meshes. Degenerate beam triangles are
  handled without repeated rendering errors. Consecutive level transitions and
  late levels were tested, but no physical Android device has been tested.

## v0.5.9 — selected classic-style home

- Recreates the chosen old-style design with a colour-matched original
  warehouse background and real, responsive Godot controls. Currency, the
  selected assassin, mission progress and claims, level, wheel, shop and
  settings use live save state rather than values baked into a picture.
- The reference and legacy rosters, selector, gameplay and movement changes
  from v0.5.8 are retained. Home and gameplay were tested in browser touch
  emulation and isolated headless suites; no physical Android test is implied.

## v0.6.0 — original spotlight home

- Recreates the newly chosen design as live Godot controls: title and resources,
  a golden spotlight showing **only the currently selected** in-game assassin
  and name, shortcut tiles, grouped missions and the saved-level Start button.
  The concept's demonstration character and example resource numbers are not
  baked in; the portrait and name refresh immediately when you choose another.
- Retains the approved warehouse, 12 reference and 10 legacy IDs, 17 knives,
  previous save migration, guarded roaming, reconstructed gait and route arrow.
- The lightweight vector spotlight is `assets/home/character_stage.svg`. The
  pure-Python `tools/build_reference_gait_stdlib.py` can regenerate the 24
  reference gait layers from the retained screenshot sprites without Pillow.
- Browser touch emulation and isolated headless tests cover the home and gameplay.
  No physical Android device test has been performed. Review `ASSETS_LICENSE.md`
  before publishing; screenshot-art rights are not established.

## v0.6.1 — clearer combat, character logo and splash labels

- The player sprite is larger while the camera and guard scales stay unchanged.
- A green world-space health bar follows the player, starts at 1,000 base HP,
  and updates after each hit. The HUD no longer displays heart lives.
- Guard separation, wall clearance and persistent avoidance prevent the
  head-on/crossing oscillation; crowded searches stop squeezing toward one point.
- Arrow orientation and size use a short look-back along the real path, avoiding
  the tiny end-segment flicker; the arrow tip remains at the route endpoint.
- The first touch of the visible flashlight cone causes an immediate shot.
  Nearby guards investigate gunfire, but neither detection nor bullets pass
  through cover. Shadows no longer delay detection inside a visible beam.
- The user-selected character-only app icon replaces the previous launcher icon.
  Only the old splash's “Loading Assets” and “APEX GAMES” labels are changed to
  “Loading...” and “Hyper Tech Labs”; the original splash artwork remains.
- The Git publisher disables the pager so its review list and confirmation
  cannot appear to stall on a long terminal screen.

## v0.6.2 — larger cover and smarter enemy traffic

The new obstacle size is 1.2 times the v0.6.1 rendered rectangle, centered on
the repaired placement. Some cover has moved and some interior wall sections
were opened to keep the enlarged layouts navigable; original crate and guard
counts, player spawn cells, rewards and local saves are preserved.

Scouts, standard guards and heavies have different shot damage and cadence;
the values above are gameplay defaults because no exact damage values were
specified. Heavies also have two health points. Nearby guards investigate
gunfire without shooting through cover. Opposing and crossing doorway traffic
yields predictably and followers can back out of a queue.
