# Apex Assassin — special enemies and missions

This v0.7.2 update preserves the existing 100 levels, enemy counts, player roster,
weapons, upgrades, saves, sounds and original six enemies. New specialists rotate
in gradually; one Boss takes an existing slot on every 20th level. Level 100
features all twelve classes. Every enemy, **including the Boss**, still falls to
one melee hit; cover still blocks attacks and grass hides the player until body
contact. Projectiles fired before concealment can still land as before.

## New enemy abilities

- **Medic / Med-Gun:** periodically heals a nearby, living ally in line of sight
  and briefly boosts that ally's damage and firing rate. Cannot revive anyone or
  prevent a one-hit melee takedown.
- **Engineer / Tesla-Gun:** a blue area shock on impact or expiry deals damage
  and briefly slows the player. Walls block the shock.
- **Bomber / GL-40:** an orange explosive round deals radial damage on impact or
  expiry. Walls block the blast.
- **Shield / Pulse-SMG:** armor-piercing shots scale against the player's bonus
  maximum health. The original game has no separate armor bar; no health upgrade
  is deleted, and shots never penetrate walls.
- **Mutant / Bio-Rifle:** a successful hit applies three timed poison ticks;
  damage respects the usual invulnerability and defeat logic.
- **Boss / Plasma-Rifle:** a powerful, slower-firing plasma shot.

## Home and missions

Tap the displayed character to open the same character-selection screen.
The title and separate CHARACTERS button are removed from home; the separate
splash screen is unchanged. The Start button pulses while retaining its shine.

Swipe the mission cards, including from a claim button, to see eleven new
one-time milestones. Their progress derives from existing kills, completed
levels, perfect wins, and three-star level results. Old mission flags, rewards,
claimed states and all other saved progress remain intact. A claim cannot pay
twice. Some new milestones may already be complete for an existing player.

Grass uses complete 40-unit tiles (previously 32), with bigger connected
patches where the original geometry allows. Stylized dimensional blood retains
the existing persistent ground splatters and temporary bloody footprints.

Use `bash tools/run_red_scarf_tests.sh` with `GODOT` pointing to Godot 4.7.2 to
run the isolated-save gameplay, migration, art, grass and UI regression suite.
