# HPA-855 mockup alignment

## Intent

Address all four issues identified in the visual comparison of PR #55 with the three HPA-855 mockups: mastery-card fidelity, rig-chip legibility, Fleet Returned cash-chip overlap, and Stellar Map presentation. Keep the work on the existing PR branch.

## Approach

Use the existing Flutter widgets, theme, authored art, and navigation paths. Reshape the mastery card rather than introducing another state owner; improve the existing per-rig chip rather than adding another badge; constrain the existing report viewport rather than hiding the cash chip; and adjust the existing map controls and card layout rather than replacing the map. A new presentation framework or gameplay changes would add complexity without addressing the visual feedback.

## Design

- **Mastery:** Follow the mockup's centered, art-led card: larger planet art, strong milestone heading and planet name, clear gates or Io reward. Pin two stacked actions using the existing sheet footer: filled cyan Open Map / RELAUNCH above outlined Continue. Both actions must be hit-testable without scrolling when opened at the four target sizes and text scale 1.3; the body may scroll. Explain the next-run sale multiplier using the shell's existing `StellarMapView.nextSaleMultiplier`, not a hardcoded first-run value. Maintain the existing shell result and navigation contracts, semantics, and dismissal behavior.
- **Rigs:** Increase contrast and readability of the single top-anchored tier/upgrade chip, with dark `0xFF04121A` text on the existing gold fill for upgrades and at least 4.5:1 contrast. Give the chip a fixed scene-space height and derive damage-label clearance from it. At the 0.8 minimum zoom, the widest upgrade label's transformed text box must be at least 8 logical pixels high. Retain the existing gold outline, one semantic rig target, pointer handling, eligibility logic, and nonintersection with HP and damage labels.
- **Fleet Returned:** Keep the cash chip visible while ensuring report content cannot scroll underneath and be obscured by it. Derive portrait viewport clearance from `MiningCashChip.height`, preserving the initial composition, separate pinned footer, all five scrollable reports, safe areas, and callbacks. Keep the existing landscape layout, where chip and reports are in separate columns.
- **Stellar Map:** Bring the unlocked non-current action closer to the mockup: a readable `TRAVEL` label beside a fixed-size play-arrow hex. The label and hex form one tappable region and one semantic button; exclude their inner semantics to avoid duplication. Preserve the existing key, busy guard, callback, current-planet treatment, locked-planet affordance, and minimum 48×48 tap target. Do not change card density or heights. This supersedes the earlier design's placement of the travel label inside the hex.

## Verification

Add focused widget regressions for each change, including small portrait and landscape layouts, large text, reduced motion, route behavior, nonoverlapping grid chrome, all five report entries, and travel guards. Recheck the implementation visually against the three ticket mockups at 360×640, 390×844, 430×932, and 874×402; check rig legibility at both zoom limits. Run the repository's applicable Flutter test, analysis, formatting, browser, and build gates. Do not alter the simulation, economy, prices, rewards, save schema, or public-action journey numbers.
