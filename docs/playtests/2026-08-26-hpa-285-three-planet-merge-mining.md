# HPA-285 three-planet merge-mining playtest

Status: **COMPLETE for representative fresh-to-Mars validation**. The
current-head web session progressed from a fresh save through Mars using only
visible public actions, and a current-head iOS simulator session covered the
required accessibility scale. No save import, storage edit, clock
manipulation, or deterministic-journey shortcut was used.

## Run record

- Date: 2026-08-27 local (UTC timestamps below; current validation commit
  `b7b1c02f6b0793fefa4c0733e15c4484dd705afb`).
- Build/session: `flutter build web --release` succeeded from the current
  commit; `build/web` was served locally at `http://127.0.0.1:8766/`.
- Representative web session: Chrome `151.0.7922.174` on macOS Darwin 25.5,
  arm64. A current-head Flutter simulator build was also installed and
  launched on iPad Pro 13-inch (M5), iOS 26.5.
- Audio: opened Settings in the running app and switched Music from enabled to
  disabled; the muted toggle was visibly off. No audio was introduced by the
  mining surfaces.
- Motion: set the running browser page to `prefers-reduced-motion: reduce`
  with browser media emulation and verified the settled shell/site views.
- Text scale: the browser session has no direct Flutter `textScaleFactor`
  control, so the iOS simulator supplied the live accessibility check with
  Dynamic Type `extra-extra-extra-large` (approximately 1.35, stricter than
  1.3). Fresh Site Deck, Mine Site, and Technology views were readable and
  reachable without clipping.
- Current-head captures: `/private/tmp/horologium-live-360x640.png`,
  `horologium-live-402x874.png`, `horologium-live-430x932.png`, and
  `horologium-live-874x402.png`; fresh, Lunar, Mars, and reload captures are
  also under `/private/tmp/horologium-*.png`.

## Required viewport observations

Each viewport was set in the current-head release session after starting a
fresh save. The shell rendered and remained interactive in all four
dimensions. Current-head captures were kept outside the repository in the
`/private/tmp/horologium-live-*.png` files listed above.

| viewport | orientation | observed surface and result |
| --- | --- | --- |
| 360x640 | portrait | Current-head Site Deck screenshot: portrait actions, Landing Basin, and Fleet Dock visible without overflow |
| 402x874 | portrait | Current-head Site Deck screenshot: portrait cards, dock, and bottom navigation remain visible and reachable |
| 430x932 | portrait | Current-head Site Deck/Mine Site screenshots: deployment controls, cavern, nodes, cargo, sell, and dock remain reachable |
| 874x402 | landscape | Current-head screenshot: side rail is fully on-screen with sell action, spawn, four bays, back/settings, and nodes reachable; no dock/navigation overlap |

An earlier release capture exposed the fixed-dock overlap; the current-head
side-rail layout resolves it in the live 874x402 capture, with the focused
874x402/text-scale-1.3 geometry regression retaining the automated guard.

## Live early-, mid-, and late-game observations

All progression below used visible merge, deploy, unlock, spawn, research,
travel, sale, and reload actions from a fresh save. Each listed cadence was a
genuine five-minute live wait to a full cargo sale; no save import, storage
edit, clock manipulation, or seeded cash/progression was used.

| phase | live state and action evidence | observed cadence and cash |
| --- | --- | --- |
| Homeworld (early) | Fresh cash `100`; visible actions reached `3/3` with `T2/T2/T1`, `2.48/s`, and cap `435` | Five real 5-minute sales at cargo `435`, each `+1680`; cash `695->9095` from `02:18:32Z..02:38:38Z` |
| Lunar starter (mid) | Surveying 1/2/3 purchased visibly; Lunar unlock cost `2500`; after 30s active Lunar, inactive Homeworld visibly reached `435/435`; fresh Lunar rigs merged/deployed to Frozen T2 at `1.50/s`, cap `225` | Three real 5-minute sales, each `+1350`; cash `4095->8145` from `02:50:47Z..03:00:50Z` |
| Lunar expansion (mid) | Surveying 4 cost `4000`; Titanium Highlands unlock `3000` plus T1 `5000` | Six real 5-minute combined sales at cap `365`, each `+3030`; cash `645->18825` from `03:08:40Z..03:33:49Z` |
| Lunar mastery (late) | Surveying 5 cost `9000`; Helium Mare unlock `8000` plus T1 `5000`; Lunar `3/3`, `2.85/s`, cap `485` | Four real 5-minute sales, each `+6630`; cash `1325->27845` from `03:41:44Z..03:56:49Z` |
| Mars starter (late) | Mars unlock visibly cost `20000` at Lunar `3/3`/Surveying 5; inactive Homeworld and Lunar continued accruing; fresh Mars rigs merged/deployed to Ochre T2 at `1.13/s`, cap `270` | Two real 5-minute sales, each `+8640`; cash `7845->25125` at `04:04:42Z` and `04:09:43Z` |
| Mars expansion (late) | Silica Dunes unlock `12000` plus T1 `5000` | Two real 5-minute combined sales at cap `430`, each `+17440`; cash `8125->43005` at `04:17:01Z` and `04:22:03Z` |
| Mars mastery | Cobalt Chasm unlock `30000` plus T1 `5000`; final deploy showed `Mars mastered — +25,000 cash.`; final Mars `3/3`, `2.02/s`, cap `560` | Reward cash `8005->33005` at `04:23:45Z` |

The live run therefore observed merge cycles on Homeworld, Lunar Frontier, and
Mars Frontier, both planet transitions, early/mid/late five-minute cap cadence,
inactive-planet accrual, and fresh-to-Mars completion. The full progression
from early Homeworld through Mars exceeded two real hours; the listed
progression windows alone total at least 85 minutes.

On normal reload, MainMenu offered `CONTINUE MINING`; the offline-return modal
reported 34 seconds across all planets, and Mars resumed at `3/3` with cash
`33005` without a duplicate mastery reward. An immediate later sell/recall
attempt correctly showed `Sell cargo before recalling this rig.` because
accrual had resumed and cargo was present; this is expected cargo-safety
behavior, not a failed progression gate.

## Public-action journey companion evidence

The separate deterministic integration journey uses a fresh repository and an
injected TestClock, then only public `MiningController` actions. It remains
companion evidence for action ordering and affordability; the current-head
live run above independently observed the progression and cadence. Its exact
emitted cadence was:

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
affordability gate, and the current-head live run confirmed early, mid, and
late five-minute cap/sell cadence, both planet transitions, and the exact
one-time Mars reward. There is no evidence-required balance change.

## Open concerns

- The accessibility run used the iPad Pro simulator rather than physical
  hardware; direct raw Xcode invocation still has the known
  `audioplayers_darwin` module issue, while the Flutter simulator build and
  installed app session pass.
