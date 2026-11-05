# Apex Assassin — Gallery 4 source update

This update applies to the published ROSTER-3 source at Git commit
`09c84c9923cb95563fd6fc802db4b1c098eccca5`.

* Two or three connected grass patches per level now sit in walkable gallery
  paths. Some are square. Every level has at least one open-path patch away
  from props, and the screenshot-matched level has three reviewed placements.
* All ten Superior characters use separate visible upper-arm, forearm, weapon
  hand, free-arm and free-hand layers cut from the supplied roster. Their joint
  rotations use Standard's walking and attack animation, and the selected
  weapon remains attached behind the gripping fist.
* Walls and props have a larger shaded 2.5D front and sides, with bounded
  camera-relative top-face movement. Art remains within the existing cover
  footprint; movement, vision, guard pathing and collision rectangles are not
  changed.
* Existing Superior slot IDs/bonuses, rewards, progression and scrolling are
  retained. No audio, saves, signing configuration, or credentials are part of
  this update.

## Safe workflow

The standalone updater defaults to read-only compatibility checking. Use
`--apply` to install, then `--verify-install` to verify the **local source**.
Publishing with `--publish` is a separate operation that immediately pushes
reviewed changes to the public GitHub repository; it does not start an APK
build. `--check-public` is a separate read-only public/source check. Dispatch
an Android workflow only after independently reviewing and approving that
publication and the workflow's public artifact. The phone's Settings build
marker is `BUILD: GALLERY-4` only after an APK built from this update is
installed. Source installation by itself never updates the phone.

This project uses debug APK signing in its current workflow. A different APK
signature cannot update an existing install; retain app data and resolve the
signing mismatch rather than uninstalling or clearing data.
