import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ai_detection/main.dart' as app;
import 'package:ai_detection/core/services/auth_service.dart';
import 'package:ai_detection/core/services/storage_service.dart';
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Integration Test - Luồng đăng ký (Register Flow)', () {
    setUp(() async {
      await StorageService.instance.clear();
      await StorageService.instance.init();
    });

    tearDown(() async {
      await StorageService.instance.clear();
    });

    testWidgets('Đăng ký thành công - Chuyển đến Dashboard', (WidgetTester tester) async {
      // Act: Khởi động app
      app.main();
      await tester.pumpAndSettle();

      // Chuyển đến màn hình đăng ký
      final signUpButton = find.text('Sign Up');
      await tester.tap(signUpButton);
      await tester.pumpAndSettle();

      // Tìm các TextField
      final textFields = find.byType(TextFormField);
      expect(textFields, findsAtLeastNWidgets(4));

      // Nhập thông tin đăng ký
      await tester.enterText(textFields.at(0), 'newuser');
      await tester.enterText(textFields.at(1), 'newuser@example.com');
      await tester.enterText(textFields.at(2), 'password123');
      await tester.enterText(textFields.at(3), 'password123');
      await tester.pumpAndSettle();

      // Nhấn nút đăng ký
      final registerButton = find.text('Create Account');
      await tester.tap(registerButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert: Kiểm tra đã chuyển đến Dashboard
      expect(find.text('Create Account'), findsNothing);
    });

    testWidgets('Đăng ký thất bại - Email đã tồn tại', (WidgetTester tester) async {
      // Arrange: Tạo tài khoản trước
      final authService = AuthService();
      await authService.register('existinguser', 'existing@example.com', 'password123');
      await StorageService.instance.clear();
      await StorageService.instance.init();

      // Act: Khởi động app
      app.main();
      await tester.pumpAndSettle();

      // Chuyển đến màn hình đăng ký
      final signUpButton = find.text('Sign Up');
      await tester.tap(signUpButton);
      await tester.pumpAndSettle();

      // Nhập thông tin với email đã tồn tại
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'newuser');
      await tester.enterText(textFields.at(1), 'existing@example.com');
      await tester.enterText(textFields.at(2), 'password123');
      await tester.enterText(textFields.at(3), 'password123');
      await tester.pumpAndSettle();

      // Nhấn nút đăng ký
      final registerButton = find.text('Create Account');
      await tester.tap(registerButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert: Kiểm tra thông báo lỗi
      expect(find.text('Email already registered'), findsOneWidget);
    });

    testWidgets('Đăng ký thất bại - Username rỗng', (WidgetTester tester) async {
      // Act: Khởi động app
      app.main();
      await tester.pumpAndSettle();

      // Chuyển đến màn hình đăng ký
      final signUpButton = find.text('Sign Up');
      await tester.tap(signUpButton);
      await tester.pumpAndSettle();

      // Nhập thông tin nhưng bỏ trống username
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(1), 'test@example.com');
      await tester.enterText(textFields.at(2), 'password123');
      await tester.enterText(textFields.at(3), 'password123');
      await tester.pumpAndSettle();

      // Nhấn nút đăng ký
      final registerButton = find.text('Create Account');
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      // Assert: Kiểm tra validation message
      expect(find.text('Please enter your username'), findsOneWidget);
    });

    testWidgets('Đăng ký thất bại - Password không khớp', (WidgetTester tester) async {
      // Act: Khởi động app
      app.main();
      await tester.pumpAndSettle();

      // Chuyển đến màn hình đăng ký
      final signUpButton = find.text('Sign Up');
      await tester.tap(signUpButton);
      await tester.pumpAndSettle();

      // Nhập thông tin với password không khớp
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'newuser');
      await tester.enterText(textFields.at(1), 'test@example.com');
      await tester.enterText(textFields.at(2), 'password123');
      await tester.enterText(textFields.at(3), 'password456');
      await tester.pumpAndSettle();

      // Nhấn nút đăng ký
      final registerButton = find.text('Create Account');
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      // Assert: Kiểm tra validation message
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('Đăng ký thất bại - Password quá ngắn', (WidgetTester tester) async {
      // Act: Khởi động app
      app.main();
      await tester.pumpAndSettle();

      // Chuyển đến màn hình đăng ký
      final signUpButton = find.text('Sign Up');
      await tester.tap(signUpButton);
      await tester.pumpAndSettle();

      // Nhập thông tin với password quá ngắn
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'newuser');
      await tester.enterText(textFields.at(1), 'test@example.com');
      await tester.enterText(textFields.at(2), '12345');
      await tester.enterText(textFields.at(3), '12345');
      await tester.pumpAndSettle();

      // Nhấn nút đăng ký
      final registerButton = find.text('Create Account');
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      // Assert: Kiểm tra validation message
      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });
  });
}

