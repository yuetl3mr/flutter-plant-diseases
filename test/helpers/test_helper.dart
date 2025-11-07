import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper để setup SharedPreferences mock cho tests
Future<void> setupSharedPreferencesMock() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Tạo mock SharedPreferences với dữ liệu rỗng
  SharedPreferences.setMockInitialValues({});
  
  // Đảm bảo instance được khởi tạo
  await SharedPreferences.getInstance();
}

/// Helper để clear SharedPreferences sau mỗi test
Future<void> clearSharedPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
}

