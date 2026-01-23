# Horologium Features PRD
## Product Requirements Document

**Version:** 1.1
**Date:** January 2026
**Author:** Product Team
**Status:** In Progress

**Implementation Status:**
- ✅ Population Growth & Happiness System (Completed)
- ✅ Building Upgrades and Visual Progression (Completed)
- ⏳ Quests and Achievement System (Not Started)
- ⏳ Production Chain Visualization (Not Started)
- ⏳ Stellar Map - Inter-Planetary Trade Routes (Not Started)
- ⏳ Decorative Buildings and Landscaping (Not Started)
- ⏳ Natural Disasters and Events System (Not Started)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Goals and Success Metrics](#2-goals-and-success-metrics)
3. [Feature Specifications](#3-feature-specifications)
   - [3.1 Population Growth and Happiness System](#31-population-growth-and-happiness-system)
   - [3.2 Building Upgrades and Visual Progression](#32-building-upgrades-and-visual-progression)
   - [3.3 Quests and Achievement System](#33-quests-and-achievement-system)
   - [3.4 Production Chain Visualization](#34-production-chain-visualization)
   - [3.5 Stellar Map - Inter-Planetary Trade Routes](#35-stellar-map---inter-planetary-trade-routes)
   - [3.6 Decorative Buildings and Landscaping](#36-decorative-buildings-and-landscaping)
   - [3.7 Natural Disasters and Events System](#37-natural-disasters-and-events-system)
4. [Dependencies and Feature Interactions](#4-dependencies-and-feature-interactions)
5. [Implementation Phases](#5-implementation-phases)
6. [Risk Assessment](#6-risk-assessment)
7. [Open Questions](#7-open-questions)

---

## 1. Executive Summary

### 1.1 Overview

This PRD defines seven major features for Horologium, a Flutter/Flame-based space city-building game. These features are designed to enhance player engagement, deepen strategic gameplay, and extend the game's longevity through interconnected systems that build upon the existing 50x50 grid, resource management, and multi-planet architecture.

### 1.2 Strategic Vision

The proposed features transform Horologium from a basic city-builder into a rich, dynamic simulation with:
- **Emergent gameplay** through happiness, disasters, and event systems
- **Visual satisfaction** via building upgrades and decorative elements
- **Long-term goals** through quests, achievements, and inter-planetary trade
- **Strategic depth** with production chain visualization and trade route optimization

### 1.3 Feature Summary

| Feature | Priority | Complexity | Player Value |
|---------|----------|------------|--------------|
| Population Growth and Happiness | High | Medium | High |
| Building Upgrades and Visual Progression | High | Medium | High |
| Quests and Achievement System | Medium | Medium | High |
| Production Chain Visualization | Medium | Low | Medium |
| Stellar Map - Inter-Planetary Trade Routes | High | High | Very High |
| Decorative Buildings and Landscaping | Low | Low | Medium |
| Natural Disasters and Events System | Medium | High | High |

---

## 2. Goals and Success Metrics

### 2.1 Business Goals

1. **Increase player retention** by 40% through engaging long-term progression systems
2. **Extend average session time** by 25% with deeper strategic mechanics
3. **Improve player satisfaction scores** through visual polish and feedback systems
4. **Create foundation for monetization** through cosmetic decorations and planet unlocks

### 2.2 Player Goals

1. Build thriving, visually appealing colonies across multiple planets
2. Master complex production chains and resource optimization
3. Complete meaningful objectives that provide direction and rewards
4. Experience dynamic, unpredictable gameplay through events and challenges

### 2.3 Success Metrics

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Daily Active Users Retention (D7) | 35% | Analytics tracking |
| Average Session Duration | 15+ minutes | Session analytics |
| Feature Adoption Rate | 70% within 7 days | Feature usage tracking |
| Player Happiness Rating | 4.2+ stars | In-app feedback |
| Quest Completion Rate | 60% of started quests | Quest system tracking |
| Buildings Upgraded (per player) | 10+ per week | Upgrade event logging |

---

## 3. Feature Specifications

---

### 3.1 Population Growth and Happiness System

#### 3.1.1 Overview and Motivation

The current population system is static (`population = 20`). This feature introduces dynamic population growth tied to a happiness mechanic, creating a feedback loop where player decisions directly impact colony success.

**Current State:**
- Fixed population count in `Resources` class (`lib/game/resources/resources.dart`)
- Workers assigned to buildings but no population dynamics
- `unshelteredPopulation` tracked but not utilized

**Desired State:**
- Population grows or shrinks based on happiness levels
- Multiple factors contribute to happiness (housing, food, services, decorations)
- Visual feedback shows population mood and growth trends

#### 3.1.2 Detailed Requirements

##### Functional Requirements

**Must Have:**
- FR-POP-001: Implement `HappinessManager` class tracking overall colony happiness (0-100 scale)
- FR-POP-002: Population growth rate calculated as: `baseGrowthRate * (happiness / 100) - attritionRate`
- FR-POP-003: Happiness factors include:
  - Housing ratio (sheltered vs unsheltered population)
  - Food availability (bread, pastries consumption)
  - Service coverage (water, electricity per capita)
  - Employment rate (workers assigned / total workers)
- FR-POP-004: Population cap based on total housing capacity (`accommodationCapacity`)
- FR-POP-005: Persist happiness and population growth state via `SaveService`

**Should Have:**
- FR-POP-006: Happiness breakdown UI showing contribution of each factor
- FR-POP-007: Population growth notifications with animations
- FR-POP-008: Negative happiness events (strikes, emigration) when happiness drops below 30%
- FR-POP-009: Happiness bonuses from decorative buildings (see Feature 3.6)

**Could Have:**
- FR-POP-010: Population segments (workers, researchers, merchants) with different needs
- FR-POP-011: Seasonal happiness modifiers
- FR-POP-012: Immigration events when happiness exceeds 80%

##### Non-Functional Requirements
- NFR-POP-001: Happiness calculation must complete within 16ms per frame
- NFR-POP-002: Population changes should animate smoothly without jarring UI updates
- NFR-POP-003: System must scale to 10,000+ population without performance degradation

#### 3.1.3 User Stories

1. **As a player**, I want to see my population grow when I provide good living conditions, so that I feel rewarded for my planning.

2. **As a player**, I want clear feedback on what makes my colonists happy or unhappy, so that I can make informed decisions.

3. **As a player**, I want population shrinkage when conditions are poor, so that there are real consequences for neglecting my colony.

4. **As a player**, I want to see happiness trends over time, so that I can predict and prevent population problems.

#### 3.1.4 UI/UX Considerations

**Happiness Indicator:**
- Add happiness icon/meter to `ResourceDisplay` widget (`lib/widgets/game/resource_display.dart`)
- Color coding: Green (70-100), Yellow (40-69), Red (0-39)
- Tooltip showing factor breakdown on hover/tap

**Population Display:**
- Modify population row to show growth trend arrow (up/down/stable)
- Add projected population in parentheses: "Population: 150 (+5)"

**Notification System:**
- Toast notifications for significant population events
- Styled consistently with dark space theme and cyan accents

#### 3.1.5 Technical Implementation Notes

**New Files:**
```
lib/game/population/happiness_manager.dart
lib/game/population/population_growth.dart
lib/game/population/happiness_factor.dart
lib/widgets/game/happiness_display.dart
```

**Modified Files:**
- `lib/game/resources/resources.dart`: Add happiness integration
- `lib/game/managers/game_state_manager.dart`: Include happiness in update cycle
- `lib/game/services/save_service.dart`: Persist happiness data
- `lib/widgets/game/resource_display.dart`: Add happiness UI

**Data Model:**
```dart
class HappinessManager {
  double overallHappiness = 50.0; // 0-100
  Map<HappinessFactor, double> factorContributions = {};
  double growthRate = 0.0;

  void calculate(Resources resources, List<Building> buildings);
  void applyPopulationChange(Resources resources);
}

enum HappinessFactor {
  housing,
  food,
  water,
  electricity,
  employment,
  decorations,
  events,
}
```

**Integration with Resources Update Cycle:**
```dart
// In GameStateManager.startResourceGeneration
_resourceTimer = Timer.periodic(Duration(seconds: 1), (timer) {
  final buildings = getBuildingsCallback();
  ResourceService.updateResources(resources, buildings);
  _happinessManager.calculate(resources, buildings);
  _happinessManager.applyPopulationChange(resources); // Every N seconds
  onUpdate();
});
```

#### 3.1.6 Acceptance Criteria

- [x] Happiness value persists across app restarts
- [x] Population grows when happiness ≥ 60 and housing available
- [x] Population shrinks when happiness ≤ 30 for extended period (60s)
- [x] Happiness calculation uses 4 contributing factors (housing, food, services, employment)
- [x] UI updates smoothly without frame drops
- [x] All existing tests pass without modification
- [x] New unit tests cover happiness calculation edge cases

#### 3.1.7 Implementation Summary

**Status:** ✅ **COMPLETED** (January 2026)

**What Was Implemented:**

1. **Happiness Calculation** (`lib/game/resources/resources.dart`)
   - Weighted happiness formula (0-100 scale)
   - Housing factor (30%): Ratio of sheltered population
   - Food factor (25%): Bread + pastries availability (1 food per 5 pop = 100%)
   - Services factor (25%): Electricity and water per capita
   - Employment factor (20%): Ratio of employed workers
   - Smooth transition (90% old + 10% new per tick)

2. **Population Dynamics** (`lib/game/resources/resources.dart`)
   - Growth: +1 every 30s when happiness ≥60 and housing available
   - Decline: -1 after 60s of happiness ≤30 (2 consecutive cycles)
   - Accumulator-based timing for precise control
   - Low happiness streak tracking to prevent rapid decline

3. **UI Enhancements** (`lib/widgets/game/resource_display.dart`)
   - Happiness indicator with emoji face (happy/neutral/sad)
   - Color-coded display (green/yellow/red)
   - Population trend arrow (↑ growing, − stable, ↓ declining)
   - Compact display in resource overlay

4. **Persistence** (`lib/game/services/save_service.dart`)
   - Happiness value saved per planet
   - Default value of 50.0 for new/legacy saves
   - Planet-scoped storage key: `planet.<id>.happiness`

**Key Decisions:**
- **Growth Rate:** Medium speed (1 pop/30s) for noticeable but not urgent feedback
- **Food Sources:** Finished foods only (bread, pastries) to require full production chains
- **UI Style:** Subtle indicators without intrusive notifications
- **Thresholds:** 60+ for growth, 30- for decline (generous mid-range)

**Test Coverage:**
- 3 new happiness system tests
- Tests cover growth, decline, and calculation logic
- All 94+ tests passing

**Files Modified:**
- `lib/game/resources/resources.dart` - Added `happiness`, `_updateHappiness()` method
- `lib/widgets/game/resource_display.dart` - Rewrote to show happiness and trends
- `lib/game/services/save_service.dart` - Added happiness persistence
- `test/widgets/game/resource_display_test.dart` - Updated for new UI
- `test/resources/resources_test.dart` - Added 3 happiness tests

**Behavior Details:**
- Happiness updates every second alongside resource updates
- Population changes checked every 30 seconds
- Streak counter prevents premature decline from temporary dips
- No notifications to avoid UI clutter (per user preference)

---

### 3.2 Building Upgrades and Visual Progression

#### 3.2.1 Overview and Motivation

The `Building` class already has `level` and `maxLevel` properties with scaling for cost, generation, and consumption. However, upgrades are not exposed to players and buildings have no visual level differentiation.

**Current State:**
- `Building.level` exists but starts at 1 with no UI for upgrading
- `Building.upgradeCost` and `Building.canUpgrade` implemented
- No visual differentiation between building levels
- Single sprite per building type in `assets/images/building/`

**Desired State:**
- Players can upgrade placed buildings using resources
- Each level has distinct visual appearance
- Upgraded buildings show enhanced effects (glow, particles)
- Clear progression path visible in building info panels

#### 3.2.2 Detailed Requirements

##### Functional Requirements

**Must Have:**
- FR-UPG-001: Upgrade button in building detail dialog
- FR-UPG-002: Upgrade cost deducted from resources when upgrading
- FR-UPG-003: Building level persisted in `PlacedBuildingData` (already exists)
- FR-UPG-004: Visual indicator of building level (border color, badge, or overlay)
- FR-UPG-005: Upgraded building stats reflected immediately (generation, consumption)

**Should Have:**
- FR-UPG-006: Level-specific sprites for buildings (level 1-5 variants)
- FR-UPG-007: Upgrade animation (particle burst, glow effect)
- FR-UPG-008: Upgrade requirements beyond cost (e.g., research prerequisites)
- FR-UPG-009: Bulk upgrade option for multiple buildings of same type

**Could Have:**
- FR-UPG-010: Special max-level building appearances (unique "prestige" skins)
- FR-UPG-011: Building upgrade paths (specialization at higher levels)
- FR-UPG-012: Upgrade cost reduction through research

##### Non-Functional Requirements
- NFR-UPG-001: Upgrade operation must complete within 100ms
- NFR-UPG-002: Level sprites must not increase app bundle size by more than 20MB
- NFR-UPG-003: Upgrade animations must not cause frame drops below 30fps

#### 3.2.3 User Stories

1. **As a player**, I want to upgrade my buildings to increase their output, so that I can optimize my colony without building more.

2. **As a player**, I want to visually distinguish building levels at a glance, so that I can assess my colony's development.

3. **As a player**, I want to see the benefits of upgrading before committing, so that I can make informed investment decisions.

4. **As a player**, I want an upgrade animation, so that upgrades feel rewarding and satisfying.

#### 3.2.4 UI/UX Considerations

**Building Detail Dialog:**
- Add "Upgrade" button below current building info
- Show current stats vs. upgraded stats comparison
- Disable button with tooltip when max level or insufficient resources

**Grid Rendering:**
- Level indicator in corner of building tile (small badge: "Lv.3")
- Higher-level buildings have enhanced border glow
- Consider different sprite assets for levels 1, 3, and 5 at minimum

**Upgrade Animation:**
- Flash effect on building
- Particle burst emanating from building center
- Sound effect (optional based on audio system)

#### 3.2.5 Technical Implementation Notes

**New Files:**
```
lib/widgets/dialogs/building_upgrade_dialog.dart
lib/game/effects/upgrade_effect.dart
```

**Modified Files:**
- `lib/game/grid.dart`: Render level indicators, load level-specific sprites
- `lib/game/planet/placed_building_data.dart`: Already supports level serialization
- `lib/game/building/building.dart`: No changes needed (level logic exists)
- `lib/game/services/building_service.dart`: Add upgrade validation method

**Asset Requirements:**
```
assets/images/building/house_lv1.png
assets/images/building/house_lv2.png
assets/images/building/house_lv3.png
assets/images/building/house_lv4.png
assets/images/building/house_lv5.png
# Repeat for each building type
```

**Grid Rendering Enhancement:**
```dart
void _renderBuilding(Canvas canvas, PlacedBuilding placedBuilding) {
  final building = placedBuilding.building;
  // ... existing sprite rendering ...

  // Add level badge
  final levelBadgePaint = Paint()
    ..color = _getLevelColor(building.level);
  final badgeRect = Rect.fromLTWH(rect.right - 20, rect.top, 20, 16);
  canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, Radius.circular(4)), levelBadgePaint);

  // Draw level text
  final textPainter = TextPainter(
    text: TextSpan(text: '${building.level}', style: TextStyle(fontSize: 10)),
    textDirection: TextDirection.ltr,
  )..layout();
  textPainter.paint(canvas, Offset(badgeRect.left + 6, badgeRect.top + 2));
}
```

#### 3.2.6 Acceptance Criteria

- [x] Players can upgrade buildings from level 1 to maxLevel (5)
- [x] Upgrade cost correctly deducted from cash resources
- [x] Building stats update immediately after upgrade
- [x] Level indicator visible on all placed buildings
- [x] Upgrade state persists across app restarts
- [x] Cannot upgrade at max level (button disabled with message)
- [x] Cannot upgrade without sufficient resources (button disabled)

#### 3.2.7 Implementation Summary

**Status:** ✅ **COMPLETED** (January 2026)

**What Was Implemented:**

1. **BuildingOptionsDialog** (`lib/widgets/game/building_options_dialog.dart`)
   - Replaced `DeleteConfirmationDialog` with comprehensive options dialog
   - Shows current building stats (production, consumption, housing)
   - Displays upgrade preview with next-level stats
   - Upgrade button with dynamic cost display
   - Delete button for building removal

2. **Level Badge Rendering** (`lib/game/grid.dart`)
   - Color-coded badges appear on buildings level 2+ (green→blue→purple→orange)
   - Badge positioned in top-right corner with level number
   - 16x14px badge with rounded corners
   - Uses `TextPainter` for crisp level text rendering

3. **Enhanced Persistence** (`lib/game/planet/placed_building_data.dart`)
   - Updated legacy string format: `"x,y,BuildingName,level,workers"`
   - Backward compatible with old format (defaults to level 1)
   - Round-trip persistence preserves all building state

4. **Upgrade Flow** (`lib/game/scene_widget.dart`)
   - Long-tap on building → `_showBuildingOptionsDialog()`
   - `_upgradeBuilding()` deducts cash and increments level
   - `_updatePlanetBuildingLevel()` syncs with planet data
   - Immediate UI refresh after upgrade

**Key Decisions:**
- **UI Access:** Long-tap replaced delete-only dialog with full options dialog
- **Visual Indicator:** Corner badge chosen over border glow for clarity
- **Cost Structure:** Cash-only upgrades (no additional resource requirements)
- **Upgrade Formula:** `upgradeCost = baseCost × (level + 1)`

**Test Coverage:**
- 24 new tests added across 3 test files
- All 117+ tests passing
- Tests cover upgrade logic, persistence, and UI interactions

**Files Created:**
- `lib/widgets/game/building_options_dialog.dart` (254 lines)
- `test/widgets/game/building_options_dialog_test.dart` (8 tests)
- `test/building/building_upgrade_test.dart` (9 tests)
- `test/planet/placed_building_data_test.dart` (7 tests)

**Files Modified:**
- `lib/game/grid.dart` - Added level badge rendering (3 new methods)
- `lib/game/scene_widget.dart` - Replaced dialog, added upgrade handlers
- `lib/game/planet/placed_building_data.dart` - Enhanced persistence format
- `test/services/save_service_planet_test.dart` - Updated expectations

**Not Implemented (Out of Scope):**
- Level-specific sprite variants (using badges instead)
- Upgrade animations/particles (deferred)
- Research prerequisites for upgrades (deferred)
- Bulk upgrade functionality (deferred)

---

### 3.3 Quests and Achievement System

#### 3.3.1 Overview and Motivation

Players currently lack directed goals beyond resource accumulation. A quest and achievement system provides short-term objectives (quests) and long-term milestones (achievements) that guide player progression and offer rewards.

**Current State:**
- No quest or achievement tracking
- Research system provides some progression (`lib/game/research/research.dart`)
- No tutorial or onboarding guidance

**Desired State:**
- Dynamic quest system with procedural and story quests
- Achievement tracking for major milestones
- Rewards for completion (resources, unlocks, cosmetics)
- Quest log accessible from hamburger menu

#### 3.3.2 Detailed Requirements

##### Functional Requirements

**Must Have:**
- FR-QST-001: `Quest` model with id, name, description, objectives, rewards
- FR-QST-002: `QuestManager` tracking active, completed, and available quests
- FR-QST-003: Quest objectives types: build X buildings, accumulate Y resources, research Z
- FR-QST-004: Quest completion detection with reward distribution
- FR-QST-005: Quest log UI accessible from hamburger menu
- FR-QST-006: Persist quest progress via `SaveService`

**Should Have:**
- FR-QST-007: Achievement system separate from quests (permanent milestones)
- FR-QST-008: Quest chains (completing one unlocks the next)
- FR-QST-009: Daily/weekly rotating quests for engagement
- FR-QST-010: Quest notification when new quest available or completed

**Could Have:**
- FR-QST-011: Quest rewards include cosmetic building skins
- FR-QST-012: Achievement leaderboards (requires backend)
- FR-QST-013: Planet-specific quests tied to biomes

##### Non-Functional Requirements
- NFR-QST-001: Quest state check must complete within 5ms per quest
- NFR-QST-002: Support minimum 50 concurrent quest/achievement definitions
- NFR-QST-003: Quest UI must load within 200ms

#### 3.3.3 User Stories

1. **As a new player**, I want beginner quests that teach me game mechanics, so that I learn how to play effectively.

2. **As an experienced player**, I want challenging quests with meaningful rewards, so that I have goals to work toward.

3. **As a completionist**, I want to see all available achievements and my progress toward them, so that I know what challenges remain.

4. **As a casual player**, I want daily quests that give me small, achievable goals, so that I feel accomplished in short sessions.

#### 3.3.4 UI/UX Considerations

**Quest Log Panel:**
- Accessible via hamburger menu (`lib/widgets/game/hamburger_menu.dart`)
- Tabs: Active Quests | Completed | Achievements
- Quest cards showing progress bars and rewards preview

**Quest Notification:**
- Banner notification at top when quest completed
- Pulsing indicator on hamburger menu when unclaimed rewards

**Quest Detail View:**
- Full description and objective breakdown
- Reward preview with item icons
- "Claim Reward" button when completed

**Achievement Display:**
- Grid of achievement badges (locked/unlocked states)
- Tap for detail overlay with unlock conditions

#### 3.3.5 Technical Implementation Notes

**New Files:**
```
lib/game/quests/quest.dart
lib/game/quests/quest_manager.dart
lib/game/quests/quest_objective.dart
lib/game/quests/quest_registry.dart
lib/game/achievements/achievement.dart
lib/game/achievements/achievement_manager.dart
lib/widgets/game/quest_log_panel.dart
lib/widgets/cards/quest_card.dart
lib/widgets/cards/achievement_card.dart
```

**Modified Files:**
- `lib/widgets/game/hamburger_menu.dart`: Add quest log button
- `lib/game/services/save_service.dart`: Quest/achievement persistence
- `lib/game/managers/game_state_manager.dart`: Quest progress checking

**Data Models:**
```dart
enum QuestObjectiveType {
  buildBuilding,
  accumulateResource,
  completeResearch,
  reachPopulation,
  achieveHappiness,
  upgradeBuilding,
}

class QuestObjective {
  final QuestObjectiveType type;
  final String targetId; // BuildingType, ResourceType, ResearchType
  final int targetAmount;
  int currentAmount = 0;

  bool get isComplete => currentAmount >= targetAmount;
}

class Quest {
  final String id;
  final String name;
  final String description;
  final List<QuestObjective> objectives;
  final QuestReward reward;
  final List<String> prerequisiteQuestIds;

  bool get isComplete => objectives.every((o) => o.isComplete);
}

class QuestReward {
  final Map<ResourceType, double> resources;
  final List<String> unlockIds; // Buildings, cosmetics
  final int researchPoints;
}
```

**Quest Progress Checking (in update loop):**
```dart
void checkQuestProgress(Resources resources, List<Building> buildings) {
  for (final quest in activeQuests) {
    for (final objective in quest.objectives) {
      switch (objective.type) {
        case QuestObjectiveType.buildBuilding:
          objective.currentAmount = buildings
              .where((b) => b.type.toString() == objective.targetId)
              .length;
          break;
        case QuestObjectiveType.accumulateResource:
          final resourceType = ResourceType.values.firstWhere(
            (r) => r.toString() == objective.targetId,
          );
          objective.currentAmount = resources.resources[resourceType]?.toInt() ?? 0;
          break;
        // ... other cases
      }
    }
  }
}
```

#### 3.3.6 Acceptance Criteria

- [ ] At least 10 starter quests defined and functional
- [ ] Quest progress updates in real-time during gameplay
- [ ] Completed quests award resources correctly
- [ ] Quest log displays active, completed, and available quests
- [ ] Quest state persists across app restarts
- [ ] Achievement grid shows locked/unlocked states
- [ ] Quest chains unlock correctly after prerequisites met
- [ ] Quest notifications appear without blocking gameplay

---

### 3.4 Production Chain Visualization

#### 3.4.1 Overview and Motivation

Horologium has complex production chains (e.g., Field -> Wheat -> Windmill -> Flour -> Bakery -> Bread) that are not clearly communicated to players. Visualizing these chains helps players optimize their colonies.

**Current State:**
- Buildings have `baseGeneration` and `baseConsumption` maps
- Production chains exist implicitly (wheat -> flour -> bread)
- No visual representation of dependencies

**Desired State:**
- Interactive graph showing resource flow
- Highlight bottlenecks in production chains
- Building info shows upstream/downstream dependencies

#### 3.4.2 Detailed Requirements

##### Functional Requirements

**Must Have:**
- FR-VIZ-001: Production chain overlay accessible from resource display
- FR-VIZ-002: Graph nodes represent buildings, edges represent resource flow
- FR-VIZ-003: Color-coded flow rates (green = surplus, yellow = balanced, red = deficit)
- FR-VIZ-004: Tap node to highlight connected chain

**Should Have:**
- FR-VIZ-005: Animated resource particles flowing along edges
- FR-VIZ-006: Filter view by resource type
- FR-VIZ-007: Bottleneck detection with recommendations
- FR-VIZ-008: Production rate numbers on edges

**Could Have:**
- FR-VIZ-009: "What-if" simulation (show impact of adding building)
- FR-VIZ-010: Export production report
- FR-VIZ-011: Historical production data graphs

##### Non-Functional Requirements
- NFR-VIZ-001: Visualization must render at 30fps with 50+ buildings
- NFR-VIZ-002: Graph layout calculation must complete within 500ms
- NFR-VIZ-003: Must work on screens as small as 320px wide

#### 3.4.3 User Stories

1. **As a player**, I want to see how resources flow through my colony, so that I can identify production bottlenecks.

2. **As a player**, I want to know which buildings supply and consume a resource, so that I can plan expansion.

3. **As a player**, I want visual feedback when production chains are inefficient, so that I can take corrective action.

#### 3.4.4 UI/UX Considerations

**Production Overlay:**
- Full-screen overlay triggered from resource panel button
- Semi-transparent background showing grid beneath
- Zoom and pan support matching main game controls

**Graph Layout:**
- Left-to-right flow (raw materials -> processed -> finished)
- Grouped by building category
- Consistent with dark space theme

**Interaction:**
- Tap building node to see details
- Long-press to highlight full chain
- Double-tap to center on building in main grid

#### 3.4.5 Technical Implementation Notes

**New Files:**
```
lib/widgets/overlays/production_chain_overlay.dart
lib/widgets/graphs/production_graph.dart
lib/game/production/chain_analyzer.dart
lib/game/production/flow_calculator.dart
```

**Modified Files:**
- `lib/widgets/game/resource_display.dart`: Add visualization button

**Chain Analysis:**
```dart
class ChainAnalyzer {
  final List<Building> buildings;

  Map<ResourceType, ProductionNode> buildProductionGraph() {
    final nodes = <ResourceType, ProductionNode>{};

    for (final building in buildings) {
      for (final entry in building.generation.entries) {
        final resourceType = ResourceType.values.firstWhere(
          (r) => r.toString().split('.').last == entry.key,
        );
        nodes.putIfAbsent(resourceType, () => ProductionNode(resourceType));
        nodes[resourceType]!.producers.add(BuildingNode(building, entry.value));
      }

      for (final entry in building.consumption.entries) {
        final resourceType = ResourceType.values.firstWhere(
          (r) => r.toString().split('.').last == entry.key,
        );
        nodes.putIfAbsent(resourceType, () => ProductionNode(resourceType));
        nodes[resourceType]!.consumers.add(BuildingNode(building, entry.value));
      }
    }

    return nodes;
  }

  List<BottleneckInfo> detectBottlenecks() {
    // Compare production vs consumption rates
  }
}
```

#### 3.4.6 Acceptance Criteria

- [ ] Production graph displays all active buildings
- [ ] Resource flow direction is clear (producer -> consumer)
- [ ] Deficit resources highlighted in red
- [ ] Tapping a node shows building details
- [ ] Graph updates in real-time as buildings are added/removed
- [ ] Visualization performs at 30fps on mid-range devices
- [ ] Chain filter correctly isolates single resource chains

---

### 3.5 Stellar Map - Inter-Planetary Trade Routes

#### 3.5.1 Overview and Motivation

The game already supports multiple planets (`Planet` class, `ActivePlanet` singleton). This feature realizes the "STELLAR MAP" menu option by creating an interactive galaxy view with trade routes between planets.

**Current State:**
- `Planet` class with independent resources, buildings, research
- `SaveService.loadOrCreatePlanet()` supports multiple planets
- Main menu has non-functional "STELLAR MAP" button
- Basic trade page for single-planet resource trading

**Desired State:**
- Visual stellar map showing all planets
- Establish trade routes between planets
- Resources transferred over time based on route distance
- Unlock new planets through research or quests

#### 3.5.2 Detailed Requirements

##### Functional Requirements

**Must Have:**
- FR-MAP-001: Stellar map view with planetary bodies
- FR-MAP-002: Planet selection to switch active planet
- FR-MAP-003: Trade route creation between owned planets
- FR-MAP-004: Resource transfer queue with travel time
- FR-MAP-005: Trade route capacity limits

**Should Have:**
- FR-MAP-006: Animated trade ships traveling routes
- FR-MAP-007: Route efficiency based on distance
- FR-MAP-008: New planet discovery/unlock system
- FR-MAP-009: Planet comparison panel (resources, buildings, population)

**Could Have:**
- FR-MAP-010: Hostile planets with conquest mechanics
- FR-MAP-011: Trade route upgrades (faster ships, larger capacity)
- FR-MAP-012: Random events during transit (pirates, discoveries)
- FR-MAP-013: AI-controlled planets for trading

##### Non-Functional Requirements
- NFR-MAP-001: Map must support 20+ planets without performance issues
- NFR-MAP-002: Trade route calculations must be deterministic for sync
- NFR-MAP-003: Stellar map must load within 2 seconds

#### 3.5.3 User Stories

1. **As a player**, I want to see all my planets on a map, so that I can manage my interplanetary empire.

2. **As a player**, I want to trade resources between planets, so that I can specialize planet economies.

3. **As a player**, I want to discover new planets, so that I can expand my territory.

4. **As a player**, I want to see trade ships traveling between planets, so that trade feels tangible.

#### 3.5.4 UI/UX Considerations

**Stellar Map:**
- Full-screen view replacing main content
- Starfield background (reuse `StarfieldPainter` from main menu)
- Planets as interactive nodes with size based on development
- Trade routes as glowing lines with animated particles

**Planet Selection:**
- Tap planet to open info panel
- "Travel" button to switch active planet
- Resource summary visible on hover/tap

**Trade Route Management:**
- Drag from planet to planet to create route
- Route configuration panel (resource type, quantity, frequency)
- Active routes shown as lines on map

#### 3.5.5 Technical Implementation Notes

**New Files:**
```
lib/pages/stellar_map_page.dart
lib/widgets/stellar_map/planet_node.dart
lib/widgets/stellar_map/trade_route.dart
lib/widgets/stellar_map/stellar_map_canvas.dart
lib/game/trade/trade_route.dart
lib/game/trade/trade_route_manager.dart
lib/game/trade/trade_ship.dart
```

**Modified Files:**
- `lib/main_menu.dart`: Wire up `_openStellarMap()`
- `lib/game/services/save_service.dart`: Trade route persistence
- `lib/game/planet/planet.dart`: Add planet coordinates

**Data Models:**
```dart
class TradeRoute {
  final String id;
  final String sourcePlanetId;
  final String destinationPlanetId;
  final ResourceType resourceType;
  final double amountPerTrip;
  final Duration travelTime; // Based on distance
  DateTime? lastDeparture;

  bool get isActive => lastDeparture != null;
}

class TradeShip {
  final TradeRoute route;
  final double cargoAmount;
  final DateTime departureTime;
  final DateTime arrivalTime;

  double get progress {
    final total = arrivalTime.difference(departureTime).inSeconds;
    final elapsed = DateTime.now().difference(departureTime).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}

class PlanetCoordinates {
  final double x; // -1.0 to 1.0 relative to galaxy center
  final double y;

  double distanceTo(PlanetCoordinates other) {
    return sqrt(pow(x - other.x, 2) + pow(y - other.y, 2));
  }
}
```

**Integration with Planet:**
```dart
class Planet {
  // ... existing fields ...
  PlanetCoordinates coordinates;
  List<TradeRoute> outgoingRoutes = [];
  List<TradeRoute> incomingRoutes = [];
}
```

#### 3.5.6 Acceptance Criteria

- [ ] Stellar map displays all owned planets
- [ ] Players can switch active planet from map
- [ ] Trade routes can be created between planets
- [ ] Resources transfer after travel time elapses
- [ ] Trade route state persists across restarts
- [ ] New planets can be unlocked (research/quest)
- [ ] Map zooms and pans smoothly
- [ ] Trade ships animate along routes

---

### 3.6 Decorative Buildings and Landscaping

#### 3.6.1 Overview and Motivation

Beyond functional buildings, players want to beautify their colonies. Decorative elements also tie into the happiness system, providing functional benefit beyond aesthetics.

**Current State:**
- All buildings are functional (produce/consume resources)
- `BuildingCategory` enum has no decorative category
- Grid supports building placement but no decoration layer

**Desired State:**
- Decorative building category with variety of options
- Decorations boost local or global happiness
- Some decorations are quest rewards or achievements
- Decorations can be placed on non-buildable terrain

#### 3.6.2 Detailed Requirements

##### Functional Requirements

**Must Have:**
- FR-DEC-001: Add `decorative` to `BuildingCategory` enum
- FR-DEC-002: Minimum 10 decorative building types (statues, gardens, fountains)
- FR-DEC-003: Decorations have happiness bonus (global or area-based)
- FR-DEC-004: Decorations cost resources but don't produce/consume

**Should Have:**
- FR-DEC-005: Decorations placeable on some non-buildable terrain types
- FR-DEC-006: Seasonal/event-specific decorations
- FR-DEC-007: Decoration animations (water fountain, flag waving)
- FR-DEC-008: Decoration sets (themed collections with bonus)

**Could Have:**
- FR-DEC-009: Custom decoration creator (combine elements)
- FR-DEC-010: Decoration gifting between planets
- FR-DEC-011: Rare decorations from exploration events

##### Non-Functional Requirements
- NFR-DEC-001: Decorative sprites must be under 50KB each
- NFR-DEC-002: Animated decorations must not exceed 10% GPU overhead
- NFR-DEC-003: Support 100+ decorations per planet without lag

#### 3.6.3 User Stories

1. **As a player**, I want to decorate my colony with statues and gardens, so that it feels personalized.

2. **As a player**, I want decorations to boost happiness, so that they have gameplay value beyond aesthetics.

3. **As a player**, I want to earn exclusive decorations through achievements, so that I can show off my accomplishments.

#### 3.6.4 UI/UX Considerations

**Building Selection Panel:**
- New "Decorative" tab in building categories
- Thumbnail previews with happiness bonus displayed

**Placement:**
- Decorations can overlap non-buildable terrain (based on terrain type)
- Smaller decorations (1x1 grid) for flexibility
- Snap to grid like regular buildings

**Visual Style:**
- Consistent with sci-fi theme (holographic statues, alien flora)
- Glow effects that complement building aesthetics

#### 3.6.5 Technical Implementation Notes

**Modified Files:**
- `lib/game/building/category.dart`: Add `decorative` category
- `lib/game/building/building.dart`: Add decorative buildings to registry
- `lib/game/population/happiness_manager.dart`: Include decoration bonus

**New Decorative Buildings:**
```dart
Building(
  type: BuildingType.holoStatue,
  name: 'Holographic Statue',
  description: 'A mesmerizing holographic display that boosts morale.',
  icon: Icons.blur_circular,
  assetPath: Assets.holoStatue,
  color: Colors.purple,
  baseCost: 200,
  baseGeneration: {},
  baseConsumption: {},
  gridSize: 1, // 1x1
  requiredWorkers: 0,
  category: BuildingCategory.decorative,
  happinessBonus: 2.0, // New field
),
```

**Terrain Buildability Override:**
```dart
// In ParallaxTerrainComponent
bool isBuildableAt(int x, int y, {bool isDecoration = false}) {
  final cell = getTerrainCell(x, y);
  if (isDecoration) {
    // Decorations can be placed on grass, dirt, sand but not water
    return cell.baseType != TerrainType.water;
  }
  return cell.baseType == TerrainType.grass || cell.baseType == TerrainType.dirt;
}
```

#### 3.6.6 Acceptance Criteria

- [ ] Decorative category appears in building selection
- [ ] At least 10 decorative buildings available
- [ ] Decorations contribute to happiness calculation
- [ ] Some decorations placeable on sand/rock terrain
- [ ] Decorations persist correctly via save system
- [ ] Decoration sprites display correctly on grid
- [ ] Animated decorations play without performance issues

---

### 3.7 Natural Disasters and Events System

#### 3.7.1 Overview and Motivation

Static gameplay becomes predictable. A dynamic events system introduces challenges (disasters) and opportunities (bonuses) that keep gameplay fresh and require adaptive strategies.

**Current State:**
- No random events during gameplay
- Resources flow predictably based on buildings
- No external challenges to player progress

**Desired State:**
- Random events with positive and negative effects
- Disaster types: meteor strikes, power outages, worker strikes
- Bonus events: resource discoveries, immigration waves, trade bonuses
- Event notification and response system

#### 3.7.2 Detailed Requirements

##### Functional Requirements

**Must Have:**
- FR-EVT-001: `EventManager` class triggering random events
- FR-EVT-002: Disaster events: Meteor Strike (destroys building), Power Outage (disables electricity), Drought (reduces water)
- FR-EVT-003: Bonus events: Resource Discovery (+resources), Immigration (+population)
- FR-EVT-004: Event notification with countdown or immediate effect
- FR-EVT-005: Event frequency configurable (difficulty setting)

**Should Have:**
- FR-EVT-006: Event mitigation through buildings (meteor defense, backup generators)
- FR-EVT-007: Event log showing recent events
- FR-EVT-008: Some events require player response (choices)
- FR-EVT-009: Planet-specific event probabilities based on biomes

**Could Have:**
- FR-EVT-010: Multi-stage disaster events (escalating severity)
- FR-EVT-011: Event chains (one event triggers another)
- FR-EVT-012: Player-triggered events (expeditions, experiments)

##### Non-Functional Requirements
- NFR-EVT-001: Event processing must not block main game loop
- NFR-EVT-002: Visual effects for disasters must be GPU-efficient
- NFR-EVT-003: Events must be deterministic from seed (for replays/testing)

#### 3.7.3 User Stories

1. **As a player**, I want unexpected events that challenge my colony, so that gameplay stays engaging.

2. **As a player**, I want to prepare defenses against disasters, so that I can mitigate risks.

3. **As a player**, I want bonus events that reward my progress, so that I have positive surprises.

4. **As a player**, I want to see what events have occurred, so that I can learn from them.

#### 3.7.4 UI/UX Considerations

**Event Notification:**
- Dramatic full-screen flash for major disasters
- Banner notification for minor events
- Event icon in corner during active events

**Event Response Dialog:**
- Modal dialog for events requiring player choice
- Clear presentation of options and consequences
- Timer for urgent responses

**Event Log:**
- Accessible from hamburger menu
- Chronological list with event icons
- Filter by event type

**Disaster Visual Effects:**
- Meteor: streak animation followed by explosion at target
- Power Outage: flickering lights on affected buildings
- Drought: brown overlay on water treatment buildings

#### 3.7.5 Technical Implementation Notes

**New Files:**
```
lib/game/events/event.dart
lib/game/events/event_manager.dart
lib/game/events/disaster_event.dart
lib/game/events/bonus_event.dart
lib/game/events/event_registry.dart
lib/widgets/dialogs/event_notification_dialog.dart
lib/widgets/game/event_log_panel.dart
lib/game/effects/meteor_effect.dart
lib/game/effects/power_outage_effect.dart
```

**Modified Files:**
- `lib/game/managers/game_state_manager.dart`: Integrate event manager
- `lib/game/scene_widget.dart`: Display event notifications

**Data Models:**
```dart
enum EventType {
  meteorStrike,
  powerOutage,
  drought,
  resourceDiscovery,
  immigrationWave,
  tradeBonus,
  workerStrike,
}

abstract class GameEvent {
  final String id;
  final EventType type;
  final String name;
  final String description;
  final Duration duration; // Zero for instant events
  final DateTime triggeredAt;

  void apply(Planet planet);
  void revert(Planet planet); // For temporary effects
}

class MeteorStrikeEvent extends GameEvent {
  final int targetX;
  final int targetY;

  @override
  void apply(Planet planet) {
    planet.removeBuildingAt(targetX, targetY);
    // Trigger visual effect
  }
}

class EventManager {
  final Random _random;
  final double baseEventChance = 0.01; // Per update tick

  void update(Planet planet, Duration elapsed) {
    if (_random.nextDouble() < baseEventChance) {
      final event = _selectRandomEvent(planet);
      event.apply(planet);
      _activeEvents.add(event);
      onEventTriggered?.call(event);
    }

    // Check for event expiration
    _activeEvents.removeWhere((e) {
      if (DateTime.now().isAfter(e.triggeredAt.add(e.duration))) {
        e.revert(planet);
        return true;
      }
      return false;
    });
  }
}
```

**Mitigation Buildings:**
```dart
// Add to building registry
Building(
  type: BuildingType.meteorDefense,
  name: 'Meteor Defense System',
  description: 'Reduces chance of meteor strikes by 50%.',
  // ...
  eventMitigation: {EventType.meteorStrike: 0.5},
),

// In EventManager
double getEffectiveEventChance(EventType type, List<Building> buildings) {
  double mitigation = 1.0;
  for (final building in buildings) {
    if (building.eventMitigation.containsKey(type)) {
      mitigation *= (1 - building.eventMitigation[type]!);
    }
  }
  return baseEventChance * mitigation;
}
```

#### 3.7.6 Acceptance Criteria

- [ ] Events trigger randomly during gameplay
- [ ] Meteor strike destroys targeted building
- [ ] Power outage disables electricity buildings temporarily
- [ ] Resource discovery adds bonus resources
- [ ] Event notification displays clearly
- [ ] Event effects revert after duration expires
- [ ] Mitigation buildings reduce disaster probability
- [ ] Event log records all triggered events
- [ ] Event frequency respects difficulty setting

---

## 4. Dependencies and Feature Interactions

### 4.1 Feature Dependency Graph

```
                    ┌─────────────────────────────────┐
                    │         Core Systems            │
                    │  Resources, Buildings, Grid,    │
                    │    Research, Planet, Save       │
                    └───────────────┬─────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ▼                           ▼                           ▼
┌───────────────┐         ┌─────────────────┐         ┌─────────────────┐
│   Population  │◄────────│   Decorative    │         │   Production    │
│   Happiness   │         │   Buildings     │         │   Chain Viz     │
└───────┬───────┘         └─────────────────┘         └─────────────────┘
        │
        ├────────────────────────────────────────────────┐
        │                                                │
        ▼                                                ▼
┌───────────────┐                               ┌─────────────────┐
│    Quests &   │                               │   Disasters &   │
│ Achievements  │                               │     Events      │
└───────┬───────┘                               └─────────────────┘
        │
        ▼
┌───────────────────────────────────────────────────────────────────┐
│                      Stellar Map & Trade Routes                   │
│              (Depends on multiple planets, quests for             │
│               unlocking, events for route disruptions)            │
└───────────────────────────────────────────────────────────────────┘
        ▲
        │
        └────────── Building Upgrades (Independent but enhances all)
```

### 4.2 Detailed Interactions

| Feature A | Feature B | Interaction |
|-----------|-----------|-------------|
| Happiness | Decorations | Decorations boost happiness |
| Happiness | Events | Disasters reduce happiness, bonuses increase |
| Happiness | Population | High happiness triggers population growth |
| Quests | All Features | Quest objectives can target any feature |
| Quests | Stellar Map | Planet unlocks gated behind quests |
| Events | Stellar Map | Events can affect trade routes |
| Events | Production Viz | Bottlenecks visualize during disasters |
| Upgrades | Production Viz | Upgraded buildings show in chain |
| Upgrades | Happiness | Higher-level housing boosts happiness |

### 4.3 Shared Components

**Notification System:**
- Used by: Quests, Events, Population changes
- Should be unified into `NotificationManager`

**Persistence Layer:**
- All features extend `SaveService`
- Consider migration to structured JSON or SQLite for scale

**Animation Framework:**
- Upgrade effects, disaster effects, trade ship animations
- Leverage Flame's existing animation capabilities

---

## 5. Implementation Phases

### Phase 1: Foundation (Weeks 1-4)

**Focus:** Core systems that enable other features

| Week | Feature | Deliverables |
|------|---------|--------------|
| 1-2 | Happiness System | `HappinessManager`, factor calculation, UI integration |
| 3-4 | Building Upgrades | Upgrade UI, level persistence, visual indicators |

**Dependencies:** None (builds on existing code)

**Risks:** Low

### Phase 2: Engagement (Weeks 5-8)

**Focus:** Player retention through goals and feedback

| Week | Feature | Deliverables |
|------|---------|--------------|
| 5-6 | Quests System | `QuestManager`, 10+ starter quests, quest log UI |
| 7-8 | Achievements | Achievement tracking, badge grid, unlock detection |

**Dependencies:** Happiness (for happiness-based objectives)

**Risks:** Medium (content creation effort)

### Phase 3: Visualization (Weeks 9-10)

**Focus:** Information clarity

| Week | Feature | Deliverables |
|------|---------|--------------|
| 9-10 | Production Chain Viz | Chain analyzer, graph overlay, bottleneck detection |

**Dependencies:** None (read-only visualization of existing data)

**Risks:** Low

### Phase 4: Expansion (Weeks 11-16)

**Focus:** Multi-planet gameplay

| Week | Feature | Deliverables |
|------|---------|--------------|
| 11-13 | Stellar Map | Map view, planet nodes, navigation |
| 14-16 | Trade Routes | Route creation, resource transfer, ship animation |

**Dependencies:** Quests (for planet unlocks)

**Risks:** High (complex new system)

### Phase 5: Polish (Weeks 17-20)

**Focus:** Variety and challenge

| Week | Feature | Deliverables |
|------|---------|--------------|
| 17-18 | Decorative Buildings | 10+ decorations, happiness integration |
| 19-20 | Events System | Event manager, 5+ disaster types, 5+ bonus types |

**Dependencies:** Happiness (for effect integration), Stellar Map (for route disruptions)

**Risks:** Medium (balancing)

---

## 6. Risk Assessment

### 6.1 Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Performance degradation with 100+ buildings | Medium | High | Profile early, implement spatial partitioning |
| Save file corruption with new data | Low | Critical | Versioned migrations, backup system |
| Event system creates unwinnable states | Medium | High | Implement difficulty scaling, recovery mechanics |
| Trade route sync issues across planets | Medium | Medium | Deterministic calculations, thorough testing |
| Memory pressure from sprites/animations | Medium | Medium | Lazy loading, sprite atlases, LOD |

### 6.2 Design Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Happiness system too punishing | High | Medium | Extensive playtesting, tunable parameters |
| Quest content gets stale | Medium | Medium | Procedural quest generation, regular updates |
| Trade routes too complex for casual players | Medium | Medium | Tutorial, sensible defaults, auto-trade option |
| Events feel unfair to players | High | High | Warning systems, mitigation buildings, difficulty options |

### 6.3 Resource Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Art asset creation bottleneck | High | Medium | Prioritize critical assets, procedural generation |
| Testing coverage for event combinations | Medium | Medium | Automated testing, seed-based replay |
| Scope creep during implementation | High | High | Strict MVP definitions, feature flags |

---

## 7. Open Questions

### 7.1 Gameplay Balance

1. **Happiness decay rate:** How quickly should happiness decrease when needs are unmet?
   - Proposed: 1 point per minute if any factor below threshold

2. **Event frequency:** How often should random events trigger?
   - Proposed: Base 1% per minute, scaling with planet development

3. **Trade route travel time:** What should be the relationship between distance and time?
   - Proposed: `travelTime = baseTime + (distance * distanceMultiplier)`

4. **Upgrade cost scaling:** Should upgrade costs scale linearly or exponentially?
   - Current: Linear (`baseCost * level`). Consider exponential for balance.

### 7.2 Technical Decisions

1. **Persistence format:** Continue with SharedPreferences or migrate to SQLite/Hive?
   - Recommendation: Migrate to structured format before Phase 4

2. **Event seeding:** Should events be reproducible for testing/replays?
   - Recommendation: Yes, use planet ID + timestamp as seed

3. **Notification architecture:** Unified system or feature-specific?
   - Recommendation: Unified `NotificationManager` with typed notifications

### 7.3 Content Scope

1. **Number of decorative building types:** Minimum 10 specified, what is ideal count?
   - Recommendation: 15-20 for launch, expandable through updates

2. **Quest content creation process:** Manual authoring or procedural generation?
   - Recommendation: Hybrid (authored story quests + procedural daily quests)

3. **Planet variety:** How many distinct planet types should exist?
   - Recommendation: 5-7 biome-based planet types, each with unique resources

### 7.4 Stakeholder Input Needed

1. **Monetization integration:** Should decorations or planet unlocks be purchasable?

2. **Multiplayer considerations:** Should trade routes eventually support player-to-player trade?

3. **Difficulty modes:** Should there be explicit easy/normal/hard modes affecting events?

4. **Tutorial scope:** How extensive should new player onboarding be for each feature?

---

## Appendix A: Glossary

| Term | Definition |
|------|------------|
| Building | Placeable structure on the grid with optional resource production/consumption |
| Happiness | 0-100 score representing colonist satisfaction |
| Planet | Independent game instance with own resources, buildings, and research |
| Production Chain | Sequence of buildings that transform raw materials into finished goods |
| Quest | Objective-based challenge with defined completion criteria and rewards |
| Trade Route | Connection between planets for automated resource transfer |

## Appendix B: Related Documents

- `CLAUDE.md` - Codebase overview and development guidelines
- `docs/TERRAIN_SYSTEM_SUMMARY.md` - Procedural terrain generation details
- `docs/PARALLAX_TERRAIN_GUIDE.md` - Parallax layer implementation

## Appendix C: File Reference

| Feature | Primary Files |
|---------|--------------|
| Core Game | `lib/game/main_game.dart`, `lib/game/scene_widget.dart`, `lib/game/grid.dart` |
| Resources | `lib/game/resources/resources.dart`, `lib/game/resources/resource_type.dart` |
| Buildings | `lib/game/building/building.dart`, `lib/game/building/category.dart` |
| Research | `lib/game/research/research.dart` |
| Planets | `lib/game/planet/planet.dart`, `lib/game/services/save_service.dart` |
| UI | `lib/widgets/game/*.dart`, `lib/widgets/cards/*.dart` |
| Terrain | `lib/game/terrain/*.dart` |

---

*Document End*
