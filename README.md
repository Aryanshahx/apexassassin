# Apex Assassin

v0.7.1 — user-selected environment art and source-priority layouts, while preserving gameplay, recordings and save progress.

Original top-down stealth action game for Godot 4.7.2, built for Raspberry Pi 5 / Ubuntu and Android.

## Environment art and supplied layouts

The 29 compact textures in `assets/environment/v71/` are built from the
user-selected AI-generated floor, wall, crate, barrel, sandbag and hazard
category images, with additional deterministic recolours and details. Eight
floor themes share this visual direction. The selected overall scene is a
style reference, not a sprite sheet. Raw selected concepts are kept separately
and are not included in the updater. The 212 supplied v0.7.0 PNGs are retained
for rollback but are not used by the new level backplate.

The 100 statically recovered level records reference 45 supplied grids and 64
unique grid/flip combinations. The adapter preserves their solid/open cell
pattern at full source-cell size; source solids may share edges. The existing
32-unit navigation and collision clearances remain. `NN` is conservatively
solid because its original semantics are unknown. These maps are adaptations,
not a verified reconstruction of the original runtime.

Supplied rosters take priority: 90 configurations contain 611 guards and nine
bosses. Ten configurations have no roster, so those levels use 110 guards from
the previous playable project instead, for 730 guards/bosses in total. Source
coordinates are transformed and projected onto reachable, separated positions
when necessary. Of 620 hints, 530 are exact and 603 are within 64 world units
of the transformed hint. The seventh guard in level 95 is moved farther for
start safety; player start positions are selected or adjusted independently.
Boss records use the project's existing elite profiles; original boss abilities
are not known. Player/guard abilities and the 100 level IDs and clear rewards remain. Per-kill
totals can change when source-priority guard counts differ from the old roster.

The source door, chest and trap entries are retained in the recovered data, but
their original runtime behavior was unavailable and has not been recreated.
The existing project's keys and lockers remain separate mechanics. Selected
hazard markings and floor details are cosmetic, not newly added traps.

`apex_v071_update.sh` updates a verified v0.7.0 project. It checks conflicts
before writing, backs up replaced files, preserves personal recordings, saved
progress and unrelated files, and never commits or pushes. The preview runs in
an isolated project and does not touch Raspberry Pi saves. Rights to supplied
maps, older art and recordings are unverified: review `ASSETS_LICENSE.md` and
obtain required permission before publication or distribution.

## What is in this build

- **12 reference characters**, immediately available in the character selector, with the
  speed/health bonuses shown in the supplied screenshot. You play as one at a time.
- The twelve v0.5.6 `new01`–`new12` designs have been removed from the game.
  Saves that selected one fall back to Ronin; other progress is preserved.
- **10 legacy character IDs**, costs, bonuses, selected state and unlocks remain supported.
  Their visuals now use the reference art style.
- **Vault Phantom**, an original 23rd character, can only be found in the three-key lockers. Unlocking it does not change your selected assassin.
- **17 knives**, with their existing damage, speed, reach and unlock rules.
- **Reconstructed movement**: separate boot pivots for player and guards, smoothed
  facing, separately animated heads, idle, run, attack, shoot, hurt and death.
  The node animation is reconstructed from still images, not original frames.
- **Smoother steering**: route replans do not pull actors back to their current
  cell centre; cached obstacle-corner visibility routes find near-shortest
  paths around cover, with a sub-pixel clearance for safe cornering. Touch-emulated
  mouse events are de-duplicated, flashlight rays use exact obstacle intersections,
  and the remaining walkable path is highlighted.
  A small arrowhead marks the end of that actual route; there is no tap ring.
  Taps on cover resolve to nearby reachable floor.
- **More evenly spread guards** start and roam across reachable map regions,
  with collision-checked recovery and cooperative yielding when a queue jams.
  The guard that first sees the player pursues alone; after a short reaction
  delay, actual gunfire alerts living guards in the same connected traversable
  area. A kill, even a silent backstab, alerts guards within 320 world units.
  Other flashlights do not replay the suspect sound during an existing alert.
  With no renewed sighting or gunfire, a short pursuit becomes a finite search
  and then patrol. Alerted guards briefly track the live target, but only shoot
  with direct, in-range line of sight; walls stop vision and bullets.
