# SDD ledger — plan: docs/superpowers/plans/2026-08-26-hpa-285-mobile-merge-mining-redesign.md

## Setup

- Worktree: `/Users/chanwaichan/workspace/horologium/.worktrees/hpa-285-mobile-merge-mining-redesign`
- Branch: `jack65786656/hpa-285-mobile-merge-mining-redesign`
- Starting HEAD: `fe0859a4fd6a72f5530e835f37e79679be534931`
- Binding spec: `docs/superpowers/specs/2026-08-26-hpa-285-mobile-merge-mining-redesign-design.md`
- Local supplied-art archive: `/Users/chanwaichan/workspace/horologium/horologium-redesign-art.zip`

## Preflight consistency scan

### Task-internal checks

| Task | Code/tests/files checked against the task text | Finding |
| --- | --- | --- |
| 1 | Closed enums, catalog renames, summed rate/capacity formulas, initial nested-map state, focused tests | Consistent. Preserve existing optional `facilityName` and `discoveryText` fields because the binding spec includes them even though the plan's abbreviated field list omits them. |
| 2 | Local progressed fixture precedes use, exact root/planet/bay/site/node keys, new key, cargo clamp, focused repository tests | Consistent. |
| 3 | Deployed-only production, summed shares, fill-time expectations, `fullSites`, deterministic/offline behavior | Consistent. |
| 4 | Existing concrete repository test seams, refresh/initialize regressions, closed bay APIs, recall safety, progression visibility | Consistent. |
| 5 | Shell/HUD renames, lifecycle/audio/timer preservation, temporary body, complete old-runtime deletion, full-suite gate | Consistent; temporary placeholder is explicitly replaced by Task 7. |
| 6 | Pure projection tests, exact supplied-art mapping, one visual constants owner, Homeworld/common-only bundle gate | Consistent; art archive contains the 25 named supplied files and will be extracted selectively. |
| 7 | Stateless Site Deck tests, shared dock/navigation, shell actions, focused and full gates | Consistent. |
| 8 | One responsive screen, shared view/callbacks, portrait/landscape geometry, shell deploy/recall/sell | Consistent. |
| 9 | Existing progression views, full-screen map, secondary surfaces, shell navigation, focused and full gates | Consistent. |
| 10 | Twelve explicit external PNGs, all-nine bundle test, no fallback, hard input gate | Consistent; remains an external-input gate until the named real files exist. |
| 11 | Public-action journey, observed playtest, numeric-only tuning, legacy/uniqueness scans, full build gates, docs | Consistent. |

### Cross-task producer/consumer checks

