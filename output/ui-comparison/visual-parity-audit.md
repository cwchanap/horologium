# Visual parity adjustments — 2026-09-07

The font manifest now registers Orbitron and IBM Plex Mono exactly once, with the correct assets. Captures load these definitions from the generated bundle; a regression check guards against missing or mixed font families.

The five priority corrections from the final audit are implemented. All nine gameplay captures were refreshed and visually inspected. The original reference mock definitions are unchanged.

| Scene | Adjustment / final check |
|---|---|
| Site Deck | Restored orbital header art; 46 px grouped cash badge; blank empty bays. Card stack and fleet order retained. |
| Mine Site, portrait | Corrected shared cash and empty bays; authored node, sale and dock anchors retained. |
| Stellar Map | Locked Lunar card reduced to 191 px; Mars teaser begins at y=623. Active card geometry retained. |
| Technology, portrait | Cavern-only backdrop and independently bright HUD. Tree/root/footer composition retained. |
| Settings | Site-card backdrop; panel begins at y=392; dismissible right tab at (320,362); rounded toggle. |
| Offline Return, portrait | Report begins at y=434; Orbitron badge font and hero gradient corrected. |
| Mine Site, landscape | N1/N2/N3/N4 x = 21.56/240.80/354.20/588.56; Sell x = 271.04 at 874 × 402. Narrow-screen collision guards retained. |
| Technology, landscape | Cavern-only backdrop, bright cash and selected Technology navigation. Navigation can open Settings; close controls verified. |
| Offline Return, landscape | Removed inner card border and padding. Panel width470; report begins at (421,52). Continue/play sizing corrected. |

## Evidence and limits

- Six portrait renders at 402 × 874 and three landscape renders at 874 × 402 were inspected against the supplied mock HTML/CSS definitions and asset identities.
- All nine embedded gameplay PNGs are byte-identical to their corresponding refreshed files. All nine reference mock definitions are unchanged.
- Focused widget checks cover exact corrected anchors, Settings panel/tab placement and dismissal, Technology navigation, cash geometry/grouping and landscape report geometry. Existing compact-screen collision, text-scale, lifecycle and controller tests remain in place.
- Browser tooling previously blocked local-file reference rendering. This is rendered-gameplay review against reference definitions, not a two-render pixel-difference sign-off. The repository's existing macOS-skipped Linux golden checks were not regenerated.
- Small glow, border, font-rendering and control-size differences remain. Native controls and 48 px targets retain accessibility. Animated miners, actual planet names, progression, gates and economy values intentionally follow the game. The storage-full message remains shorter than the mock.
- Final validation passed: Dart format, Flutter analyze with fatal infos, 267 host tests (4 existing golden skips), coverage, Chrome tests, Android debug APK, web build and iOS simulator debug build. The built web FontManifest also contains each font family exactly once with its correct assets; no missing-Orbitron warning remains. Automatic native-project migrations were restored after the builds.
