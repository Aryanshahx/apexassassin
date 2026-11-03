# Apex Assassin v0.7.2 — five-character draft

This is a **private test draft**, not independently recreated final art. The four new characters are AI-edited closely from the supplied references, with a flat background removed and separate draft animation layers. The retained red-scarf character includes reference-derived pixels. The five weapon icons and adjusted grip graphics come from the selected Google Drive images. Do not publish these assets without confirming the right to do so and obtaining the owner's explicit approval.

## What changes

- The playable selector shows Red Scarf, White Hood, Blue Tactical, Green Fighter and Yellow Hazmat. Previous looks are hidden from the selector; their files and entitlement data are not deleted.
- The weapons selector shows Aurora Fang, Thor Hammer, Wolverine Claws, Dracula Blade and Leviathan Axe. Each selected graphic follows the hand during attacks. All five use the previous selected melee weapon's combat statistics; the choices are free visual changes, not new damage/range balances. Earlier weapon files and unlock data remain in place for rollback.
- Player attacks remain melee-only; guards keep their guns. No throwing is added. The red-scarf elbow/shoulder/ankle motion remains; the new characters have draft joint layers and matching black boots.
- Cosmetic selections are stored in a separate `user://apex_five_look_draft_v1.json`. The existing GameState and its save schema, character bonuses, selected legacy equipment, currency, key history, levels, audio and signing key are unchanged. An older build ignores the cosmetic sidecar; the original progress is not migrated or replaced.
- The exact key-art repair is retained if it was installed. The existing GitHub Actions workflow stays manual-only and is not changed by the installer. Its test runner is updated to test the five-look draft; the workflow still checks the seven recordings already in the checkout.

## Safety and testing

This installer requires the previously working red-scarf preview and verifies known source hashes. Its default is read-only preflight; applying it requires an explicit draft-art acknowledgement and creates checksum-verified backups. It does not commit, push, upload, build an APK, delete any Drive or pre-existing project files during installation, access real saves, alter audio or read a keystore. It refuses unknown modified targets or a partially pre-installed draft instead of overwriting them. The installer can also preflight and explicitly apply a rollback from its recorded backup, restoring changed original files and removing only unchanged files that this update added. It will not overwrite later edits; the original backup and cosmetic sidecar are retained.

The installed-project integration was tested in reconstructed v0.7.2 projects with **synthetic** saves and **synthetic** MP3s. It was not tested against your real save, Pi or phone. One separate legacy traffic diagnostic previously reported a guard waiting 5.27 seconds; this draft does not claim to fix it. The private browser preview disables progress saving and audio and resets when reloaded.

A GitHub debug APK generated with a different signing key may not update the installed APK. Do not uninstall the existing app or clear its data to work around this; back up progress first and review signing separately.
