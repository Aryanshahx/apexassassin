# Depth, grass and animation polish

This update keeps the top-down controls, levels, collision geometry, saved
progress, character unlocks, weapons, mission claims, bonus stages and all
audio files. It is applied on top of public commit `95e5a4fe`.

- Each normal map has two or three compact grass spots. Each spot consists of
  connected 32-unit tiles and meets a visible prop edge; there are no loose
  one-by-three strips and grass creates no collider. The four-tile block is
  still one wooden-box-sized area. Entry/exit sounds and bounce are retained.
- An alerted guard can investigate a reachable tile inside a patch it saw the
  player enter. Grass still conceals the player's live position, and walls and
  guard body-clearance rules still apply.
- Cover receives a small movement-responsive perspective offset over its
  fixed footprint; it does not change movement, collision or aiming. Six
  additional prop appearances enter progressively after levels 10, 25, 50 and
  75, without adding obstacles or obstructing a route.
- The visible FIND KEY text is removed; the existing key icon still opens the
  optional path-to-key guide when a key is on the floor. Money/diamond loot
  remains visible and is credited once, without the kill-time coin sound.
- Character legs are hidden at rest and shown in motion. The Gold and Flame
  Guard arms have coherent hand/shoulder layers; stray disconnected artifacts
  are cleaned from the ten Superior figures. Selected weapons stay independent.
- Purchase and other notices appear within the center of the device safe area;
  available mission claim buttons receive a shine that stops after claiming.

The updater and publication helper include no MP3s or saves. Neither installs,
replaces, stages nor publishes any audio; the existing public audio remains
unchanged. Installation and publication are separate. APK build dispatch is a
third separate step.
