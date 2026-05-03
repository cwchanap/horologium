# Production Chain Recommendations

This document captures improvement ideas for Horologium's production-chain
system. The current chain reference lives in `docs/production_chains.md`.

## Recommendation Summary

1. Add downstream uses for existing intermediate resources.
2. Add partial utilization to the production analyzer.
3. Improve bottleneck recommendations.
4. Separate economy data from building UI metadata.
5. Add chain validation tests.
6. Show locked or missing chain steps in the production overlay.
7. Revisit current production ratios.

## 1. Add Downstream Uses For Existing Intermediates

Several current resources are produced but have no in-colony downstream
consumer:

- `cornmeal`
- `polishedRice`
- `maltedBarley`
- `planks`
- `stone`

These resources should either become meaningful production inputs or be
explicitly treated as terminal trade/export resources. The stronger gameplay
choice is to add downstream uses so each crop path has a reason to exist.

Possible chain extensions:

| Existing Output | Possible Consumer | New Output |
| --- | --- | --- |
| cornmeal | Kitchen, Food Factory, or Canteen | ration packs, tortillas, or meal kits |
| polished rice | Kitchen, Food Factory, or Canteen | rice bowls or preserved meals |
| malted barley | Brewery or Fermentation Vat | beer or nutrient drink |
| planks + stone | Workshop or Construction Yard | building materials |
| bread + pastries + water | Market or Canteen | happiness/service output |

## 2. Add Partial Utilization

The current analyzer treats buildings as binary: a node can produce or it cannot.
Factory-style feedback would be clearer if nodes had utilization from `0.0` to
`1.0`.

Example:

- A Wind Mill needs 5 wheat/s and produces 1 flour/s.
- The colony produces 2.5 wheat/s.
- The Wind Mill runs at 50% and produces 0.5 flour/s.

This would make bottlenecks less abrupt and give players clearer information
about how much additional supply is needed.

## 3. Improve Bottleneck Recommendations

Current recommendations choose a producer from the building registry and suggest
adding more of it. Better recommendations should inspect colony state and return
the most actionable next step.

Recommendation cases:

- assign workers to idle producers;
- add a missing producer;
- switch a `Field` to the crop needed by the bottleneck;
- switch a `Bakery` product when flour is constrained;
- research a locked producer;
- upgrade an existing producer;
- increase building limits when adding more producers is blocked;
- buy or trade for short-term input coverage if the resource is available in the
  market.

## 4. Separate Economy Data From Building UI Metadata

`BuildingRegistry.availableBuildings` currently mixes:

- production and consumption rates;
- worker requirements;
- costs and limits;
- research pacing;
- icons, colors, sprites, descriptions;
- runtime defaults.

As chains grow, production tuning will be easier if recipe data lives in a
dedicated economy definition layer.

Possible shape:

```dart
class ProductionRecipe {
  final Map<ResourceType, double> inputs;
  final Map<ResourceType, double> outputs;
  final int workers;
}

class BuildingEconomyDefinition {
  final BuildingType type;
  final List<ProductionRecipe> recipes;
}
```

The current `Building` class can keep runtime state while recipe definitions
become easier to validate and balance.

## 5. Add Chain Validation Tests

Add economy-level tests that prevent accidental chain regressions.

Suggested checks:

- every consumed resource has at least one producer or is explicitly external;
- every produced intermediate has a consumer or is explicitly terminal;
- every research-gated building is unlocked by the intended research path;
- every dynamic recipe variant appears in graph signatures and graph tests;
- every recommendation path has a test fixture.

## 6. Show Locked Or Missing Chain Steps

The production overlay can become a planning tool by showing missing or locked
steps in a filtered chain.

Example for bread:

`Field(wheat) -> Wind Mill [not built or locked] -> Bakery [not built or locked]`

This helps players understand whether a bottleneck is caused by missing
infrastructure, missing research, missing workers, or missing inputs.

## 7. Revisit Production Ratios

Some current ratios may create extreme demand early in the game.

The clearest example is:

`Sawmill: 10 wood/s -> 1 planks/s`

At level 1, one Sawmill requires 10 Wood Factories to run continuously. That may
be intended, but it should be reviewed against unlock timing, building limits,
and expected early-game pacing.
