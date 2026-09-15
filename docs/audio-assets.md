# Horologium audio

Original music and effects generated with ElevenLabs on 2026-09-14.
Source takes and prompts: [Orbital Foundry audio flow](https://elevenlabs.io/app/flows/1MAJk6feBuZEEdErzaJU).

Orbital Foundry is a restrained instrumental ambient-electronic track: warm
pads, rounded bass, glassy arpeggios, and light mechanical percussion. The
80-second source has a 2.5-second wrap crossfade, producing a 77.5-second loop.
It is normalized with constant gain toward -23 LUFS, capped at -3 dBTP, and
encoded as 44.1 kHz stereo MP3 at 160 kbps.

Effects are 44.1 kHz mono PCM WAV with 3 ms attack and 15 ms release fades
(20 ms release for mining).
Peak targets are -12 dBFS for mining/tap/reject, -8 for rig/travel/cargo-full,
and -6 for merge/sale/upgrade/milestone;
the manager plays them at 70%. Music keeps the existing independent volume.

| Asset | Source generation | Duration |
| --- | --- | --- |
| orbital_foundry.mp3 | 1bwxV2gjV6Ec5Opjs2jM | 77.5 s |
| tap.wav | IOyFic0XWjn0tLTDhPEt | 0.48 s |
| rig.wav | vpLvvafuMMAQuuZ8ztc9 | 0.68 s |
| merge.wav | eXzyl6a9bxwnsZTQBDXT | 1.2 s |
| sale.wav | 4koh5zeYIan9Sm6gGvKK | 0.88 s |
| upgrade.wav | PoKpkTtH23bp0kQTYrQB | 1.36 s |
| travel.wav | 06FJ0ARzPTcq8LHyauso | 1.48 s |
| mining.wav | LyW3pgFWyoNN4V7fLrZd | 0.55 s |
| cargoFull.wav | KxJiTXwdRLZ3dlxHFwFZ | 0.88 s |
| milestone.wav | 6Jo94djyHYSrn4kDWPFk | 1.76 s |
| reject.wav | 7MsgoEWT4uQ80pc11RNO | 0.48 s |

Mining uses a steel pick striking dense ore, with a solid impact, stone crack,
and short falling-grit tail. The 0.8-second source is trimmed from 15 ms to
565 ms, faded, then peak-normalized after downmixing. This keeps the attack
close to the visible strike and gives each one-second mining cycle room to decay.
Generation prompt: “A steel pickaxe slams once into hard mineral ore: a deep
solid chunk, sharp stone crack, and brief crunchy falling grit, close-miked and
dry, immediate attack.”

`AudioManager` owns both players, music preferences, and `audio.soundEnabled`.
The shell requests action effects after persistence succeeds. Coverage:

| Event | Cue |
| --- | --- |
| Start/Continue, navigation, dock selection, sheet opening/dismissal, technology selection, music controls | tap |
| Spawn, deploy into a commissioned site, recall | rig |
| Merge matching rigs | merge |
| Successful cargo sale | sale |
| Research and site unlock | upgrade |
| Planet travel | travel |
| First site commissioning (including planet mastery/Mars reward), planet unlock | milestone |
| Rejected grid/dock action, failed action or save | reject |
| Visible Landing Basin strike at 46% of its animation | mining |
| Active-planet site crosses from below capacity to full during foreground play | cargoFull |

Mining emits once per animated strike, even with multiple rigs. It stays silent
under a modal, with reduced motion, or without a visible strike. Frames that
skip past the strike do not replay its sound late. Full-site
notifications do not repeat until cargo is sold and fills again. Loading and
lifecycle accrual never replay mining or cargo-full notifications. Disabled
controls and continuous pan/zoom/slider movement stay quiet; slider release taps.

One reusable effect player keeps rapid input bounded. Mining has the lowest
priority, then taps, then actions/notifications, then milestones. Lower-priority
requests cannot interrupt a queued or playing cue; completion releases that
protection. Equal/higher-priority cues replace the current effect. Mute,
backgrounding, and disposal cancel pending cues and stop playback.
Effects never resume as a delayed burst. All audio ships in the asset bundle;
the game makes no generation or streaming requests at runtime.
