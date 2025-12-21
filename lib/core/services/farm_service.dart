import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:ai_detection/core/models/farm_model.dart';
import 'package:ai_detection/core/services/storage_service.dart';

class FarmService extends ChangeNotifier {
  static late final FarmService _instance = FarmService._internal();
  static FarmService get instance => _instance;

  final List<FarmModel> _farms = [];
  String? _currentUserId;

  List<FarmModel> get farms => List.unmodifiable(_farms);

  FarmService._internal();

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    _farms.clear();
    _loadFarms();
  }

  void clearData() {
    _currentUserId = null;
    _farms.clear();
    notifyListeners();
  }

  Future<void> _loadFarms() async {
    final farmsJson = StorageService.instance.getString('farms', userId: _currentUserId);
    if (farmsJson != null) {
      final List<dynamic> decoded = jsonDecode(farmsJson);
      _farms.clear();
      _farms.addAll(
        decoded.map((f) => FarmModel.fromJson(f as Map<String, dynamic>)),
      );
      notifyListeners();
    }
  }

  Future<void> _saveFarms() async {
    final encoded = jsonEncode(_farms.map((f) => f.toJson()).toList());
    await StorageService.instance.saveString('farms', encoded, userId: _currentUserId);
    notifyListeners();
  }


  Future<void> addFarm(String name, String location, String cropType) async {
    final farm = FarmModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      location: location,
      cropType: cropType,
      plants: [],
    );
    _farms.add(farm);
    await _saveFarms();
  }

  FarmModel? getFarmById(String id) {
    try {
      return _farms.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addPlantToFarm(String farmId, String name, String imagePath, PlantStatus status) async {
    final farmIndex = _farms.indexWhere((f) => f.id == farmId);
    if (farmIndex == -1) return;
    final farm = _farms[farmIndex];
    final plant = PlantModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      imagePath: imagePath,
      status: status,
      createdAt: DateTime.now(),
    );
    final updatedPlants = [...farm.plants, plant];
    _farms[farmIndex] = FarmModel(
      id: farm.id,
      name: farm.name,
      location: farm.location,
      cropType: farm.cropType,
      plants: updatedPlants,
    );
    await _saveFarms();
  }

  Future<void> deletePlant(String farmId, String plantId) async {
    final farmIndex = _farms.indexWhere((f) => f.id == farmId);
    if (farmIndex == -1) return;
    final farm = _farms[farmIndex];
    final updatedPlants = farm.plants.where((p) => p.id != plantId).toList();
    _farms[farmIndex] = FarmModel(
      id: farm.id,
      name: farm.name,
      location: farm.location,
      cropType: farm.cropType,
      plants: updatedPlants,
    );
    await _saveFarms();
  }

  Future<void> deleteFarm(String farmId) async {
    _farms.removeWhere((f) => f.id == farmId);
    await _saveFarms();
  }

  Future<void> updatePlantStatus(String farmId, String plantId, PlantStatus newStatus) async {
    final farmIndex = _farms.indexWhere((f) => f.id == farmId);
    if (farmIndex == -1) return;
    final farm = _farms[farmIndex];
    final updatedPlants = farm.plants.map((p) {
      if (p.id == plantId) {
        return PlantModel(
          id: p.id,
          name: p.name,
          imagePath: p.imagePath,
          status: newStatus,
          createdAt: p.createdAt,
        );
      }
      return p;
    }).toList();
    _farms[farmIndex] = FarmModel(
      id: farm.id,
      name: farm.name,
      location: farm.location,
      cropType: farm.cropType,
      plants: updatedPlants,
    );
    await _saveFarms();
  }
}

