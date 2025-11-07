import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ai_detection/main.dart' as app;
import 'package:ai_detection/core/services/auth_service.dart';
import 'package:ai_detection/core/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Integration Test - Luồng đăng nhập (Login Flow)', () {
    setUp(() async {
      await StorageService.instance.clear();
      await StorageService.instance.init();
    });

    tearDown(() async {
      await StorageService.instance.clear();
    });

    testWidgets('Đăng nhập thành công - Chuyển đến Dashboard', (WidgetTester tester) async {
      // Arrange: Tạo tài khoản trước
      final authService = AuthService();
      await authService.register('testuser', 'test@example.com', 'password123');
      await StorageService.instance.clear();
      await StorageService.instance.init();

      // Act: Khởi động app
      app.main();
      await tester.pumpAndSettle();

      // Tìm các TextField và nhập thông tin
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;

      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.pumpAndSettle();

      // Tìm và nhấn nút đăng nhập
      final loginButton = find.text('Sign In');
      await tester.tap(loginButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert: Kiểm tra đã chuyển đến Dashboard
      // (Có thể kiểm tra bằng cách tìm các widget đặc trưng của Dashboard)
      expect(find.text('Sign In'), findsNothing);
    });

    testWidgets('Đăng nhập thất bại - Email không tồn tại', (WidgetTester tester) async {
      // Act: Khởi động app
      app.main();
      await tester.pumpAndSettle();

      // Nhập thông tin không hợp lệ
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;

      await tester.enterText(emailField, 'nonexistent@example.com');
      await tester.enterText(passwordField, 'password123');
      await tester.pumpAndSettle();

      // Nhấn nút đăng nhập
      final loginButton = find.text('Sign In');
      await tester.tap(loginButton);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert: Kiểm tra thông báo lỗi
      expect(find.text('Invalid email or password'), findsOneWidget);
    });

    testWidgets('Đăng nhập thất bại - Email rỗng', (WidgetTester tester) async {
      // Act: Khởi động app
      app.main();
      await tester.pumpAndSettle();

      // Nhập password nhưng không nhập email
      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(passwordField, 'password123');
      await tester.pumpAndSettle();

      // Nhấn nút đăng nhập
      final loginButton = find.text('Sign In');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Assert: Kiểm tra validation message
      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('Đăng nhập thất bại - Password rỗng', (WidgetTester tester) async {
      // Act: Khởi động app
      app.main();
      await tester.pumpAndSettle();

      // Nhập email nhưng không nhập password
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'test@example.com');
      await tester.pumpAndSettle();

      // Nhấn nút đăng nhập
      final loginButton = find.text('Sign In');
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      // Assert: Kiểm tra validation message
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('Chuyển đến màn hình đăng ký', (WidgetTester tester) async {
      // Act: Khởi động app
      app.main();
      await tester.pumpAndSettle();

      // Tìm và nhấn nút Sign Up
      final signUpButton = find.text('Sign Up');
      await tester.tap(signUpButton);
      await tester.pumpAndSettle();

      // Assert: Kiểm tra đã chuyển đến màn hình đăng ký
      expect(find.text('Create Account'), findsOneWidget);
    });
  });
}

