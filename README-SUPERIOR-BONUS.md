# Superior roster, bonus stages and grass update

This additive update retains the original ten characters, selected weapon,
saved progress, keys, mission claims and twelve enemy types. It adds a separate
Superior category with the ten pictured looks; each is purchased once with
explicit confirmation. Their speed/health bonuses are exactly those pictured.
Prices are 20, 30, 40, 50 and 60 diamonds per pair.

After completing level 10, 20, … 100, the game queues a separate bonus combat
stage in a different arena. Enemies cannot damage the player there; ordinary
kill cash is doubled, and completing the bonus pays 10 diamonds plus cash. The
queue and completion are saved so an interrupted bonus can be resumed and
cannot pay its completion reward twice. Replaying a previously completed
milestone does not requeue that bonus. Existing saves are not forced through
retroactive stages, but replaying an unpaid milestone offers its bonus.

The requested obsolete mission cards are hidden; their saved claim IDs remain.
The two remaining extra milestones and all three original missions still work.
Four 32-unit grass tiles make one 64-unit box-sized section; sections join
without gaps. Player entry and exit use the user's grass.mp3. The nearby key
is pulled toward the player if there is a clear line of sight. Cash and diamond
collection visuals return without changing normal payouts. The home content is
raised while the running-character selector and Start shine/pulse are retained.

The updater contains NO MP3s. On the Pi it reads exactly grass.mp3 and
gameplay3.mp3 from /home/aryan/Downloads, copies them into assets/audio only
when absent, and refuses to replace a different existing file. The separately
requested --publish command makes these two recordings, this update and the
workflow change public on GitHub. No other personal audio, saves, or signing
keys are staged. APK generation is a further separate command.
