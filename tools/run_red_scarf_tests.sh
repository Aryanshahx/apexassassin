#!/usr/bin/env bash
# Test in isolated temporary user-data directories. Never run suites against a real save.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
GODOT="${GODOT:-godot}"
command -v "$GODOT" >/dev/null || { echo "Godot 4.7.2 not found: $GODOT" >&2; exit 1; }
case "$("$GODOT" --version)" in 4.7.2.*) ;; *) echo 'Expected Godot 4.7.2.' >&2; exit 1;; esac
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/apex-red-scarf-tests-XXXXXXXX")"
trap 'rm -rf -- "$TEST_TMP"' EXIT
mkdir -p "$TEST_TMP/import/data" "$TEST_TMP/import/config" "$TEST_TMP/import/cache"
# Import modifies only the project import cache; XDG paths isolate user settings and saves.
XDG_DATA_HOME="$TEST_TMP/import/data" XDG_CONFIG_HOME="$TEST_TMP/import/config" \
  XDG_CACHE_HOME="$TEST_TMP/import/cache" "$GODOT" --headless --path . --import
# These are the existing gameplay/progression suites, plus the new visual/save test.
# The old smoke/home/roster tests describe retired visuals. Adapted combat and
# locker tests preserve their gameplay checks but expect the new preview artwork.
# The randomized legacy traffic stress test is a separate optional diagnostic.
tests=(depth_grass_polish_test superior_bonus_grass_test special_enemies_and_missions_test background_music_test ten_character_selection_test ten_character_grass_test grass_contact_one_hit_test world_effects_and_ui_test movement_test roaming_test transition_test red_scarf_combat_test
 collision_test splash_test layout_test gate_test ten_characters_enemies_test player_path_test
 loot_speed_test button_feedback_test tap_audio_import_test five_looks_locker_test
 v72_deferred_locker_test v72_progression_test v72_key_audio_import_test
 five_looks_legacy_combat_test v64_path_stress_test
 v65_combat_audio_test v66_mechanics_test v67_behavior_test v71_visual_sync_test)
for test in "${tests[@]}"; do
  [ -f "tests/$test.gd" ] || { echo "Required test is missing: tests/$test.gd" >&2; exit 1; }
  sandbox="$TEST_TMP/$test"; mkdir -p "$sandbox/data" "$sandbox/config" "$sandbox/cache"
  echo "--- $test (isolated user data)"
  APEX_REDSCARF_TEST_ROOT="$sandbox/data" APEX_FIVE_TEST_ROOT="$sandbox/data" XDG_DATA_HOME="$sandbox/data" \
    XDG_CONFIG_HOME="$sandbox/config" XDG_CACHE_HOME="$sandbox/cache" \
    timeout 300 "$GODOT" --headless --path . --script "tests/$test.gd"
done
for seed in 70000 71000 72000; do
  sandbox="$TEST_TMP/v71-start-$seed"; mkdir -p "$sandbox/data" "$sandbox/config" "$sandbox/cache"
  APEX_SAFETY_SEED="$seed" XDG_DATA_HOME="$sandbox/data" XDG_CONFIG_HOME="$sandbox/config" \
    XDG_CACHE_HOME="$sandbox/cache" timeout 120 "$GODOT" --headless --path . --script tests/v71_start_safety_test.gd
done
echo 'Twelve-enemy abilities, missions, ten-character, complete-tile grass, world effects, UI, collision, combat and preserved-gameplay suites completed using isolated synthetic saves.'
