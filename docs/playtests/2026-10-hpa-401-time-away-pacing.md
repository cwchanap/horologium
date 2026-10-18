# HPA-401 time-away pacing: UX check

- Date: 2026-10-18
- Build: `flutter build web --no-web-resources-cdn` from the HPA-401 branch, served locally and driven in headless Chromium at 360×640 and 874×402
- Scope: copy, overflow, and feel of the new numbers and labels. Pacing is proven by `test/integration/merge_mining_journey_test.dart`, not here.

## Method

The cloud session has no Android emulator or iOS simulator, so the device-clock step was replaced by its save-level equivalent: two strict saves were generated from `MiningSave` with `lastAccruedAtUtc` set 45 minutes and 30 hours before the browser's clock, then loaded through the normal `MiningSaveRepository` path. Both saves had Homeworld mastered with four T3 rigs per site, Lunar Frontier active with Frozen Basin (2×T2) and Titanium Highlands (1×T1), Extraction 3, Logistics 2, Surveying 4, and 16,400,000 or 1,240,500 cash.

A human pass on a phone, moving the device clock, is still worth doing for feel; it is not a merge gate.

## Findings

| Surface | Result |
| --- | --- |
| Offline return, part full | `Away 47m`; per-resource rows `+18,289`, `+27,433`; no cap note. |
| Offline return, 30 h away | `Away 24h 00m`, `Capped at 24h 00m.`, `Storage full: …` per site, rows up to `+56,160`. |
| Cash chip | `16.40M`, `16.50M` after a sale, `1.24M`. |
| Site Deck, portrait | `44% · FULL IN 1H 01M` fits beside the bar. |
| Site Deck, landscape | `4.35/s · 12,004 / 28,080` over `FULL IN 1H 02M`. |
| Sell | `+113,280` on the Sell action; `Sold 108,672 cash.` snackbar. |
| Technology | Extraction 4 costs `300,000`; Logistics shows `Storage ×1.30 · fills in 1h 48m` and `Next: Storage ×1.50 · fills in 2h 05m`. |
| Stellar Map | Mars requirement `16.00M ✓`. |
| Fleet Dock | Lunar spawn `+ 40,000` fits the Spawn hex. |

## Fixed during the check

- The Site Deck and Mine Site cargo gauge clipped `15596.3` to `15596.`; it now shows `15,596` and scales down to fit (`mining_hud.dart`, test in `mining_hud_test.dart`).
- The Mine Site Sell amount was raw (`+116382`); it now uses `formatMiningCash` (`mine_site_screen.dart`, test in `mine_site_screen_test.dart`).
- Found earlier by the shell tests: the Fleet Dock Spawn label overflowed at `40,000` and now scales to fit (`fleet_dock.dart`, test in `mine_site_screen_test.dart`).

## Noted, not changed

- The next-goal strip ellipsizes its detail when the cash label is long (`Spawn a rig for 40,000…  16.40M / 40,000`). This is the existing strip layout.
- In the journey, Mars rigs never pay back before the next target (a 4,000,000 spawn returns about 170,000 per two-hour visit), so Mars progress is funded by Lunar and Homeworld sales. That matches the design's flat per-planet prices; Ceres (HPA-403) should keep it in mind.

Screenshots: `/mnt/project-files/hpa-401/ux-check-portrait.png` and `ux-check-landscape-deck.png` in the project files (not committed).
