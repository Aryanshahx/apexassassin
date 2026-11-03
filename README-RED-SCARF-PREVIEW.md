# Apex Assassin 0.7.2 — red-scarf preview

This is a **temporary test-art integration**, not final independently recreated artwork. The body, head, arms, hands, knife and home portrait contain pixels derived from your supplied reference image. The legs and boots are separately drawn draft pieces. Do not describe these assets as independent final art or publish them without confirming your rights.

The selected red-scarf fighter is the sole **playable appearance**. The stronger elbow movement follows the approved test; shoulders, ankles, legs, head and hands also move. The player's combat remains melee-only, guards retain their guns, and no throwing was added. Existing character IDs, selected bonuses, weapons, currency, level progress and key/save code are not reset. The old selection screen is hidden, so previous loadout bonuses stay active but cannot be changed through that screen during this preview.

**Known visual limitation:** every equipped weapon is still displayed as the reference knife, even when another unlocked melee weapon's existing statistics are active. This is not a completed weapon-art implementation.

The update does not replace or modify any audio, key artwork, keystore, save, `project.godot`, Android export preset or version. It changes the level and home visual integration and replaces the known v0.7.2 Android workflow, backing up the original changed files under `.apex-backup/`. It adds the preview art, rig and tests. It does not run Git, commit, push, publish or build an APK on your behalf. The APK workflow is manual and the test image and any included audio will be present in its GitHub artifact.

## Apply on the Pi

Download the single `apex_v072_red_scarf_preview.sh` installer to `~/Downloads`. Replace the project path below if yours is different:

```bash
bash ~/Downloads/apex_v072_red_scarf_preview.sh /home/aryan/apex-assassin
```

That first command is a read-only compatibility check. The script refuses to overwrite unknown or locally modified integration files. If the check succeeds and you accept the temporary reference-derived art, apply it explicitly:

```bash
bash ~/Downloads/apex_v072_red_scarf_preview.sh /home/aryan/apex-assassin --apply --accept-reference-art
```

Close Godot while applying. Your changed files are backed up under `.apex-backup/`. The installer never reads or writes game saves or personal recordings; it does not access any signing key. Back up your game saves separately before running any test build. This has been tested against reconstructed v0.7.2 code with synthetic saves, not against your physical Pi, phone, or real save.

## GitHub build — manual and review first

The installer replaces the existing **known** Android workflow with a manual test workflow. It requires all seven existing recordings in the GitHub checkout, verifies the two previously supplied key recordings, and fails rather than quietly creating a silent APK if they are missing. Nothing in the installer uploads those recordings. Putting audio or temporary reference-derived art in GitHub may expose it to people with access to your repository or artifact; check the repository visibility and your rights and explicitly approve each upload before doing so. If you do not want that upload, do not upload the recordings or run this audio-inclusive workflow.

The previous `tools/publish_github.sh` does **not** know about the new preview files. After reviewing your local repository and ensuring the complete 0.7.2 source is already tracked, you can stage only these update paths:

```bash
cd /home/aryan/apex-assassin
git status --short
git add -- scripts/game/level.gd scripts/ui/home.gd .github/workflows/android.yml \
  scripts/game/red_scarf_preview.gd assets/characters/red-scarf-preview/ \
  tests/red_scarf_preview_test.gd tests/red_scarf_combat_test.gd \
  tests/red_scarf_lockers_test.gd tests/red_scarf_legacy_combat_test.gd \
  tools/run_red_scarf_tests.sh README-RED-SCARF-PREVIEW.md
git diff --cached --stat
```

Review the staged files, any other already-staged changes, repository visibility, prior local commits, and your permission to publish the artwork and recordings. If you decide to commit only these preview paths, the explicit path list avoids including unrelated staged files:

```bash
git diff --cached --name-only
git commit -m "Add red scarf preview" -- \
  scripts/game/level.gd scripts/ui/home.gd .github/workflows/android.yml \
  scripts/game/red_scarf_preview.gd assets/characters/red-scarf-preview/ \
  tests/red_scarf_preview_test.gd tests/red_scarf_combat_test.gd \
  tests/red_scarf_lockers_test.gd tests/red_scarf_legacy_combat_test.gd \
  tools/run_red_scarf_tests.sh README-RED-SCARF-PREVIEW.md
```

Inspect `git remote -v` and **all** local commits that would be pushed; a push can include older commits too. Only after you approve their contents and repository visibility, push your current branch with `git push origin HEAD`. Neither the installer nor these commands stage any audio; the required recordings must already be in the checkout or be added separately only after your approval.

Once the workflow exists on the default branch, open GitHub **Actions → Android APK - red scarf test → Run workflow**, select the branch, and check the approval box. Download the `apex-red-scarf-preview-debug-...` artifact when it succeeds. It is not a release or a store-signed APK. No GitHub run or actual APK build has been performed by this package. A separate, non-blocking legacy traffic stress diagnostic may report a guard stall; one 5.27-second wait was observed in reconstructed v0.7.2 testing. Its result is not hidden and should be reviewed.

The workflow expects `ui_tap_audio.mp3`, `stab.mp3`, `suspect.mp3`, `stab2.mp3`, `suspect2.mp3`, `pickkey.mp3` and `unlockkey.mp3` under `assets/audio/` in the checkout. If any are absent, it stops with an error; it never copies them from the Pi or manufactures substitutes. The exact key-recording checksums match the previous key/audio repair. The GitHub repository must also contain the other files used by the existing v0.7.2 tests.

A newly generated GitHub debug signing key will generally be different from your installed app's signing key. Android may therefore refuse to update the existing installation. Do not uninstall the old app or clear its data to work around this.

## Changes

- Red-scarf test appearance and stronger elbow/shoulder/ankle animation.
- Single-player appearance and temporary test portrait; existing game data and audio are left in place.
- Compatibility-checked installer, original-file backups, isolated synthetic-save tests and manual GitHub debug APK workflow.