| Tasks | Producer -> consumer | Finding |
| --- | --- | --- |
| 1 -> 2 | `MiningSave`, enum-keyed docks/sites, content capacity helper -> strict codec/clamp | Clean. |
| 1 -> 3 | content/state and rig ladders -> simulation rate/capacity loop | Clean. |
| 1 -> 4 | state/content identities -> controller actions and progression gates | Clean. |
| 1 -> 5 | renamed core types -> shell/HUD cutover and old-runtime deletion | Clean; old presentation may remain red only until this coherent cutover. |
| 1 -> 6 | per-site/per-planet asset fields and content helpers -> pure views/visual tests | Clean. |
| 1 -> 11 | authored balance values -> journey assertions and evidence-based tuning | Clean. |
| 2 -> 4 | concrete repository/new save key -> serialized controller persistence | Clean. |
| 2 -> 5 | repository presence/load semantics -> Main Menu and shell initialization | Clean. |
| 2 -> 11 | new strict schema -> reload proof and legacy-key scan | Clean. |
| 3 -> 4 | `AccrualResult`/`OfflineProductionSummary` -> controller refresh/actions | Clean. |
| 3 -> 5 | `fullSites` and non-persisting accrual -> timer/offline shell behavior | Clean. |
| 3 -> 6 | effective rate/capacity -> Site Deck/Mine Site projections | Clean. |
| 3 -> 9 | per-planet/resource summary -> Offline Return retargeting | Clean. |
| 3 -> 11 | deterministic economy -> fresh-to-Mars journey and cadence evidence | Clean. |
| 4 -> 5 | controller/progression seams -> shell owner and lifecycle tests | Clean. |
| 4 -> 6 | controller-ready state and progression views -> pure projections | Clean. |
| 4 -> 7 | spawn/merge/unlock APIs -> Site Deck shell wiring | Clean. |
| 4 -> 8 | deploy/recall/sell APIs -> Mine Site shell wiring | Clean. |
| 4 -> 9 | technology/planet APIs and projections -> map/secondary wiring | Clean. |
| 4 -> 11 | public actions -> journey-only progression proof | Clean. |
| 5 -> 6 | evolved `MiningHud` tokens/owner -> `MiningTheme` and visual layer | Clean. |
| 5 -> 7 | `MiningShell`, HUD, temporary body -> production Site Deck | Clean. |
| 5 -> 8 | shell ownership/local destination -> Mine Site navigation | Clean. |
| 5 -> 9 | shell/audio/offline/settings/technology ownership -> final navigation/sheets | Clean. |
| 5 -> 11 | Flame-free architecture -> uniqueness scans and docs | Clean. |
| 6 -> 7 | `SiteDeckView`, `FleetDockView`, theme/assets -> Site Deck widgets | Clean. |
| 6 -> 8 | `MineSiteView`, Fleet Dock, anchors/rig assets -> responsive Mine Site | Clean. |
| 6 -> 9 | richer `StellarMapView`, planet assets/theme -> Stellar Map/secondary surfaces | Clean. |
| 6 -> 10 | declared all-site paths and structural visual test -> final binary resolution gate | Clean; Task 6 intentionally skips six Lunar/Mars cavern/node pairs. |
| 6 -> 11 | content paths/projections -> final asset/docs/build verification | Clean. |
| 7 -> 8 | shared dock/navigation and shell selection -> Mine Site interactions | Clean. |
| 7 -> 9 | shared navigation/shell primary destination -> Stellar Map integration | Clean. |
| 7 -> 10 | Site Deck card loading -> Lunar/Mars cavern-as-card inputs | Clean by final state; temporary pre-Task-10 commits are not merge-ready. |
| 7 -> 11 | production default surface -> journey/playtest shell entry | Clean. |
| 8 -> 9 | shell destination/open-site state -> final navigation integration | Clean. |
| 8 -> 10 | Mine Site asset loading -> all Lunar/Mars cavern/node binaries | Clean by final state; Task 10 is the explicit hard gate. |
| 8 -> 11 | responsive interactions -> geometry/device playtest | Clean. |
| 9 -> 10 | final primary/secondary UI -> complete visual bundle | Clean. |
| 9 -> 11 | final navigation/secondary surfaces -> playtest and docs | Clean. |
| 10 -> 11 | all-nine real asset proof -> final gates and merge readiness | Clean. |

## Rulings

- Ruling: Preserve `MiningSiteDefinition.facilityName` and `discoveryText` during Task 1 — the binding spec retains them and the plan only abbreviates the field list — cost if wrong: two harmless existing optional fields survive longer than necessary.
- Ruling: Use `/Users/chanwaichan/workspace/horologium/horologium-redesign-art.zip` as Task 6's supplied prototype archive, extracting only the explicitly mapped PNGs — it contains the verified 25 slot-named assets and keeps the main checkout artifact untouched — cost if wrong: a separately attached prototype revision could require replacing those binaries before Task 10/final review.
- Ruling: Clear Task 10's external-art gate by generating the twelve required final Lunar/Mars PNGs with the built-in image generator, using the supplied Horologium style brief plus the existing gold cavern/node assets as style references — this continues the user's prior art-generation request without placeholders — cost if wrong: the user may prefer separately commissioned art and replace these binaries before release.
- Ruling: The Task 11 public-action journey has no direct controller/repository mutation or affordability bypass; state reads are assertion-only.
- Ruling: Inactive Homeworld production, the exact one-time 25,000 Mars reward, and reload state are all explicitly covered by the Task 11 journey.
- Ruling: The 874x402/text-scale-1.3 geometry test adequately covers the code-level overlap regression and 48px controls, but does not replace current-head live playtest evidence.
- Ruling: The Chrome-only asset-byte-load skip is a documented, nonblocking runner limitation because host/full/coverage retain the direct bundle proof; it is not evidence of a browser byte-load pass.
- Ruling: The remaining long-form representative-playtest limitation blocks Task 11 approval under the written plan.
- Ruling: The 100-iteration `earnUntil` limit is a minimal, deterministic test-only safeguard and does not alter economy behavior.
- Ruling: The zero-iteration journey regression is sufficient to prove the earning bound's failure path without additional fixtures or state bypasses.
- Ruling: The scoped Task 11 corrective re-review did not rerun broad gates; it accepted the corrected report's recorded focused/full results as evidence.

## Baseline verification

- `rtk flutter pub get`: passed.
- `rtk flutter analyze --fatal-infos`: passed with no issues.
- `rtk flutter test`: passed with exit code 0.

