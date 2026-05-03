# Production Chain Expansion Design

## Purpose

Expand Horologium's production chains in a balanced first slice:

- give existing food intermediates meaningful downstream outputs;
- make `planks` and `stone` useful through upgrade costs;
- replace one-off bottleneck messages with a deterministic recommendation
  engine.

This design intentionally avoids a full production-recipe refactor. It uses the
existing `Building`, `Resources`, `ResearchManager`, `BuildingLimitManager`, and
production graph patterns.

## Current Context

Current intermediate resources include:

- `cornmeal` from `Field(corn) -> Grinder Mill`;
- `polishedRice` from `Field(rice) -> Rice Huller`;
- `maltedBarley` from `Field(barley) -> Malt House`;
- `planks` from `Wood Factory -> Sawmill`;
- `stone` from `Quarry`.

`cornmeal`, `polishedRice`, and `maltedBarley` are produced but have no
in-colony downstream consumer. `planks` and `stone` also need stronger in-colony
uses.

The production overlay is derived from placed building generation and
consumption maps, so new chains should appear automatically once buildings and
resources are registered.

## Scope

In scope:

- add a new recipe-style `Kitchen` building;
- add distinct stored outputs for existing food intermediates;
- include the new finished foods in happiness food satisfaction;
- change upgrade costs from cash-only to a `ResourceCost` value object;
- use `planks` and `stone` directly in selected upgrade costs;
- add a small `ProductionRecommendationEngine`;
- add persistence and tests for the new resources, building mode, upgrade costs,
  and recommendation rules.

Out of scope:

- partial utilization;
- ghost nodes for missing or locked chain steps;
- full recipe abstraction;
- placement costs as multi-resource costs;
- trade/market changes;
- custom generated art assets. Use existing asset fallback behavior or a simple
  code-level fallback rendering if a dedicated sprite is unavailable.

## Food Chain Design

Add one new building type: `Kitchen`.

`Kitchen` should follow the same runtime pattern as `Bakery`: one building type
with a selectable product mode.

Add a `KitchenProduct` enum with three product modes:

| Product Mode | Inputs | Outputs | Role |
| --- | --- | --- | --- |
| `tortillas` | 2 cornmeal/s + 1 water/s | 1 tortillas/s | Finished food |
| `riceMeals` | 2 polishedRice/s + 1 water/s | 1 riceMeals/s | Finished food |
| `maltDrink` | 2 maltedBarley/s + 1 water/s | 1 maltDrink/s | Food/service drink |

Add stored resources:

- `tortillas`;
- `riceMeals`;
- `maltDrink`.

These resources should initialize to zero, persist through save/load, and appear
where resource details are shown. The happiness food factor should include:

```text
bread + pastries + tortillas + riceMeals + maltDrink
```

Research gate:

- unlock `Kitchen` through the existing `Food Processing` research node.

Rationale:

- one building avoids three nearly identical new building types;
- distinct outputs preserve real-world production-chain flavor;
- stored outputs fit the existing resource and production overlay model;
- using `maltDrink` instead of `beer` keeps the tone broad and avoids alcohol
  specificity.

## Construction And Upgrade Cost Design

Upgrade costs should support multiple resource types.

Preferred implementation shape:

```dart
class ResourceCost {
  final Map<ResourceType, double> resources;
}
```

`ResourceCost` should centralize:

- affordability checks against `Resources`;
- deduction from `Resources`;
- display iteration for UI;
- empty and cash-only construction helpers.

Placement cost remains cash-only through the existing `baseCost` field in this
slice. Upgrade costs become multi-resource costs.

Initial upgrade-cost pattern:

| Building Group | Upgrade Cost Resources |
| --- | --- |
| Residential | cash + planks |
| Large/advanced residential | cash + planks + stone |
| Raw material producers | cash + planks |
| Services | cash + stone |
| Processing/refinement buildings | cash + planks + stone |
| Kitchen | cash + planks |

Exact numeric balancing can be conservative in the first implementation. A
simple level-based formula is sufficient:

```text
cash = existing upgrade cash cost
material amount = level being purchased * group multiplier
```

