import 'package:flutter_test/flutter_test.dart';
import 'package:ai_detection/core/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });
  
  group('StorageService - Lưu và lấy chuỗi (saveString/getString)', () {
    setUp(() async {
      await StorageService.instance.clear();
      await StorageService.instance.init();
    });

    tearDown(() async {
      await StorageService.instance.clear();
    });

    test('Lưu và lấy chuỗi thành công', () async {
      // Arrange
      const key = 'test_key';
      const value = 'test_value';
      
      // Act
      await StorageService.instance.saveString(key, value);
      final result = StorageService.instance.getString(key);
      
      // Assert
      expect(result, equals(value));
    });

    test('Lưu và lấy chuỗi rỗng', () async {
      // Arrange
      const key = 'test_key';
      const value = '';
      
      // Act
      await StorageService.instance.saveString(key, value);
      final result = StorageService.instance.getString(key);
      
      // Assert
      expect(result, equals(value));
    });

    test('Lưu và lấy chuỗi dài', () async {
      // Arrange
      const key = 'test_key';
      final value = 'a' * 1000;
      
      // Act
      await StorageService.instance.saveString(key, value);
      final result = StorageService.instance.getString(key);
      
      // Assert
      expect(result, equals(value));
    });

    test('Lấy chuỗi không tồn tại trả về null', () {
      // Act
      final result = StorageService.instance.getString('nonexistent_key');
      
      // Assert
      expect(result, isNull);
    });

    test('Ghi đè giá trị đã tồn tại', () async {
      // Arrange
      const key = 'test_key';
      const value1 = 'value1';
      const value2 = 'value2';
      
      // Act
      await StorageService.instance.saveString(key, value1);
      await StorageService.instance.saveString(key, value2);
      final result = StorageService.instance.getString(key);
      
      // Assert
      expect(result, equals(value2));
    });
  });

  group('StorageService - Lưu và lấy danh sách chuỗi (saveStringList/getStringList)', () {
    setUp(() async {
      await StorageService.instance.clear();
      await StorageService.instance.init();
    });

    tearDown(() async {
      await StorageService.instance.clear();
    });

    test('Lưu và lấy danh sách chuỗi thành công', () async {
      // Arrange
      const key = 'test_list_key';
      final value = ['item1', 'item2', 'item3'];
      
      // Act
      await StorageService.instance.saveStringList(key, value);
      final result = StorageService.instance.getStringList(key);
      
      // Assert
      expect(result, equals(value));
    });

    test('Lưu và lấy danh sách rỗng', () async {
      // Arrange
      const key = 'test_list_key';
      final value = <String>[];
      
      // Act
      await StorageService.instance.saveStringList(key, value);
      final result = StorageService.instance.getStringList(key);
      
      // Assert
      expect(result, equals(value));
    });

    test('Lấy danh sách không tồn tại trả về null', () {
      // Act
      final result = StorageService.instance.getStringList('nonexistent_key');
      
      // Assert
      expect(result, isNull);
    });
  });

  group('StorageService - Xóa (remove)', () {
    setUp(() async {
      await StorageService.instance.clear();
      await StorageService.instance.init();
    });

    tearDown(() async {
      await StorageService.instance.clear();
    });

    test('Xóa key thành công', () async {
      // Arrange
      const key = 'test_key';
      const value = 'test_value';
      await StorageService.instance.saveString(key, value);
      expect(StorageService.instance.getString(key), equals(value));
      
      // Act
      await StorageService.instance.remove(key);
      
      // Assert
      expect(StorageService.instance.getString(key), isNull);
    });

    test('Xóa key không tồn tại không gây lỗi', () async {
      // Act: Không có lỗi xảy ra
      await StorageService.instance.remove('nonexistent_key');
      
      // Assert: Không có lỗi
      expect(StorageService.instance.getString('nonexistent_key'), isNull);
    });
  });

  group('StorageService - Xóa tất cả (clear)', () {
    setUp(() async {
      await StorageService.instance.clear();
      await StorageService.instance.init();
    });

    tearDown(() async {
      await StorageService.instance.clear();
    });

    test('Xóa tất cả dữ liệu thành công', () async {
      // Arrange: Lưu nhiều key
      await StorageService.instance.saveString('key1', 'value1');
      await StorageService.instance.saveString('key2', 'value2');
      await StorageService.instance.saveStringList('key3', ['item1', 'item2']);
      
      // Act
      await StorageService.instance.clear();
      
      // Assert
      expect(StorageService.instance.getString('key1'), isNull);
      expect(StorageService.instance.getString('key2'), isNull);
      expect(StorageService.instance.getStringList('key3'), isNull);
    });
  });

  group('StorageService - Avatar path', () {
    setUp(() async {
      await StorageService.instance.clear();
      await StorageService.instance.init();
    });

    tearDown(() async {
      await StorageService.instance.clear();
    });

    test('Lưu và lấy đường dẫn avatar thành công', () async {
      // Arrange
      const userId = 'user123';
      const avatarPath = '/path/to/avatar.jpg';
      
      // Act
      await StorageService.instance.saveAvatarPath(userId, avatarPath);
      final result = StorageService.instance.getAvatarPath(userId);
      
      // Assert
      expect(result, equals(avatarPath));
    });

    test('Lấy đường dẫn avatar không tồn tại trả về null', () {
      // Act
      final result = StorageService.instance.getAvatarPath('nonexistent_user');
      
      // Assert
      expect(result, isNull);
    });

    test('Ghi đè đường dẫn avatar', () async {
      // Arrange
      const userId = 'user123';
      const avatarPath1 = '/path/to/avatar1.jpg';
      const avatarPath2 = '/path/to/avatar2.jpg';
      
      // Act
      await StorageService.instance.saveAvatarPath(userId, avatarPath1);
      await StorageService.instance.saveAvatarPath(userId, avatarPath2);
      final result = StorageService.instance.getAvatarPath(userId);
      
      // Assert
      expect(result, equals(avatarPath2));
    });
  });
}

