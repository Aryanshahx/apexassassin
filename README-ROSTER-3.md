# Apex Assassin 0.7.2 — Roster, grass and Special Rewards

This update is based on the published Depth-2 source. It changes appearance and
presentation without resetting player data or changing the Android package,
version, signing configuration, gameplay audio, weapon choices or level files.

## Ten replacement Superior characters

The new supplied roster is used in row order. The internal IDs below are the
existing save slots; IDs, diamond prices, speed/health bonuses and existing
unlocks remain exactly as before. Visible names are descriptive because the
reference picture does not give names.

| Save slot (unchanged) | New name | Price | Bonus |
| --- | --- | ---: | --- |
| crimson_blade | Mummy | 20 diamonds | +10% speed |
| frost_tech | Flame Fighter | 20 diamonds | +10% health |
| gold_knight | Hazmat | 30 diamonds | +15% speed |
| yellow_goggles | Blue Brute | 30 diamonds | +15% health |
| green_ghillie | Neon Robot | 40 diamonds | +20% speed |
| blue_swat | Purple Assassin | 40 diamonds | +20% health |
| purple_reaper | Hooded Clown | 50 diamonds | +25% speed |
| red_samurai | Jester | 50 diamonds | +25% health |
| neon_cyber | Zombie | 60 diamonds | +30% speed |
| warrior_monk | Golden Fighter | 60 diamonds | +30% health |

The extracted figures keep their supplied two-handed poses. Existing melee
weapons are separate and still attach behind the gripping fist, with running,
shoulder and wrist motion. The source does not provide unseen limb frames, so
the new illustrated torso and arms move as a coherent drawing.

## Grass, scrolling and rewards

* Every one of the 100 authored levels now chooses 2–3 patches of connected
  grass. Each is a filled 2×4, 4×2, 2×6 or 6×2 rectangle of 32-unit tiles:
  two or three touching box-sized sections, never a single 2×2 box. The
  existing prop contact, solid geometry, pathfinding and guard-search rules
  are kept.
* The mission and character-selection scrollbars are not drawn; touch drags,
  mouse-wheel scrolling, selection and claim buttons still work.
* The Special Rewards reference is the real interactive nine-crate board.
  Each saved pick reveals its actual prize, used keys dim, an interrupted
  board resumes, and the existing three-key/three-pick reward rules are kept.
* Settings displays `BUILD: ROSTER-3`. That identifies a built APK; source
  installation alone does not update a phone.

The isolated test suite includes the new roster, weapon-grip, old-save,
100-level connected-grass, hidden-scrollbar/touch, exact three-pick and board
resume checks. It also retains the existing contact, guard-path and collision
regressions.