## Task 1 — Catalog, closed IDs, capacity, and state

- Implementer commit: `46f57978a0e91c38af7c12468104232a193a7f50` (`feat(mining): remodel mining state for merge rigs`).
- Focused verification: 18 catalog/state tests passed; focused analysis and format checks passed.
- Review: approved for spec compliance and code quality after confirming asset binaries are intentionally owned by Tasks 6 and 10.
- Deferred integration gate: all declared mining asset paths must resolve by Task 10; no Task 1 scope expansion was made.

## Task 2 — Strict save repository

- Implementer commit: `fd5536aa046db23692419e1b7ec91e773a51b319` (`feat(mining): persist merge-rig saves`).
- Focused verification: 45 repository tests passed; focused analysis, format, and diff checks passed.
- Review: approved for spec compliance and code quality with no Critical, Important, or Minor findings.
- Planned transition state: the repo-wide analyzer remains red only in downstream pre-cutover consumers assigned to Tasks 3–5.

## Task 3 — Deterministic rig accrual

- Implementer commit: `2e8e5ea724020197febedfc3ec2abe10a7e4ab74` (`feat(mining): accrue rig production and storage`).
- Focused verification: 11 simulation tests passed; focused analysis, format, and diff checks passed.
- Review: approved for spec compliance and code quality with no findings.
- Planned transition state: downstream controller/presentation consumers still use legacy sector names until Tasks 4–5.

## Task 4 — Controller and progression projections

- Implementer commit: `dde6e08` (`feat(mining): serialize merge-rig progression`).
- Focused verification: 25 controller tests, 13 progression tests, and the combined 38-test run passed; focused analysis, format, and diff checks passed.
- Review: approved for spec compliance and code quality with no findings; temporary projection aliases were judged minimal and tied to Task 5 consumers.
- Planned transition state: remaining analyzer failures are old presentation/Flame consumers owned by Task 5.

## Task 5 — Flame-free MiningShell cutover

- Implementer commits: `ba10cbb` (`refactor(mining): cut over to a Flame-free mining shell`) and `253dc2b` (`fix(mining): close shell cutover review gaps`).
- Verification: format, fatal-info analysis, and all 162 Flutter tests passed; closure searches found no remaining Flame/terrain/old-world consumers.
- Initial review findings: add a real viewport rotation to the identity test and remove six stale deleted-terrain constants.
- Fix round 1: both findings addressed; scoped re-review found no new breakage.
- Review status: approved.

## Task 6 — Pure projections and supplied visuals

- Implementer commits: `b01e212` (`feat(mining): add mobile projections and Homeworld visuals`), `154d931` (`fix(mining): close Task 6 review gaps`), and `6c38a60` (`fix(mining): remove unused mine-site alias`).
- Verification: exactly 25 supplied PNGs mapped; 26 initial focused tests passed; final fatal-info analysis and all 176 Flutter tests passed.
- Initial review findings: add explicit locked Site Deck state coverage and remove unused aliases/speculative theme tokens.
- Fix rounds: locked state and theme/alias cleanup completed; a surviving alias required and passed a second scoped re-review.
- Review status: approved; twelve Lunar/Mars cavern/node binaries remain the explicit Task 10 gate.

## Task 7 — Site Deck

- Implementer commits: `b1e4de4` (`feat(mining): build the mobile site deck`) and `dc04847` (`fix(mining): gate Site Deck during initialization`).
- Verification: final focused Site Deck/shell run passed 17 tests; fatal-info analysis and all 183 Flutter tests passed.
- Initial review findings: pre-initialization controls appeared actionable while taps were discarded, and target-size tests did not assert exact four bays/both dimensions.
- Fix round 1: added explicit non-interactive SafeArea loading state, delayed-initialization regression, exact four-bay coverage, and 48x48 checks for all requested control groups.
- Review status: approved with no new breakage.

## Task 8 — Responsive Mine Site

- Implementer commits: `2541bd6` (`feat(mining): build responsive mine sites`), `cda5c89` (`fix(mining): align site sales with active planet`), and `6f2d404` (`fix(mining): align site sale metric with aggregate`).
- Verification: final focused view/screen tests passed; fatal-info analysis and all 194 Flutter tests passed.
- Initial review findings: sale UI used current-site cargo while the controller sells all active-planet cargo, and reduced-motion SnackBars still animated.
- Fix round 1: canonical active-planet sale projection and no-animation SnackBars added; re-review found the SALE metric and floor-once test still incomplete.
- Fix round 2: SALE metric now uses the aggregate and fractional two-site coverage proves floor-once semantics.
- Review status: approved with no new breakage.

