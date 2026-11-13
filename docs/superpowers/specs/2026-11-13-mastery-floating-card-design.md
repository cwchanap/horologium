# HPA-855 floating mastery card

## Intent

Bring the transient mastery presentation closer to the approved HPA-855 mockup: an art-led, centered floating card instead of a full-width sheet. This supersedes the mastery layout and button-copy portions of `2026-11-12-hpa-855-mockup-alignment-design.md`; the rest of that design remains in force.

## Design

- Use a dedicated mastery presentation, leaving other `MiningSheetFrame` consumers unchanged. On roomy portrait screens, the planet overlaps the centered card's top edge; a centered outlined milestone badge and white planet name follow. Size the card to its contents when they fit, keeping the actions near the details rather than leaving the earlier large empty gap. Keep the existing palette and fonts.
- Display the mockup's vertically stacked rounded-rectangle action hierarchy: `OPEN STELLAR MAP` above `CONTINUE`, or `RELAUNCH` above `LATER` for Io. The two buttons retain their current callbacks and immediately accessible hit targets. Retain an accessible close and barrier dismissal.
- Show the successor requirements with their actual current Surveying level and cash, using data projected from the existing display state. The mastery card labels the first gate `<planet> mastered`; Stellar Map retains its own existing labels. Never hardcode sample values or recalculate gameplay eligibility in the widget. Preserve the existing satisfied/required state for all consumers.
- On shorter screens or landscape, adapt the composition rather than forcing the mockup's proportions. At 360×640, 390×844, 430×932, and 874×402 with text scales 1.0 and 1.3, key content and both actions must be visible on opening, without scrolling, with appropriate safe-area insets. Key content means Homeworld name, successor, all gates and current values; for Io, name, reward, and complete next-run explanation. Other content may scroll. Keep text readable without reducing the user's text scale, and support rotation and reduced motion.
- Preserve post-persistence feedback, live top safe-area handling, screen-reader headings and action labels, keyboard navigation, navigation/unwinding, reward ownership, the projected next-run multiplier, and all existing tests. No new state owner, persistence, economy, save schema, dependency, or gameplay change.

## Approach

Chosen: a mastery-specific floating card using existing Flutter and mining presentation primitives, responsive where needed. Restyling the shared bottom-sheet frame would affect unrelated screens and still constrain the mockup's floating composition. A fixed mockup layout at every size would hide content or controls on short screens.
