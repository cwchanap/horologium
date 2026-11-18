# HPA-1086 — Non-blocking messages and UAT polish (design)

Linear: https://linear.app/cwchanap/issue/HPA-1086/stop-messages-blocking-the-bottom-nav-plus-two-small-uat-fixes  
Baseline: main @ 89d91b1c747a0b4395e483e0711b8a05ff5e052b (2026-11-17 UAT)  
Mockups: the two images attached to HPA-1086, **“Messages: before and after”** and **“Technology labels: before and after”**.

## Outcome and scope

A result message must not prevent the player from immediately using the navigation, dock, Sell or a control beneath it. Feedback remains visible under the top HUD in portrait and landscape. The three Technology track labels must clear their first level hex even at 1.3 text scale. The progression documentation must state the already-authored Mars cash gate.

This is **presentation and documentation only**. No change to MiningController, MiningSimulation, MiningContentRegistry, save JSON/schema, prices, rewards, gameplay actions or the public-action journey's numerical expectations. No new art or SFX.

## Evidence on main

- MiningShell._showResult (lib/mining/presentation/mining_shell.dart) produces the game's one floating ScaffoldMessenger SnackBar. It calls removeCurrentSnackBar before showSnackBar. The default display duration is four seconds. The app's bottom navigation is embedded in SiteDeckScreen, MineSiteScreen, StellarMapScreen and MiningSheetScene, not in Scaffold.bottomNavigationBar; the floating SnackBar can cover its hit regions.
- The existing dark message look is panel fill, cyan/accent 12px-rounded outline, 13px Orbitron text and primary-text contrast. Reduced motion currently disables SnackBar animation.
- Portrait Site Deck places Sell at top +108 through +156, cash at +54 through +100 and cargo gauge at +50 through +130 (all plus the safe-area inset). Mine Site's dock/navigation occupy the bottom; the back control is around +146. Landscape Mine Site's cargo sits at +52 through +126 and has a bottom toolbar/right rail. Positioning must respect these fixed chrome bounds, not only the Scaffold.
- TechnologySheet._tree uses a 48px-tall portrait header. Its 28px icon + 5px gap + scalable label can touch the first node at y=39. Its five portrait nodes begin at 39 with a 76px pitch; the last node ends at 401 and the root starts at 427. _TechnologyLinks hardcodes the matching link endpoints.
- CLAUDE.md currently omits the Mars cash cost from its unlock chain, while MiningContentRegistry already defines unlockCashCost: 16000000 for Mars.

## Design decision 1 — one shell-owned, pass-through result message

Keep **one** feedback owner and **one** entry point: MiningShell._showResult(message). Replace the floating ScaffoldMessenger SnackBar with a **Stack child in MiningShell's existing Scaffold.body**, above the current primary surface. Do **not** insert an OverlayEntry into the root Navigator overlay, create a message service/provider, or add a parallel action path. Modal sheets continue to cover shell messages exactly as they do today.

- The **entire visible message panel** sits in IgnorePointer, including its background and border; a tap beneath it reaches the underlying control on the first try. Expose only its text in read-only Semantics(liveRegion: true, ...), reusing the current shell accessibility pattern. In particular, the Linear mockup intentionally places feedback across Mine Site Back; Back must still be tappable.
- The panel is width-constrained to ~420px maximum with at least 16px horizontal margin and positioned below top chrome, initially safe-area top +160px in portrait or +136px in landscape. Portrait clears Site Deck Sell (through +156); landscape clears Mine Site cargo (through +126). Verify actual widget rectangles and the ticket mockup; adjust these presentation offsets only where needed. It must never visually overlap cash, cargo, Sell, dock or nav, but may be drawn above Back because hit testing passes through.
- Reuse the existing dark SnackBar appearance: MiningTheme.panel fill, MiningTheme.accent cyan border, 12px corner radius, 13px Orbitron and MiningTheme.primaryText. **No entrance/exit animation**; the message appears on the next frame. Reduced-motion users therefore see no animation as required, without adding another animation controller.
- MiningShell stores only String? _message and Timer? _messageTimer. Each _showResult replaces the current text and restarts one four-second expiry timer; no queue or stacking. Timer expiry clears _message through setState, and dispose cancels the timer. Because this is part of the shell widget tree, orientation and MediaQuery insets are picked up by ordinary rebuilds. No overlay insert/remove/dispose lifecycle, no persisted feedback state.
- Keep _runSheetAction, _showActionFailure, _scheduleRecoverySnackBar, _sellCargo and all controller/audio semantics. Failures still dismiss **only** their currently initiating sheet before showing the shell message; do not dismiss later routes. Offline-return Sell already unwinds popups before the sale, Relaunch dismisses its own sheet, and Settings permission denial appears inline. A successful Technology purchase intentionally updates its sheet **without any toast** (MiningController.purchaseTechnology returns success with no message, and the existing shell regression test asserts this). Mastery continues to show its card instead.
- Keep the existing MiningShell widget harness: replace the SnackBar-specific assertion with a keyed panel/theme/semantics assertion, and check first-tap navigation, pass-through, four-second expiry/replacement, rotation and immediate no-animation appearance. Do not add an active-sheet success-message test or root-overlay cleanup test.

