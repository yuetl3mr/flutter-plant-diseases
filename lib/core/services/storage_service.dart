import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService instance = StorageService._internal();
  StorageService._internal();
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Generate user-scoped key
  String _getUserKey(String key, String? userId) {
    if (userId == null || userId.isEmpty) {
      return key;
    }
    return '${userId}_$key';
  }

  Future<void> saveString(String key, String value, {String? userId}) async {
    await _prefs?.setString(_getUserKey(key, userId), value);
  }

  String? getString(String key, {String? userId}) => _prefs?.getString(_getUserKey(key, userId));

  Future<void> saveStringList(String key, List<String> value, {String? userId}) async {
    await _prefs?.setStringList(_getUserKey(key, userId), value);
  }

  List<String>? getStringList(String key, {String? userId}) => _prefs?.getStringList(_getUserKey(key, userId));

  Future<void> remove(String key, {String? userId}) async {
    await _prefs?.remove(_getUserKey(key, userId));
  }

  Future<void> clear() async {
    await _prefs?.clear();
  }

  Future<void> saveAvatarPath(String userId, String imagePath) async {
    await _prefs?.setString('avatar_$userId', imagePath);
  }

  String? getAvatarPath(String userId) => _prefs?.getString('avatar_$userId');
}

