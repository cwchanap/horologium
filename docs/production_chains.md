# Production Chains

This document describes the current production chains and the buildings that
participate in them.

## Source Of Truth

Production-chain data comes from `BuildingRegistry.availableBuildings` in
`lib/game/building/building.dart`.

Each placed `Building` contributes:

- `generation`: resources produced per second, scaled by building level.
- `consumption`: resources consumed per second, scaled by building level.
- `requiredWorkers`: worker count required for production.
- `category`: graph grouping used by the production overlay.

`Field` and `Bakery` have dynamic recipes:

- `Field.cropType` selects wheat, corn, rice, or barley.
- `Bakery.productType` selects bread or pastries.

## Production Rules

The live resource tick uses the current placed buildings:

1. Buildings without consumption produce when they have enough assigned workers.
2. Buildings with consumption produce only when all input resources are
   available and the building has enough assigned workers.
3. Buildings with `requiredWorkers == 0`, such as housing, satisfy the worker
   requirement automatically.
4. Inputs are consumed before outputs are generated.
5. Research generation is accumulated and paid out every 10 seconds.

## Full Chain Diagram

```mermaid
flowchart LR
  CoalMine["Coal Mine\n1 coal/s"] --> Coal["Coal"]
  Coal --> PowerPlant["Power Plant\n-1 coal/s\n+1 electricity/s"]
  PowerPlant --> Electricity["Electricity"]
  Electricity --> LargeHouse["Large House\n-1 electricity/s\n-2 water/s\n+3 cash/s\n+8 housing/level"]

  WoodFactory["Wood Factory\n1 wood/s"] --> Wood["Wood"]
  Wood --> House["House\n-1 wood/s\n-1 water/s\n+1 cash/s\n+2 housing/level"]
  Wood --> Sawmill["Sawmill\n-10 wood/s\n+1 planks/s"]
  Sawmill --> Planks["Planks"]

  WaterTreatment["Water Treatment Plant\n2 water/s"] --> Water["Water"]
  Water --> House
  Water --> LargeHouse

  Field["Field\nselected crop"] --> Wheat["Wheat"]
  Field --> Corn["Corn"]
  Field --> Rice["Rice"]
  Field --> Barley["Barley"]

  Wheat --> WindMill["Wind Mill\n-5 wheat/s\n+1 flour/s"]
  WindMill --> Flour["Flour"]
  Flour --> BakeryBread["Bakery: Bread\n-2 flour/s\n+1 bread/s"]
  Flour --> BakeryPastries["Bakery: Pastries\n-3 flour/s\n+1 pastries/s"]
  BakeryBread --> Bread["Bread"]
  BakeryPastries --> Pastries["Pastries"]

  Corn --> GrinderMill["Grinder Mill\n-4 corn/s\n+1 cornmeal/s"]
  GrinderMill --> Cornmeal["Cornmeal"]

  Rice --> RiceHuller["Rice Huller\n-2 rice/s\n+1 polished rice/s"]
  RiceHuller --> PolishedRice["Polished Rice"]

  Barley --> MaltHouse["Malt House\n-2 barley/s\n+1 malted barley/s"]
  MaltHouse --> MaltedBarley["Malted Barley"]

  GoldMine["Gold Mine\n1 gold / 10s"] --> Gold["Gold"]
  Quarry["Quarry\n1 stone/s"] --> Stone["Stone"]
  ResearchLab["Research Lab\n1 research / 10s"] --> Research["Research"]
```

## Chain Groups

### Basic Resource Producers

```mermaid
flowchart LR
  WoodFactory["Wood Factory"] --> Wood["Wood"]
  CoalMine["Coal Mine"] --> Coal["Coal"]
  Quarry["Quarry"] --> Stone["Stone"]
  GoldMine["Gold Mine"] --> Gold["Gold"]
  WaterTreatment["Water Treatment Plant"] --> Water["Water"]
  ResearchLab["Research Lab"] --> Research["Research"]
```

| Building | Inputs | Outputs | Workers | Category | Research Gate |
| --- | --- | --- | --- | --- | --- |
| Wood Factory | None | 1 wood/s | 1 | rawMaterials | None |
| Coal Mine | None | 1 coal/s | 1 | rawMaterials | None |
| Quarry | None | 1 stone/s | 1 | rawMaterials | None |
| Gold Mine | None | 0.1 gold/s | 1 | rawMaterials | Gold Mining |
| Water Treatment Plant | None | 2 water/s | 1 | foodResources | None |
| Research Lab | None | 0.1 research/s | 1 | services | None |

### Energy And Housing

