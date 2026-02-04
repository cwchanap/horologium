import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horologium/game/building/building.dart';
import 'package:horologium/game/building/category.dart';
import 'package:horologium/game/production/production_graph.dart';
import 'package:horologium/game/resources/resource_type.dart';
import 'package:horologium/game/resources/resources.dart';
import 'package:horologium/widgets/game/production_overlay/building_node.dart';
import 'package:horologium/widgets/game/production_overlay/cluster_node.dart';
import 'package:horologium/widgets/game/production_overlay/empty_state.dart';
import 'package:horologium/widgets/game/production_overlay/node_detail_panel.dart';
import 'package:horologium/widgets/game/production_overlay/production_overlay.dart';
import 'package:horologium/widgets/game/production_overlay/resource_flow_edge.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ProductionOverlay', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('shows empty state when no buildings', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProductionOverlay(
            getBuildings: () => [],
            getResources: () => Resources(),
            onClose: () {},
          ),
        ),
      );

      expect(find.byType(EmptyStateWidget), findsOneWidget);
      expect(find.text('No production buildings'), findsOneWidget);
    });

    testWidgets('shows graph when buildings exist', (tester) async {
      final buildings = [
        _createTestBuilding(
          type: BuildingType.coalMine,
          generation: {'coal': 1.0},
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ProductionOverlay(
            getBuildings: () => buildings,
            getResources: () => Resources(),
            onClose: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should not show empty state
      expect(find.byType(EmptyStateWidget), findsNothing);
    });

    testWidgets('cluster stays visible after expanding', (tester) async {
      final buildings = List.generate(
        51,
        (index) => _createTestBuilding(type: BuildingType.house),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProductionOverlay(
            getBuildings: () => buildings,
            getResources: () => Resources(),
            onClose: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ClusterNodeWidget), findsOneWidget);
      expect(find.byIcon(Icons.unfold_more), findsOneWidget);

      await tester.tap(find.byType(ClusterNodeWidget));
      await tester.pumpAndSettle();

      expect(find.byType(ClusterNodeWidget), findsOneWidget);
      expect(find.byIcon(Icons.unfold_less), findsOneWidget);
    });

    testWidgets('close button calls onClose', (tester) async {
      var closeCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ProductionOverlay(
            getBuildings: () => [],
            getResources: () => Resources(),
            onClose: () => closeCalled = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(closeCalled, isTrue);
    });

    testWidgets('displays header with title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProductionOverlay(
            getBuildings: () => [],
            getResources: () => Resources(),
            onClose: () {},
          ),
        ),
      );

      expect(find.text('Production Chain'), findsOneWidget);
    });
  });

  group('BuildingNodeWidget', () {
    testWidgets('displays node name', (tester) async {
      final node = BuildingNode(
        id: 'test',
        name: 'Test Building',
        type: BuildingType.house,
        category: BuildingCategory.residential,
        inputs: [],
        outputs: [],
        status: FlowStatus.balanced,
        hasWorkers: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BuildingNodeWidget(node: node)),
        ),
      );

      expect(find.text('Test Building'), findsOneWidget);
    });

    testWidgets('shows status icon for surplus', (tester) async {
      final node = BuildingNode(
        id: 'test',
        name: 'Test',
        type: BuildingType.house,
        category: BuildingCategory.residential,
        inputs: [],
        outputs: [],
        status: FlowStatus.surplus,
        hasWorkers: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BuildingNodeWidget(node: node)),
        ),
      );

      // Check for green checkmark indicator
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows status icon for deficit', (tester) async {
      final node = BuildingNode(
        id: 'test',
        name: 'Test',
        type: BuildingType.house,
        category: BuildingCategory.residential,
        inputs: [],
        outputs: [],
        status: FlowStatus.deficit,
        hasWorkers: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BuildingNodeWidget(node: node)),
        ),
      );

      // Check for red X indicator
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows no workers warning', (tester) async {
      final node = BuildingNode(
        id: 'test',
        name: 'Test',
        type: BuildingType.house,
        category: BuildingCategory.residential,
        inputs: [],
        outputs: [],
        status: FlowStatus.balanced,
        hasWorkers: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BuildingNodeWidget(node: node)),
        ),
      );

      expect(find.text('No workers'), findsOneWidget);
    });

    testWidgets('tap callback is triggered', (tester) async {
      var tapped = false;
      final node = BuildingNode(
        id: 'test',
        name: 'Test',
        type: BuildingType.house,
        category: BuildingCategory.residential,
        inputs: [],
        outputs: [],
        status: FlowStatus.balanced,
        hasWorkers: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingNodeWidget(node: node, onTap: () => tapped = true),
          ),
        ),
      );

      await tester.tap(find.byType(BuildingNodeWidget));
      expect(tapped, isTrue);
    });

    testWidgets('double tap callback is triggered', (tester) async {
      var doubleTapped = false;
      final node = BuildingNode(
        id: 'test',
        name: 'Test',
        type: BuildingType.house,
        category: BuildingCategory.residential,
        inputs: [],
        outputs: [],
        status: FlowStatus.balanced,
        hasWorkers: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BuildingNodeWidget(
              node: node,
              onDoubleTap: () => doubleTapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(BuildingNodeWidget));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(BuildingNodeWidget));
      await tester.pumpAndSettle();
      expect(doubleTapped, isTrue);
    });
  });

  group('ResourceFilterWidget', () {
    testWidgets('filter dropdown shows all resources option', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProductionOverlay(
            getBuildings: () => [],
            getResources: () => Resources(),
            onClose: () {},
          ),
        ),
      );

      // Find the filter dropdown
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });
  });

  group('NodeDetailPanel', () {
    testWidgets('displays node name', (tester) async {
      final node = BuildingNode(
        id: 'test',
        name: 'Test Factory',
        type: BuildingType.powerPlant,
        category: BuildingCategory.processing,
        inputs: [],
        outputs: [],
        status: FlowStatus.balanced,
        hasWorkers: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NodeDetailPanel(node: node)),
        ),
      );

      expect(find.text('Test Factory'), findsOneWidget);
    });

    testWidgets('displays input resources with rates', (tester) async {
      final node = BuildingNode(
        id: 'test',
        name: 'Test',
        type: BuildingType.powerPlant,
        category: BuildingCategory.processing,
        inputs: [
          ResourcePort(
            resourceType: ResourceType.coal,
            ratePerSecond: 1.5,
            status: FlowStatus.balanced,
          ),
        ],
        outputs: [],
        status: FlowStatus.balanced,
        hasWorkers: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NodeDetailPanel(node: node)),
        ),
      );

      expect(find.text('Inputs (Consumption)'), findsOneWidget);
      expect(find.text('1.5/s'), findsOneWidget);
    });

    testWidgets('displays output resources with rates', (tester) async {
      final node = BuildingNode(
        id: 'test',
        name: 'Test',
        type: BuildingType.powerPlant,
        category: BuildingCategory.processing,
        inputs: [],
        outputs: [
          ResourcePort(
            resourceType: ResourceType.electricity,
            ratePerSecond: 2.0,
            status: FlowStatus.surplus,
          ),
        ],
        status: FlowStatus.surplus,
        hasWorkers: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NodeDetailPanel(node: node)),
        ),
      );

      expect(find.text('Outputs (Production)'), findsOneWidget);
      expect(find.text('2.0/s'), findsOneWidget);
    });

    testWidgets('shows bottleneck recommendation when provided', (
      tester,
    ) async {
      final node = BuildingNode(
        id: 'test',
        name: 'Test',
        type: BuildingType.powerPlant,
        category: BuildingCategory.processing,
        inputs: [],
        outputs: [],
        status: FlowStatus.deficit,
        hasWorkers: true,
      );

      final bottleneck = BottleneckInsight(
        id: 'bottleneck1',
        resourceType: ResourceType.coal,
        severity: BottleneckSeverity.high,
        description: 'Coal shortage detected',
        recommendation: 'Build more coal mines',
        impactedNodeIds: ['test'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NodeDetailPanel(node: node, bottleneck: bottleneck),
          ),
        ),
      );

      expect(find.text('Coal shortage detected'), findsOneWidget);
      expect(find.text('Build more coal mines'), findsOneWidget);
    });

    testWidgets('shows no workers warning when building has no workers', (
      tester,
    ) async {
      final node = BuildingNode(
        id: 'test',
        name: 'Test',
        type: BuildingType.powerPlant,
        category: BuildingCategory.processing,
        inputs: [],
        outputs: [],
        status: FlowStatus.balanced,
        hasWorkers: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: NodeDetailPanel(node: node)),
        ),
      );

      expect(find.text('No workers assigned - building idle'), findsOneWidget);
    });

    testWidgets('close button calls onClose', (tester) async {
      var closeCalled = false;
      final node = BuildingNode(
        id: 'test',
        name: 'Test',
        type: BuildingType.powerPlant,
        category: BuildingCategory.processing,
        inputs: [],
        outputs: [],
        status: FlowStatus.balanced,
        hasWorkers: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NodeDetailPanel(
              node: node,
              onClose: () => closeCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(closeCalled, isTrue);
    });
  });

  group('ClusterNodeWidget', () {
    testWidgets('displays category name', (tester) async {
      final cluster = NodeCluster(
        id: 'cluster1',
        category: BuildingCategory.processing,
        nodeIds: ['node1', 'node2'],
        aggregateStatus: FlowStatus.balanced,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ClusterNodeWidget(cluster: cluster)),
        ),
      );

      expect(find.text('Processing'), findsOneWidget);
    });

    testWidgets('displays node count', (tester) async {
      final cluster = NodeCluster(
        id: 'cluster1',
        category: BuildingCategory.residential,
        nodeIds: List.generate(15, (i) => 'node_$i'),
        aggregateStatus: FlowStatus.surplus,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ClusterNodeWidget(cluster: cluster)),
        ),
      );

      expect(find.text('15 buildings'), findsOneWidget);
    });

    testWidgets('tap callback is triggered', (tester) async {
      var tapped = false;
      final cluster = NodeCluster(
        id: 'cluster1',
        category: BuildingCategory.rawMaterials,
        nodeIds: ['node1'],
        aggregateStatus: FlowStatus.balanced,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClusterNodeWidget(
              cluster: cluster,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ClusterNodeWidget));
      expect(tapped, isTrue);
    });

    testWidgets('shows expand icon when collapsed', (tester) async {
      final cluster = NodeCluster(
        id: 'cluster1',
        category: BuildingCategory.services,
        nodeIds: ['node1'],
        aggregateStatus: FlowStatus.balanced,
        isExpanded: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ClusterNodeWidget(cluster: cluster)),
        ),
      );

      expect(find.byIcon(Icons.unfold_more), findsOneWidget);
    });

    testWidgets('shows collapse icon when expanded', (tester) async {
      final cluster = NodeCluster(
        id: 'cluster1',
        category: BuildingCategory.services,
        nodeIds: ['node1'],
        aggregateStatus: FlowStatus.balanced,
        isExpanded: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ClusterNodeWidget(cluster: cluster)),
        ),
      );

      expect(find.byIcon(Icons.unfold_less), findsOneWidget);
    });
  });

  group('EmptyStateWidget', () {
    testWidgets('displays message text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EmptyStateWidget())),
      );

      expect(find.text('No production buildings'), findsOneWidget);
    });

    testWidgets('displays icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EmptyStateWidget())),
      );

      expect(find.byIcon(Icons.account_tree_outlined), findsOneWidget);
    });
  });

  group('BuildingNodeWidget visual states', () {
    testWidgets('applies dimmed opacity when isDimmed is true', (tester) async {
      final node = BuildingNode(
        id: 'test',
        name: 'Test',
        type: BuildingType.house,
        category: BuildingCategory.residential,
        inputs: [],
        outputs: [],
        status: FlowStatus.balanced,
        hasWorkers: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BuildingNodeWidget(node: node, isDimmed: true)),
        ),
      );

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(animatedOpacity.opacity, equals(0.3));
    });

    testWidgets('applies full opacity when isDimmed is false', (tester) async {
      final node = BuildingNode(
        id: 'test',
        name: 'Test',
        type: BuildingType.house,
        category: BuildingCategory.residential,
        inputs: [],
        outputs: [],
        status: FlowStatus.balanced,
        hasWorkers: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BuildingNodeWidget(node: node, isDimmed: false)),
        ),
      );

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(animatedOpacity.opacity, equals(1.0));
    });

    testWidgets('shows balanced status icon', (tester) async {
      final node = BuildingNode(
        id: 'test',
        name: 'Test',
        type: BuildingType.house,
        category: BuildingCategory.residential,
        inputs: [],
        outputs: [],
        status: FlowStatus.balanced,
        hasWorkers: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BuildingNodeWidget(node: node)),
        ),
      );

      // Balanced shows dash/remove icon
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });
  });

  group('ResourceFlowEdgeWidget', () {
    testWidgets('renders SizedBox.shrink when startNode is null', (
      tester,
    ) async {
      final edge = ResourceFlowEdge(
        id: 'edge1',
        producerNodeId: 'node1',
        consumerNodeId: 'node2',
        resourceType: ResourceType.coal,
        ratePerSecond: 1.0,
        status: FlowStatus.balanced,
        isIncomplete: false,
        isHighlighted: false,
      );

      final endNode = BuildingNode(
        id: 'node2',
        type: BuildingType.powerPlant,
        name: 'Power Plant',
        category: BuildingCategory.primaryFactory,
        position: const Offset(200, 100),
        inputs: [],
        outputs: [],
        status: FlowStatus.balanced,
        hasWorkers: true,
        isSelected: false,
        isHighlighted: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ResourceFlowEdgeWidget(
            edge: edge,
            startNode: null,
            endNode: endNode,
          ),
        ),
      );

      // Widget should return SizedBox.shrink
      final widget = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(widget.width, equals(0.0));
      expect(widget.height, equals(0.0));
    });

    testWidgets('renders SizedBox.shrink when endNode is null', (tester) async {
      final edge = ResourceFlowEdge(
        id: 'edge1',
        producerNodeId: 'node1',
        consumerNodeId: 'node2',
        resourceType: ResourceType.coal,
        ratePerSecond: 1.0,
        status: FlowStatus.balanced,
        isIncomplete: false,
        isHighlighted: false,
      );

      final startNode = BuildingNode(
        id: 'node1',
        type: BuildingType.coalMine,
        name: 'Coal Mine',
        category: BuildingCategory.rawMaterials,
        position: const Offset(100, 100),
        inputs: [],
        outputs: [],
        status: FlowStatus.balanced,
        hasWorkers: true,
        isSelected: false,
        isHighlighted: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ResourceFlowEdgeWidget(
            edge: edge,
            startNode: startNode,
            endNode: null,
          ),
        ),
      );

      // Widget should return SizedBox.shrink
      final widget = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(widget.width, equals(0.0));
      expect(widget.height, equals(0.0));
    });

    testWidgets('renders edge when both nodes exist', (tester) async {
      final edge = ResourceFlowEdge(
        id: 'edge1',
        producerNodeId: 'node1',
        consumerNodeId: 'node2',
        resourceType: ResourceType.coal,
        ratePerSecond: 1.0,
        status: FlowStatus.balanced,
        isIncomplete: false,
        isHighlighted: false,
      );

      final startNode = BuildingNode(
        id: 'node1',
        type: BuildingType.coalMine,
        name: 'Coal Mine',
        category: BuildingCategory.rawMaterials,
        position: const Offset(100, 100),
        inputs: [],
        outputs: [],
        status: FlowStatus.balanced,
        hasWorkers: true,
        isSelected: false,
        isHighlighted: false,
      );

      final endNode = BuildingNode(
        id: 'node2',
        type: BuildingType.powerPlant,
        name: 'Power Plant',
        category: BuildingCategory.primaryFactory,
        position: const Offset(300, 100),
        inputs: [],
        outputs: [],
        status: FlowStatus.balanced,
        hasWorkers: true,
        isSelected: false,
        isHighlighted: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResourceFlowEdgeWidget(
              edge: edge,
              startNode: startNode,
              endNode: endNode,
            ),
          ),
        ),
      );

      // Should render CustomPaint for the edge (may be multiple layers)
      expect(find.byType(CustomPaint), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(ResourceFlowEdgeWidget),
          matching: find.byType(SizedBox),
        ),
        findsNothing,
      );
    });

    testWidgets('disposes animation controller properly', (tester) async {
      final edge = ResourceFlowEdge(
        id: 'edge1',
        producerNodeId: 'node1',
        consumerNodeId: 'node2',
        resourceType: ResourceType.coal,
        ratePerSecond: 1.0,
        status: FlowStatus.balanced,
        isIncomplete: false,
        isHighlighted: false,
      );

      final startNode = BuildingNode(
        id: 'node1',
        type: BuildingType.coalMine,
        name: 'Coal Mine',
        category: BuildingCategory.rawMaterials,
        position: const Offset(100, 100),
        inputs: [],
        outputs: [],
        status: FlowStatus.balanced,
        hasWorkers: true,
        isSelected: false,
        isHighlighted: false,
      );

      final endNode = BuildingNode(
        id: 'node2',
        type: BuildingType.powerPlant,
        name: 'Power Plant',
        category: BuildingCategory.primaryFactory,
        position: const Offset(300, 100),
        inputs: [],
        outputs: [],
        status: FlowStatus.balanced,
        hasWorkers: true,
        isSelected: false,
        isHighlighted: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResourceFlowEdgeWidget(
              edge: edge,
              startNode: startNode,
              endNode: endNode,
            ),
          ),
        ),
      );

      // Dispose the widget
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      // No assertion needed - if animation controller wasn't disposed,
      // this would throw or cause memory leaks detectable in debug mode
    });
  });
}

Building _createTestBuilding({
  required BuildingType type,
  Map<String, double> generation = const {},
  Map<String, double> consumption = const {},
}) {
  return Building(
    type: type,
    name: type.name,
    description: 'Test',
    icon: Icons.home,
    assetPath: '',
    color: Colors.blue,
    baseCost: 100,
    baseGeneration: generation,
    baseConsumption: consumption,
    requiredWorkers: 1,
    category: BuildingCategory.residential,
  );
}
