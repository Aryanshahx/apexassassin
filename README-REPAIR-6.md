# REPAIR-6

Based on public REPAIR-5. Superior actors use the intact supplied portraits with
smooth local arm motion; selected weapons remain separate and follow the fist.
The Standard character's unrelated leg/foot sprites are not drawn on Superior
looks. No saved selections or unlocks are reset.

Grass gameplay patches remain complete 2×2 or 3×3 squares. A visual underlay
under contacted props fills transparent edges; it never adds stealth tiles or
changes collision or AI. Home displays cash, diamonds and keys as icons and
amounts without captions or transient messages. Gameplay puts those three
resources on one evenly spaced, safe-area-aware row.

The update uses the user's `hurt.mp3` for actual damage when present, respecting
sound settings; the existing `hurt.wav` is the fallback. The guarded updater
copies only the exact user-supplied file from Downloads, without overwriting a
different destination. The updater does not contain that recording. A separate
`--publish` explicitly publishes the reviewed update and that copied MP3 to the
public repository; build workflow dispatch is separate.

Settings shows `BUILD: REPAIR-6` when this source has been built into an APK.
The regression suites use disposable synthetic saves. GPU rendering is tested
off-screen; phone behavior still requires checking the actual installed APK.
