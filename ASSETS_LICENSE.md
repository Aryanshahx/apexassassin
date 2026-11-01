# Asset provenance and licensing

The earlier Apex Assassin modular character parts, UI artwork, synthesized
sound effects, and project code were created for this project. The Warehouse
Depot assets are extracted from the concept image supplied with this project.

The v0.5.5 character cards, player poses, and guard poses under
`assets/reference/` were derived from the user-supplied screenshots preserved
in `art_source/reference/`. The cards have their lock icons retouched; the
transparent character and guard images use the screenshot RGB pixels with
computed alpha masks. They are reference-derived images, not newly drawn
originals, and the animations are new approximations made from those stills.

The v0.5.6 twelve additional AI-generated designs were removed from the game in
v0.5.8. Removed selections fall back safely; the designs are not shipped in the
current project or playable roster.

`art_source/selector/concept.webp` is a 720-pixel working copy of the user-selected AI-generated UI concept
and preserves its pixels losslessly. The game uses an edited background from it;
the live buttons, labels, statistics and portraits are Godot controls. The
concept includes a sample reference-derived character, so review its provenance
too before distributing the source concept.

The rights and licensing of material appearing in the screenshots have not been
established. **Check that you have permission from the relevant rights holders
before publishing the repository or distributing builds that contain these
assets.** No license to the underlying screenshot artwork is granted here.

The bundled Baloo 2 font is licensed under the SIL Open Font License 1.1; see
`assets/fonts/OFL-Baloo2.txt`.

The v0.5.7 guard body, boot, and rifle layers under
`assets/reference/guards/parts/` are cut from the same user-supplied guard
stills, with the region beneath the separated rifle inpainted. Their animation
is newly reconstructed, not original frames. `tools/build_guard_layers.py`
regenerates the layers from the preserved still sprites.

The v0.5.8 concept was superseded by the selected classic-style v0.5.9 home.
The current `assets/home/home_bg_v59.jpg` is a colour-adjusted version of the
project's earlier `home_bg.jpg`. Its controls and values are built in Godot,
not baked from the concept. `tools/build_home_v59_background.py` regenerates it.
The player boot layers in `assets/reference/characters/parts/` are cut from the
same screenshot-derived stills; `tools/build_reference_gait.py` regenerates
them. The movement is newly reconstructed, not original animation frames.

## v0.6.0 home redesign

`assets/home/character_stage.svg` is a new vector spotlight created for the
selected v0.6.0 home concept. The home continues to display the project's
warehouse and the player's actual selected character, so the screenshot-derived
art and other rights cautions above still apply. Obtain necessary rights before
publishing.


The v0.6.1 Android launcher icon is derived from the AI-generated character
logo selected by the user; it contains no text. The two small splash-label
patches replace text on the existing project splash image; the rest of that
image is unchanged. Review the rights of all original and screenshot-derived
assets before publishing; selection does not establish third-party rights.


## v0.6.4 warehouse and animated heads

The new `art_source/environment/v64_floor_concept.webp` and
`art_source/characters/vault_phantom_topdown.webp` are AI-generated concepts
created for this update. The floor tile, key artwork and Vault Phantom sprite
are reconstructed for gameplay by `tools/build_v64_assets.py`. The twelve
reference-character heads and two guard heads remain derived from the earlier
user-supplied screenshot artwork; their separated layers and animation are new
approximations. The provenance and permission cautions above still apply.
The installed user-provided tap audio is preserved unchanged; rights to publish
that recording must be confirmed separately before any GitHub push.


## v0.6.5 supplied warehouse reference and audio

`art_source/environment/v65_user_warehouse_reference.jpg` is the user's supplied
warehouse screenshot. `tools/build_warehouse_v65_art.py` extracts and tiles
parts of it for floor, walls, gate and crate textures. The screenshot may depict
third-party game artwork; ownership and permission are not established. Check
rights before sharing or publishing any screenshot-derived files or builds.

The updater does not contain or create `stab.mp3` or `suspect.mp3`: it copies
those exact recordings from the user's Raspberry Pi `~/Downloads`. The earlier
`ui_tap_audio.mp3` is left untouched. Confirm rights for all three recordings
before separately reviewing and confirming a GitHub publication.


## v0.6.6 walkthrough-inspired layouts and new recordings

The first five level layouts are independently adapted from the visible portions
of a publicly available 2020 Hunter Assassin walkthrough
(https://www.youtube.com/watch?v=EFnL3VUJ9fk), not extracted assets or exact
reproductions. The full boundaries and placements are not visible. The design
reference may be subject to third-party rights; check permissions before sharing
or distributing derivative material. Existing screenshot-derived assets remain.

The v0.6.6 updater contains none of the user's MP3 recordings. It copies
`stab2.mp3` and `suspect2.mp3` directly from the Pi's `~/Downloads`, and leaves
`stab.mp3`, `suspect.mp3`, and `ui_tap_audio.mp3` unchanged. Confirm rights for
all recordings before separately reviewing and approving a GitHub publication.
