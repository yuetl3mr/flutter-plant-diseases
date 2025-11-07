import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ai_detection/main.dart' as app;
import 'package:ai_detection/core/services/auth_service.dart';
import 'package:ai_detection/core/services/storage_service.dart';
import 'package:ai_detection/core/services/detection_service.dart';
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Integration Test - Luồng phát hiện bệnh (Detection Flow)', () {
    setUp(() async {
      await StorageService.instance.clear();
      await StorageService.instance.init();
      
      // Đăng nhập trước
      final authService = AuthService();
      await authService.register('testuser', 'test@example.com', 'password123');
      await authService.login('test@example.com', 'password123');
    });

    tearDown(() async {
      await StorageService.instance.clear();
    });

    testWidgets('Phát hiện bệnh thành công - Lưu kết quả', (WidgetTester tester) async {
      // Arrange
      final detectionService = DetectionService();
      final initialCount = detectionService.detections.length;

      // Act: Phát hiện bệnh
      final detection = await detectionService.detectDisease('/path/to/test/image.jpg');
      await detectionService.saveDetection(detection);

      // Assert: Kiểm tra đã lưu kết quả
      expect(detectionService.detections.length, equals(initialCount + 1));
      expect(detectionService.detections.last.id, equals(detection.id));
      expect(detectionService.detections.last.diseaseName, isNotEmpty);
      expect(detectionService.detections.last.confidence, greaterThan(0.0));
    });

    testWidgets('Phát hiện bệnh - Kiểm tra thống kê tuần', (WidgetTester tester) async {
      // Arrange
      final detectionService = DetectionService();
      
      // Act: Tạo một số phát hiện
      for (int i = 0; i < 3; i++) {
        final detection = await detectionService.detectDisease('/path/to/test/image$i.jpg');
        await detectionService.saveDetection(detection);
      }

      // Act: Lấy thống kê tuần
      final stats = detectionService.getWeeklyStats();

      // Assert: Kiểm tra thống kê
      expect(stats.length, equals(7));
      expect(stats.last['infected'], greaterThanOrEqualTo(0));
    });

    testWidgets('Phát hiện bệnh - Lưu với farmId', (WidgetTester tester) async {
      // Arrange
      final detectionService = DetectionService();
      const farmId = 'farm123';

      // Act: Phát hiện và lưu với farmId
      final detection = await detectionService.detectDisease('/path/to/test/image.jpg');
      await detectionService.saveDetection(detection, farmId: farmId);

      // Assert: Kiểm tra farmId đã được lưu
      expect(detectionService.detections.last.farmId, equals(farmId));
    });

    testWidgets('Phát hiện bệnh - Danh sách phát hiện gần đây', (WidgetTester tester) async {
      // Arrange
      final detectionService = DetectionService();

      // Act: Tạo nhiều phát hiện
      final detection1 = await detectionService.detectDisease('/path/to/test/image1.jpg');
      await Future.delayed(const Duration(milliseconds: 10));
      final detection2 = await detectionService.detectDisease('/path/to/test/image2.jpg');
      
      await detectionService.saveDetection(detection1);
      await detectionService.saveDetection(detection2);

      // Act: Lấy danh sách phát hiện gần đây
      final recent = detectionService.recentDetections;

      // Assert: Kiểm tra sắp xếp đúng (mới nhất trước)
      expect(recent.length, greaterThanOrEqualTo(2));
      expect(recent.first.id, equals(detection2.id));
    });
  });
}

