# HPA-285 three-planet merge-mining playtest

Status: **BLOCKED for full representative completion**. The browser run was
genuine and produced early-game observations, but this environment could not
provide a reliable text-scale 1.3 setting or enough real time to observe the
mid/late economy and complete Mars without injecting progress. Those gaps are
recorded below; no observations are inferred from widget tests or the
deterministic journey.

## Run record

- Date: 2026-08-27 (local run; validation source commit
  `63e3d01ee55a1e8c29d1f1047e9418843af0f9a8`).
- Build/session: `flutter build web --release` succeeded; `build/web` was
  served locally at `http://127.0.0.1:8766/`.
- Representative session: Chrome `151.0.7922.174` on macOS Darwin 25.5,
  arm64. The available iPad Pro 13-inch (M5) iOS 26.5 simulator was not used
  for gameplay; the simulator debug build now passes, but no representative
  iOS gameplay session was run.
- Audio: opened Settings in the running app and switched Music from enabled to
  disabled; the muted toggle was visibly off. No audio was introduced by the
  mining surfaces.
- Motion: set the running browser page to `prefers-reduced-motion: reduce`
  with browser media emulation and verified the settled shell/site views.
- Text scale: **BLOCKED**. Chrome's session has no genuine Flutter
  `textScaleFactor: 1.3` control, so the required representative observation
  at 1.3 was not claimed. Existing widget tests cover the 1.3 layout seam.

## Required viewport observations

Each viewport was set in the same release session after starting a fresh save.
The shell rendered and remained interactive in all four dimensions. Captures
were kept outside the repository while testing (`/private/tmp/
horologium-360x640-muted-reduced.png`, `horologium-402x874-shell.png`,
`horologium-430x932-shell.png`, and `horologium-874x402-shell.png`).

| viewport | orientation | observed surface and result |
| --- | --- | --- |
| 360x640 | portrait | Site Deck, muted/reduced-motion state, Landing Basin and Fleet Dock visible; no overflow observed |
| 402x874 | portrait | Site Deck showed all three Homeworld cards, dock, and bottom navigation |
| 430x932 | portrait | Site Deck and Mine Site usable; deployment controls, cavern, node, cargo, sell, and dock rendered |
| 874x402 | landscape | The live release capture showed the Site Deck action behind the fixed full-width Fleet Dock; the follow-up responsive side rail now reserves the dock beside the deck, and the 874x402/text-scale-1.3 geometry regression confirms the action does not overlap the dock or navigation |

The landscape overlap was an observed presentation defect in the captured
release build. It did not change the economy decision; the follow-up layout fix
is covered by the focused host geometry test rather than represented as a new
live release observation.

## Live early-game observations

The session started through the public UI. It entered Landing Basin, selected
the existing B1 dock and N1 node, and deployed the fresh T1 rig. The live Mine
Site read `RATE 0.50/s`, `CARGO 0.8/90`, and `SALE +3`, with the `Rig deployed.`
feedback. A subsequent near-cap observation read `CARGO 89.8/90`; selling from
that state produced the visible `Sold 360 cash.` feedback and cash `460` from
the initial `100`. The immediate post-sale read was `CARGO 1.0/90`, `SALE +4`.

Two captures made 24 seconds apart showed cargo progressing from `1.0/90` to
`13.1/90`, consistent with the displayed `0.50/s` rate. The one-rig early cap
fill interval is therefore 180 seconds (`90 / 0.50`), a readout-derived
interval rather than a timed full-cap wall-clock observation. The observed
sell/cap cadence is one 90-unit cap sale worth 360 cash, followed by refill;
the small post-sale cargo is expected foreground accrual.

The live run did not reach a reliable mid-game fill, late-game fill, or a live
merge/spawn cycle. The live run also did not complete fresh-to-Mars: doing so
would require waiting for the authored economy, and using a seeded save, fake
cash, or clock shortcut would violate this playtest gate.

## Public-action journey companion evidence

The separate deterministic integration journey uses a fresh repository and an
injected TestClock, then only public `MiningController` actions. It is evidence
for action ordering and affordability, not a substitute for the representative
browser observations above. Its exact emitted cadence was:

```text
Homeworld before Carbon Ridge: elapsed=300s, sales=540, cash=640
Homeworld before Granite Crater: elapsed=300s, sales=900, cash=1265
Homeworld mastery and Surveying 3: elapsed=1500s, sales=1500/1500/1500/1500/1500, cash=8040
inactive Homeworld while Lunar active: elapsed=30s, cargo=0.0->22.5
Lunar before Surveying 4 and Titanium Highlands: elapsed=1200s, sales=1350/1350/1350/1350, cash=8440
Lunar before Surveying 5 and Helium Mare: elapsed=1800s, sales=3030/3030/3030/3030/3030/3030, cash=19120
Lunar mastery before Mars unlock: elapsed=1200s, sales=6630/6630/6630/6630, cash=28140
Mars before Silica Dunes: elapsed=600s, sales=8640/8640, cash=25420
Mars before Cobalt Chasm: elapsed=600s, sales=17440/17440, cash=43300
Mars mastery: one reward of 25000 cash, 8300->33300
reload: active=marsFrontier, surveying=5, marsSites=3/3, cargo=0.0
```

That journey explicitly merges fresh T1 rigs and deploys the starter site on
Homeworld, Lunar Frontier, and Mars Frontier, commissions the gated sites,
proves Homeworld production while Lunar is active, proves the one-time Mars
reward, and reloads the resulting save. It passed without changing authored
numeric content.

## Balance decision

**KEEP the authored numeric content.** The public-action journey passed every
affordability gate and the live Landing readout/cap sale were internally
consistent, so there is no evidence-required balance change. This decision is
provisional with respect to the blocked live mid/late cadence run; a future
representative long session should re-check those timings before tuning.

## Open concerns

- A representative text-scale 1.3 browser/device setting was unavailable.
- Live mid/late fill timing, both live transition merge cycles, and live
  fresh-to-Mars completion remain unobserved; do not represent the deterministic
  journey as device evidence.
- No representative iOS gameplay session was run, despite the simulator debug
  build passing.