- **Progressive enemy types**: scout, standard guard and heavy are joined by a
  ranger from level 8, a breacher from level 25 and a captain from level 50.
  Damage is 25% higher than v0.6.6, still scales gradually with level, and
  armor increases at higher tiers. All enemy shot intervals are halved (twice the previous firing rate); a red
  `?` marks alert, investigation and search.
- **Visible health**: the player starts at 1,000 base health, shown in a thinner
  green bar above the character. Existing character health bonuses and saved
  health upgrades continue to apply (+100 per upgrade).
- **Selected environments and supplied layouts**: eight new floor themes,
  selected-style walls, cover and floor details; 100 adapted source layouts,
  with source-priority rosters where available and explicitly marked fallbacks.
- **Faster movement**: player speed, including saved bonuses and upgrades, is
  20% above v0.6.3. Alerted chase speed is 15% above v0.6.3 (2.07× patrol);
  investigation remains 1.45× and bullets remain 660 units/s.
- **Money and rare diamonds**: each kill immediately saves +10 cash (+20 for a
  heavy, plus +5 for a silent kill). Some levels have one diamond carrier; a
  carrier awards one diamond on defeat. Existing saved gems retain their value
  and are shown as diamonds. Money, diamonds and keys share one straight HUD
  row; kill rewards update there without kill-only floating loot effects.
- **Random-level keys**: keys appear in a seeded subset of levels. A FIND KEY
  button highlights a walkable route when a key is present. Three collected keys
  open a 3×3 board with three unique picks. Most lockers award diamonds; one
  randomly placed locker may unlock Vault Phantom. Keys, the board and each
  prize are saved immediately and an unfinished board returns on the home screen.
- **Button tap feedback**: buttons briefly compress and play the player's own
  `assets/audio/ui_tap_audio.mp3`, respecting the existing sound setting.
- **Personal combat sounds**: the already-installed original tap, `stab.mp3`,
  `suspect.mp3`, `stab2.mp3`, and `suspect2.mp3` are all kept byte-for-byte.
  Stabs use `stab2` and the first flashlight detection in an alert uses
  `suspect2`; both respect the existing sound setting. This update never copies,
  replaces or publishes recordings.
- **Blood-only kills**: a kill leaves a blood splatter until the level ends or
  restarts, with no corpse, poof, ring or floating kill reward. Saved rewards
  and counters are unchanged.
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
- **100 validated adapted layouts** retain the existing level IDs and clear rewards; guard counts follow supplied rosters where available.
- User-selected **classic-style home**: the old top-down warehouse backdrop,
  purple character/knife cards, three mission rows and a large gold Start button.
  Resources, selected character portrait, progress, mission claims, wheel,
  settings, upgrades, level select, stars and local save are all live controls.
  Diamond and cash icons, captions and values share a straight home-screen row;
  the example numbers from the design are not baked into the game.
- Level and depot resources are cached; static map layers are retained, and
  off-screen/near-cover guard beams are culled or cached to reduce work.
- Existing sound effects and mobile haptics, plus the locally supplied button-tap MP3.
- **Debug-only Android APK workflow** for GitHub Actions. No release keystore or signing secrets.

## Update on Raspberry Pi 5

Place `apex_v071_update.sh` in `~/Downloads` and run it on the existing,
completed v0.7.0 project:

```bash
bash ~/Downloads/apex_v071_update.sh /home/aryan/apex-assassin
```

The installer checks affected files before writing, refuses conflicting local
edits, backs up replaced files, and preserves all five installed MP3s and saved
progress. It does not require or copy recordings from `~/Downloads`. Missing
installed sounds stop the update safely; restore your own files and retry.
It does not commit or publish. The optional code-only ZIP is not a full game.

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

Stay out of flashlight cones. The detecting guard chases first; gunfire alerts guards in the same connected area and kills alert nearby guards. Pursuit and search end without renewed detection or gunfire. Guards shoot only with a direct line of sight; use cover to block shots.

## Tests