The implementation should preserve current upgrade behavior where possible:

- if a building only has cash in its upgrade cost, existing flows should behave
  the same;
- failed upgrades should not deduct any resource;
- successful upgrades should deduct every listed resource atomically.

## Recommendation Engine Design

Add `ProductionRecommendationEngine` as a separate production-domain service.
Do not embed this logic directly into `FlowAnalyzer`.

Inputs:

- analyzed `ProductionGraph`;
- placed buildings;
- current `Resources`;
- `ResearchManager`;
- `BuildingLimitManager`.

Output:

- one primary recommendation for each bottleneck resource;
- supporting context for UI display and tests, including recommendation type,
  target building type when applicable, and missing resources when applicable.

Rule priority:

1. Assign workers to an existing producer that is idle.
2. Switch an existing dynamic producer recipe:
   - `Field.cropType` for wheat, corn, rice, and barley shortages;
   - `Bakery.productType` where bakery output choice matters;
   - `Kitchen.productType` for tortillas, riceMeals, and maltDrink.
3. Upgrade an existing producer if upgrade is possible.
4. If upgrade is not affordable, explain the missing upgrade inputs.
5. Build an unlocked producer when under the building limit.
6. Research the producer unlock if the producer is locked.
7. Explain that the resource has no available producer in the current economy.

The engine should be deterministic. It should not attempt simulation or cost
optimization in this slice.

Special resource mapping is required for dynamic producers:

| Resource | Producer Hint |
| --- | --- |
| wheat | Field set to wheat |
| corn | Field set to corn |
| rice | Field set to rice |
| barley | Field set to barley |
| bread | Bakery set to bread |
| pastries | Bakery set to pastries |
| tortillas | Kitchen set to tortillas |
| riceMeals | Kitchen set to riceMeals |
| maltDrink | Kitchen set to maltDrink |

## UI Design

Upgrade UI should display multi-resource upgrade costs as resource chips or icon
rows, matching existing resource display patterns.

Required UI behavior:

- show every resource in the upgrade cost;
- mark unavailable resources clearly;
- disable or block upgrade when any required resource is missing;
- keep current cash-only display readable for buildings without material costs.

Production overlay behavior:

- no custom overlay changes are required for graph construction;
- Kitchen nodes and new resources should appear through generation/consumption
  maps;
- bottleneck recommendation display can use the new engine output where
  bottlenecks are already surfaced.

Resource UI:

- include `tortillas`, `riceMeals`, and `maltDrink` in resource details and
  icon/name lookup paths.

## Persistence

Persist:

- `tortillas`;
- `riceMeals`;
- `maltDrink`;
- `Kitchen.productType`.

Follow the existing `Bakery.productType` and resource save/load patterns.

Backward compatibility:

- saves without new resource keys should load the new resource values as zero;
- saves without kitchen product mode should default to `tortillas`.

## Testing

Add or update tests for:

- resource initialization for new resources;
- save/load of new resources;
- save/load of `Kitchen.productType`;
- Kitchen generation and consumption for each product mode;
- happiness food calculation includes new finished foods;
- upgrade cost affordability with multiple resources;
- upgrade deduction is atomic;
- failed upgrades do not partially deduct resources;
- production graph includes Kitchen chains;
- recommendation engine rule priority;
- worker recommendation;
- dynamic `Field` crop recommendation;
- dynamic `Kitchen` product recommendation;
- upgrade recommendation and missing-upgrade-input recommendation;
- build unlocked producer recommendation;
- locked research recommendation;
- no-producer fallback.

## Acceptance Criteria

- `cornmeal`, `polishedRice`, and `maltedBarley` each have a downstream Kitchen
  recipe.
- `tortillas`, `riceMeals`, and `maltDrink` are stored, displayed, saved, and
  loaded.
- Food happiness includes the three new finished foods.
- Upgrade costs can include resources other than cash.
- `planks` and `stone` are used directly in selected upgrade costs.
- Production graph reflects the new Kitchen chains without bespoke graph code.
- Bottleneck recommendations are generated by `ProductionRecommendationEngine`
  with deterministic rule priority.
- Existing saves load without migration failure.
