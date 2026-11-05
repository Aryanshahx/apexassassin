# Depth-2 build verification and opening patrol safety

This small follow-up is based on public commit `b861edd790596fd7913d9a123948264056fbadc7`, which already contains the prop-attached grass, depth, UI and character-polish update.

- A reproduced level-3 start-safety failure is fixed by selecting opening patrol destinations away from the idle spawn for the first three seconds. Guard vision, combat, pursuit, body contact, authored spawn points, obstacle geometry and routes are unchanged. Players who move can be seen and pursued immediately.
- Settings now shows **BUILD: DEPTH-2**, so the person using the Android app can tell this APK from an older download. The marker is informational and does not affect saves.
- The test runner now reports a failing test or start-safety seed as a GitHub Actions annotation. All tests remain enabled and failures still stop the APK build.
- The updater's `--verify-install` is a read-only verification of the local source files and the previous update. It does not verify the Android APK. The Settings marker is the on-device check.

The installer backs up changed project files, will not overwrite conflicting files, and neither includes nor modifies audio, saves or signing keys. `--apply`, `--publish`, `--verify-install` and `--check-public` are distinct operations. Publishing is public; building an APK is a separate workflow dispatch. If Android reports a signature mismatch, do not uninstall or clear data; obtain help preserving the existing signing key and saves.