```bash
python3 tools/test_v71_source_integrity.py
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
# Additional behavior and v0.7.1 visual/start suites (each directory must be isolated):
for test in v64_lockers_test v64_combat_test v64_path_stress_test v64_traffic_stress_test v65_combat_audio_test v66_mechanics_test v67_behavior_test v71_visual_sync_test v71_start_safety_test; do
  TEMP_DATA="$(mktemp -d)"
  XDG_DATA_HOME="$TEMP_DATA" godot --headless --path . --script "tests/$test.gd"
  rm -rf "$TEMP_DATA"
done
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
staged changes, stages only the update paths (never personal audio), shows the
proposed commit and asks for confirmation. Authenticate Git with GitHub first (for example, `gh auth
login`); never put access tokens in the script. Check `ASSETS_LICENSE.md` and
make sure you have permission to publish any artwork and recordings already in the repository before publishing. It does not force-push or automatically resolve divergent history.

Then open:

```text
https://github.com/Aryanshahx/apexassassin/actions
```

The **Android APK** workflow runs tests and uploads:

```text
apex-assassin-debug-<commit-sha>
```

Download the artifact and install the APK on an arm64 Android device.

## Optional: rebuild the selected art and maps

All playable PNGs and adapted level data ship in the update; regeneration is not
needed to play. The seven selected concept/category images are intentionally not
bundled. If you retain them privately under `art_source/v71-selected/`, install
Pillow and NumPy and run `python3 tools/build_v71_selected_art.py` to rebuild the
selected-style textures. Avoid publishing concept images without reviewing rights.

To reproduce the adapted catalog without overwriting the playable one:

```bash
python3 tools/import_supplied_maps_v71.py data/source_maps/v70/v069-level-catalog.json /tmp/rebuilt-v071.json
python3 tools/test_v71_source_integrity.py
```

Older art and layout generators remain historical; their output is not the v0.7.1
level catalog. The compiled source library is never needed or executed.

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

## v0.7.2 — restored enemies, supplied characters, and the vault

- All 100 level IDs, clear rewards, supplied layouts, and approved v0.7.1
  environments remain. Each level has **at least** its v0.7.0 enemy count;
  where v0.7.1 had more, that higher count remains. The 730 existing
  source/fallback guards are retained and 336 supplemental guards use the same
  patrol, pursuit and combat code (1,066 total). Later levels add a little
  more damage and fire-rate pressure on top of the existing armor progression.
  The player start in level 75 and two new level-28/76 guards were adjusted
  for tested start/traffic safety; original source guard hints were not moved.
- Six supplied player appearances and six supplied guard appearances replace
  the visible artwork. The supplied images were static RGB concept sheets;
  transparent cutouts and simple body/knife animations are reconstructed, not
  original frames. Guns and the shield are **visual only**: knife combat and
  the existing guard AI remain. Five new looks are free; Elite is the unique
  three-key prize. Old character unlock IDs and selected bonuses are kept.
  Use **BONUS** in the selector to cycle and re-equip saved legacy stat profiles
  on the new six appearances. An already-earned Vault Phantom grants Elite.
- Three keys queue a saved vault board. It appears only after completing a
  level, never immediately on pickup, retry, loss or returning home. The
  counter displays 3/3 while queued. Eligible/partially opened boards, their
  secret slot and every credited reward survive exit and reload. Pre-v0.7.2
  pending boards remain eligible so no old rewards get stranded.
- The key graphic comes from the supplied `KeyIconB.png`. The installer copies
  the exact files `~/Downloads/pickkey.mp3` and `~/Downloads/unlockkey.mp3` from
  the Pi into `assets/audio/`. It refuses missing files or conflicting existing
  destination recordings without overwriting anything. The updater contains no
  private audio or saves. Open the project in Godot after installation to
  import the two MP3s; key pickup and locker opening use them when present.
- An ordinary `tools/publish_github.sh` run **does not publish** the two new
  recordings. A GitHub-built APK from that code-only push will therefore lack
  these two sounds unless they are already in the repository. If you own the
  recordings and deliberately wish to upload them, use
  `APEX_PUBLISH_KEY_SOUNDS=1 bash tools/publish_github.sh "Apex Assassin v0.7.2"`.
  The publisher explicitly asks permission to upload the two MP3s, then asks
  separately to confirm rights and the final commit/push. It never stages the
  older personal recordings or audio import metadata. Do not opt in if the
  recordings should remain private, especially on a public repository.

User-supplied art, maps and source-derived configuration have unverified rights;
review `ASSETS_LICENSE.md` and confirm permission before any publication or
redistribution. This update cannot guarantee performance on a particular Pi or
Android device; debug APK signing may differ from an installed APK.
