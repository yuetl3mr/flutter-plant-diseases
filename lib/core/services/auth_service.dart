import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:ai_detection/core/models/user_model.dart';
import 'package:ai_detection/core/services/storage_service.dart';
import 'package:ai_detection/core/services/detection_service.dart';
import 'package:ai_detection/core/services/farm_service.dart';

class AuthService extends ChangeNotifier {
  UserModel? _currentUser;
  final List<UserModel> _users = [];

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  AuthService() {
    _loadUsers();
  }

  void _setUserContextForServices() {
    if (_currentUser != null) {
      DetectionService.instance.setCurrentUserId(_currentUser!.id);
      FarmService.instance.setCurrentUserId(_currentUser!.id);
    }
  }

  Future<void> _loadUsers() async {
    final usersJson = StorageService.instance.getString('users');
    if (usersJson != null) {
      final List<dynamic> decoded = jsonDecode(usersJson);
      _users.clear();
      _users.addAll(decoded.map((u) => UserModel.fromJson(u as Map<String, dynamic>)));
      final currentUserId = StorageService.instance.getString('current_user_id');
      if (currentUserId != null) {
        _currentUser = _users.firstWhere(
          (u) => u.id == currentUserId,
          orElse: () => _users.first,
        );
        _setUserContextForServices();
      }
      notifyListeners();
    }
  }

  Future<void> _saveUsers() async {
    final encoded = jsonEncode(_users.map((u) => u.toJson()).toList());
    await StorageService.instance.saveString('users', encoded);
  }

  Future<bool> register(String username, String email, String password) async {
    if (_users.any((u) => u.email == email)) {
      return false;
    }
    final user = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: username,
      email: email,
    );
    _users.add(user);
    await _saveUsers();
    return true;
  }

  Future<bool> login(String email, String password) async {
    final user = _users.firstWhere(
      (u) => u.email == email,
      orElse: () => UserModel(id: '', username: '', email: ''),
    );
    if (user.id.isEmpty) {
      return false;
    }
    _currentUser = user;
    _setUserContextForServices();
    await StorageService.instance.saveString('current_user_id', user.id);
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _currentUser = null;
    DetectionService.instance.clearData();
    FarmService.instance.clearData();
    await StorageService.instance.remove('current_user_id');
    notifyListeners();
  }
}

