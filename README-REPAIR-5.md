# Apex Assassin v0.7.2 — REPAIR-5

This source update builds on the public GALLERY-4 commit. It does not reset the
player's data, replace audio or signing keys, publish code, or install an APK.

- Superior characters use connected body, arm and hand layers derived from the
  supplied roster artwork. Weapons remain attached to the moving fist.
- Grass consists only of filled 2×2 or 3×3 squares of the existing tiles. Each
  authored level has an open gallery square and a centred, flush prop-edge
  square without changing collisions or grass concealment.
- Cover uses the original shaded artwork at its existing footprint. It no
  longer shifts or redraws in response to player motion.
- The locker is a screen of nine actual controls, not a pasted reference board.
  A new board saves one currently locked Superior character and its slot. If
  found within the three picks, that exact character is unlocked and can be
  equipped from Superior. If the player bought it meanwhile, its full price is
  paid as diamonds instead; if all are owned, the board awards diamonds.
- Unfinished pre-update boards keep their original Elite reward, revealed
  prizes, keys and recovery behavior. Existing Elite and Superior unlocks are
  retained. A failed save does not reveal a reward or consume a key.

Run the guarded updater's default read-only preflight before using `--apply`.
Local source installation is separate from publishing and building an APK.
`--publish` commits and immediately pushes reviewed files to **public** GitHub
without another typed confirmation. Workflow dispatch is a separate action.
An APK signed with a different key cannot replace the installed app; stop and
check the signing configuration rather than uninstalling or clearing data.
After an APK built from this update is installed, Settings should display
`BUILD: REPAIR-5`. A source-only installation does not change the phone APK.
