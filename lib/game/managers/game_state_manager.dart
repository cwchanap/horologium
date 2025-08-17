import 'dart:async' as async;
import 'package:flutter/material.dart';

import '../building/building.dart';
import '../research/research.dart';
import '../resources/resources.dart';
import '../services/resource_service.dart';

class GameStateManager {
  final Resources resources;
  final ResearchManager researchManager = ResearchManager();
  final BuildingLimitManager buildingLimitManager = BuildingLimitManager();
  
  async.Timer? _resourceTimer;
  
  GameStateManager({required this.resources});

  void startResourceGeneration(List<Building> Function() getBuildingsCallback, VoidCallback onUpdate) {
    _resourceTimer = async.Timer.periodic(const Duration(seconds: 1), (timer) {
      final buildings = getBuildingsCallback();
      ResourceService.updateResources(resources, buildings);
      onUpdate();
    });
  }

  void stopResourceGeneration() {
    _resourceTimer?.cancel();
    _resourceTimer = null;
  }

  void dispose() {
    stopResourceGeneration();
  }
}