```mermaid
flowchart LR
  CoalMine["Coal Mine"] --> Coal["Coal"]
  Coal --> PowerPlant["Power Plant"]
  PowerPlant --> Electricity["Electricity"]
  Electricity --> LargeHouse["Large House"]

  WoodFactory["Wood Factory"] --> Wood["Wood"]
  WaterTreatment["Water Treatment Plant"] --> Water["Water"]
  Wood --> House["House"]
  Water --> House
  Water --> LargeHouse

  House --> Cash["Cash"]
  House --> Housing["Housing Capacity"]
  LargeHouse --> Cash
  LargeHouse --> Housing
```

| Building | Inputs | Outputs | Workers | Category | Research Gate |
| --- | --- | --- | --- | --- | --- |
| Power Plant | 1 coal/s | 1 electricity/s | 1 | services | Electricity |
| House | 1 wood/s, 1 water/s | 1 cash/s, 2 housing/level | 0 | residential | None |
| Large House | 1 electricity/s, 2 water/s | 3 cash/s, 8 housing/level | 0 | residential | Modern Housing |

### Wood Processing

```mermaid
flowchart LR
  WoodFactory["Wood Factory"] --> Wood["Wood"]
  Wood --> Sawmill["Sawmill"]
  Sawmill --> Planks["Planks"]
```

| Building | Inputs | Outputs | Workers | Category | Research Gate |
| --- | --- | --- | --- | --- | --- |
| Sawmill | 10 wood/s | 1 planks/s | 1 | primaryFactory | None |

### Crop And Food Processing

```mermaid
flowchart LR
  Field["Field"] --> Wheat["Wheat"]
  Field --> Corn["Corn"]
  Field --> Rice["Rice"]
  Field --> Barley["Barley"]

  Wheat --> WindMill["Wind Mill"]
  WindMill --> Flour["Flour"]
  Flour --> BakeryBread["Bakery: Bread"]
  Flour --> BakeryPastries["Bakery: Pastries"]
  BakeryBread --> Bread["Bread"]
  BakeryPastries --> Pastries["Pastries"]

  Corn --> GrinderMill["Grinder Mill"]
  GrinderMill --> Cornmeal["Cornmeal"]

  Rice --> RiceHuller["Rice Huller"]
  RiceHuller --> PolishedRice["Polished Rice"]

  Barley --> MaltHouse["Malt House"]
  MaltHouse --> MaltedBarley["Malted Barley"]
```

| Building | Inputs | Outputs | Workers | Category | Research Gate |
| --- | --- | --- | --- | --- | --- |
| Field | None | 1 selected crop/s | 1 | foodResources | None |
| Wind Mill | 5 wheat/s | 1 flour/s | 1 | processing | Grain Processing |
| Grinder Mill | 4 corn/s | 1 cornmeal/s | 1 | processing | Grain Processing |
| Rice Huller | 2 rice/s | 1 polished rice/s | 1 | processing | Advanced Grain Processing |
| Malt House | 2 barley/s | 1 malted barley/s | 1 | processing | Advanced Grain Processing |
| Bakery: Bread | 2 flour/s | 1 bread/s | 1 | refinement | Food Processing |
| Bakery: Pastries | 3 flour/s | 1 pastries/s | 1 | refinement | Food Processing |

## Current End-To-End Chains

| Chain | Required Buildings | Result |
| --- | --- | --- |
| Coal -> Electricity | Coal Mine -> Power Plant | Electricity |
| Wood + Water -> House output | Wood Factory + Water Treatment Plant -> House | Cash and housing capacity |
| Coal -> Electricity + Water -> Large House output | Coal Mine -> Power Plant + Water Treatment Plant -> Large House | Cash and larger housing capacity |
| Wood -> Planks | Wood Factory -> Sawmill | Planks |
| Wheat -> Flour -> Bread | Field(wheat) -> Wind Mill -> Bakery(bread) | Bread |
| Wheat -> Flour -> Pastries | Field(wheat) -> Wind Mill -> Bakery(pastries) | Pastries |
| Corn -> Cornmeal | Field(corn) -> Grinder Mill | Cornmeal |
| Rice -> Polished Rice | Field(rice) -> Rice Huller | Polished rice |
| Barley -> Malted Barley | Field(barley) -> Malt House | Malted barley |

## Research Gates

| Research | Unlocks |
| --- | --- |
| Electricity | Power Plant |
| Gold Mining | Gold Mine |
| Grain Processing | Wind Mill, Grinder Mill |
| Advanced Grain Processing | Rice Huller, Malt House |
| Modern Housing | Large House |
| Food Processing | Bakery |
