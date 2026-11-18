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

## Design decision 1 — shell-owned, pass-through result message

Keep **one** feedback owner and **one** entry point: MiningShell._showResult(message). Replace its ScaffoldMessenger SnackBar with a transient OverlayEntry inserted into the root Navigator overlay, so feedback is above active sheets as well as the three primary surfaces. Do not introduce a message service, provider, controller or second action path.

- The overlay content is wrapped in IgnorePointer (cover the entire message hit region, not only its Text) and is visually noninteractive. A tap on an overlapped control goes to that control; it must not dismiss the message or require a second tap. Expose the text with a live-region Semantics label, without adding accessibility actions.
- Anchor a width-constrained (at most ~420px, with 16px horizontal screen margins) message just below the fixed top chrome. Initial placement guideline: safe-area top +160px in portrait, +136px in landscape. The portrait placement clears the Site Deck Sell row; the landscape placement clears the 74px cargo gauge. Check actual widget rectangles and the Linear mockup, then adjust these presentation offsets if needed. The toast may cross the Mine Site back button, since it passes taps through; it may **not visually overlap** cash, cargo, Sell, dock or bottom navigation.
- Preserve the existing dark panel, cyan border, rounded shape, Orbitron typography and four-second display duration. A new message replaces the previous one immediately and starts its own four-second window, never queues. If an entrance transition is used, keep it lightweight and set its duration to zero when MediaQuery.disableAnimations is true.
- MiningShell owns the OverlayEntry and its expiry Timer; cancel/remove/dispose them on replacement and shell disposal. The builder takes MediaQuery layout/safe-area information so a currently displayed message relocates correctly on rotation. No persisted feedback state.
- Keep _runSheetAction, _showActionFailure, _scheduleRecoverySnackBar, _sellCargo and their existing controller/audio semantics unchanged. In particular, keep the initiating-route-only dismissal on failure; do not pop a later route. A success originating in a Technology sheet must still show its feedback above that active sheet.
- The existing shell widget-test harness remains the feedback test owner. Replace old SnackBar-type assertions with assertions on the keyed message surface, text, theme, four-second replacement/expiry, reduced-motion transition and pointer pass-through.

Rejected alternatives: moving a floating SnackBar just above the nav (obscures the dock), shortening its duration (still blocks taps), changing Scaffold.bottomNavigationBar across all screens (unrelated layout rewrite), or adding a global toast/message service (unnecessary state owner).

## Design decision 2 — keep the Technology tree compact

Only the **portrait** layout changes. Move the first level node down from y=39 to y=55, and reduce the node pitch from 76 to 72. The top coordinates become **55, 127, 199, 271, 343**, preserving the last node's original y=343 and bottom=401. The root at y=427, 500px minimum canvas, all five levels and the pinned footer remain unchanged.

- Share small portrait-position constants between node placement and _TechnologyLinks so lines continue to meet the nodes: first link now spans y=113 to y=127, then the same endpoints plus 72 per step.
- Do not change landscape node positions, icon/label styling, font sizes, costs, purchase affordances, sheet frame or scrolling behavior.
- At 360×640 with production Orbitron, assert non-overlap and a positive gap between each EXTRACTION/LOGISTICS/SURVEYING label and the first (level-5) node at text scales 1.0 and 1.3. Check all three labels, not just the selected track. Keep existing node/root link and selectable-track checks.

## Design decision 3 — correct one progression sentence

Update **CLAUDE.md**, under “Economy and progression”, to say:

> Homeworld mastery plus Surveying 3 unlocks Lunar Frontier; Lunar mastery plus Surveying 5 and **16,000,000 cash** unlocks Mars Frontier; Mars mastery plus Surveying 5 and 30,000,000 cash unlocks Ceres Frontier; Ceres mastery plus Surveying 5 and 90,000,000 cash unlocks Io Frontier.

Do not alter the registry, progression screen or content values. Existing historical HPA-855 specs remain as historical records; this ticket supersedes only their SnackBar presentation decision.

## Behavioral contract / acceptance

1. At 360×640, 390×844 and 874×402, after a result message is shown, every bottom navigation destination is immediately reachable by tapping its normal hit region (including lower-half taps). No initial tap is consumed by feedback.
2. At those sizes and on the applicable Site Deck, Mine Site, Stellar Map and sheet surfaces, message bounds do not intersect cash, cargo, Sell, dock or nav bounds. Mine Site back remains tappable even when the pass-through message covers it.
3. All message paths (success, rejection, sale, recovery, Technology purchase) share one dark visual style, one visible message, four-second timeout, replacement semantics and zero-duration motion when accessibility disables animation.
4. At 360×640 and text scales 1.0/1.3, Technology labels are clear of all first-level hexes using the real font. The tree, footer and purchase controls remain reachable.
5. Mars documentation matches 16,000,000 cash; controller/save/economy are untouched and journey totals remain byte-for-byte behaviorally unchanged.
6. Automated UI tests, one MCP-driven web end-to-end flow and screenshot comparison against both Linear mockups establish acceptance; no manual sign-off criterion.

## Explicit exclusions

No mastery-card close-button relocation, late-game balance changes, Extraction/Logistics trade-off redesign, new asset/SFX work, backward-compatibility logic or multi-PR delivery. Implementation and review revisions remain on this **same draft PR**.