Rejected alternatives: moving a floating SnackBar just above the nav (obscures the dock), shortening its duration (still blocks taps), migrating every screen to Scaffold.bottomNavigationBar (unrelated rewrite), a global/root OverlayEntry (unneeded sheet layering and lifecycle), or adding a message service/provider (second state owner).

## Design decision 2 — keep the Technology tree compact

Only the **portrait** layout changes. Move the first level node down from y=39 to y=55, and reduce the node pitch from 76 to 72. The top coordinates become **55, 127, 199, 271, 343**, preserving the last node's original y=343 and bottom=401. The root at y=427, 500px minimum canvas, all five levels and the pinned footer remain unchanged.

- Use shared `_portraitNodeTop(step) = 55 + step * 72` and `_portraitNodeHeight = 58` for node placement **and every portrait link endpoint**, including the final link start at `_portraitNodeTop(4) + _portraitNodeHeight` (401). First inter-node link spans y=113 to y=127. Keep the separate authored root/trunk location fixed.
- Do not change landscape node positions, icon/label styling, font sizes, costs, purchase affordances, sheet frame or scrolling behavior.
- At 360×640 with production Orbitron, assert non-overlap and a positive gap between each EXTRACTION/LOGISTICS/SURVEYING label and the first (level-5) node at text scales 1.0 and 1.3. Check all three labels, not just the selected track. Keep existing node/root link and selectable-track checks.

## Design decision 3 — correct one progression sentence

Update **CLAUDE.md**, under “Economy and progression”, to say:

> Homeworld mastery plus Surveying 3 unlocks Lunar Frontier; Lunar mastery plus Surveying 5 and **16,000,000 cash** unlocks Mars Frontier; Mars mastery plus Surveying 5 and 30,000,000 cash unlocks Ceres Frontier; Ceres mastery plus Surveying 5 and 90,000,000 cash unlocks Io Frontier.

Do not alter the registry, progression screen or content values. Existing historical HPA-855 specs remain as historical records; this ticket supersedes only their SnackBar presentation decision.

## Behavioral contract / acceptance

1. At 360×640, 390×844 and 874×402, after a result message is shown, every bottom navigation destination is immediately reachable by its normal hit region (including lower-half taps). No first tap is consumed by feedback; a currently selected destination need not change routes on a re-tap.
2. On Site Deck, Mine Site and Stellar Map, message bounds never intersect cash, cargo, Sell, dock or nav bounds. Mine Site Back is still tappable when the pass-through message visually crosses it. Modal sheets remain above the underlying shell message and preserve their existing dismissal behavior.
3. All **existing** message paths (success, rejection, sale, recovery, post-dismissal sheet failure) use one dark style, one visible message, a four-second timeout and replacement rather than queuing. Messages appear immediately without a transition, including when reduced motion is enabled. **No toast is added to successful Technology purchases.**
4. At 360×640 and text scales 1.0/1.3, Technology labels clear every first-level hex with the real font. The tree, footer, links and purchase controls remain reachable.
5. Mars documentation matches 16,000,000 cash; controller/save/economy stay untouched and public-action journey totals do not change.
6. Deterministic widget tests cover all three viewports; **one MCP-driven web end-to-end smoke run at 390×844** reproduces the original first-tap bug and captures messages and Technology for screenshot comparison against the two Linear mockups. The 360×640 / 1.3 text-scale visual check is performed with the real-font widget/golden harness. No manual sign-off criterion.

## Explicit exclusions

No mastery-card close-button relocation, late-game balance changes, Extraction/Logistics trade-off redesign, new asset/SFX work, backward-compatibility logic or multi-PR delivery. Implementation and review revisions remain on this **same draft PR**.