## Task 9 — Stellar Map and secondary surfaces

- Implementer commits: `1bf9ef5` (`feat(mining): finish mobile mining navigation`) and `890e77f` (`fix(mining): reset dock selection on planet change`).
- Verification: final focused Stellar Map/shell run passed 24 tests; fatal-info analysis and all 204 Flutter tests passed.
- Initial review findings: dock selection leaked across active-planet changes, and Stellar Map carried an unnecessary default-content fallback.
- Fix round 1: selection clears only after successful active-planet change; travel and unlock regressions added; Stellar Map content is required.
- Review status: approved with no new breakage.

## Task 10 — Lunar/Mars art gate

- External art workflow: twelve final PNGs generated with the built-in image generator using the supplied Horologium style brief and existing gold cavern/node references.
- Implementer commit: `63e3d01` (`feat(mining): complete Lunar and Mars visuals`).
- Verification: six 800x1200 opaque caverns, six 512x512 RGBA nodes, exactly nine expected files in each directory; focused visual/layout tests, fatal-info analysis, and all 204 Flutter tests passed.
- Review: approved after focused binary metadata and visual QA; no placeholders, duplicates, corruptions, fallbacks, aliases, or unrelated code found.

## Task 11 — Economy validation, playtest, and final gates

- Implementer commits: `d971b38` (`test(mining): validate the mobile merge economy`), `5adeb0d` (`fix(mining): preserve landscape site actions`), and `b7b1c02` (`fix(mining): bound journey earning loop`).
- Automated verification: public-action fresh-to-Mars/reload journey passed; format and fatal-info analysis passed; host/full and coverage suites passed 206 tests; Chrome passed 205 tests with one intentional browser-runner-only asset-byte-load skip; exact web, Android debug, and iOS simulator debug builds passed.
- Initial review findings: the required representative live playtest was incomplete, `earnUntil` could loop indefinitely, and `CLAUDE.md` misstated `refresh()` persistence.
- Corrective patch: bounded the earning loop with diagnostic evidence and a regression test; corrected refresh documentation; both P2 findings passed scoped re-review with no new findings.
- Review status: blocked only on the written representative live-playtest gate: current-head text scale 1.3, mid/late fill and sell cadence, both planet-transition cycles, and real-time fresh-to-Mars completion remain unobserved and were not faked.

### Task 11 final review sequence

- The current-head live run documented in the Task 11 report and playtest
  record supersedes the earlier blocked status above; the run covered the
  accessibility scale, mid/late cadence, both transitions, fresh-to-Mars, and
  normal reload without save or clock manipulation.
- Caption correction commit: `a74baf39` (`docs(mining): correct live viewport captions`).
- Final Task 11 status: **Approved** at HEAD `a74baf39`.
- Ruling: The b7b1c02 live run is valid for current documentation-only heads because intervening commits change evidence documents, not application code.
- Ruling: Exact-once Mars reward/reload evidence is adequate: live cash 8005->33005 stayed 33005 after reload, and deterministic journey asserts no reward on recall/redeploy.
- Ruling: The iPad simulator satisfies the written device/simulator accessibility gate; the raw-Xcode issue is an honestly scoped follow-up, not an acceptance blocker.
- Ruling: The cadence scripts used real five-minute waits and visible UI actions, with no save or clock mutation.
- Ruling: The prior P2 viewport-caption finding is fully resolved.
- Ruling: The simulator-only accessibility/device limitation is honestly scoped and is not an acceptance blocker under the written plan.

### Final whole-branch review sequence

- Initial final review found blocked pointer feedback, busy sale state/copy, and terminology.
- Corrective commits `1da861d` and `7739f48` completed strict RED/GREEN cycles.
- Final whole-branch reviewer verdict at commit `7739f48b76bfd15b69e20cb923e09e5b4c018a31`: Ready to merge Yes, Critical/Important/Minor none.
- Ruling: Keeping disabled Semantics/styling while forwarding taps solely to explain disabled state is coherent.
- Ruling: Skipping unused compatibility aliases and the legacy asset catalog is acceptable KISS/YAGNI scope control; they are not current behavior defects.
- Ruling: Both remaining corrective findings are fully resolved.
- Ruling: The delayed repository is justified test-seam code for proving a genuine in-flight action; it introduces no production abstraction.
- Ruling: Lean already. Ship. Net: -0 lines possible.
