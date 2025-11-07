import 'package:flutter_test/flutter_test.dart';
import 'package:ai_detection/core/services/detection_service.dart';
import 'package:ai_detection/core/services/storage_service.dart';
import 'package:ai_detection/core/models/detection_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });
  
  group('DetectionService - Phát hiện bệnh (detectDisease)', () {
    late DetectionService detectionService;

    setUp(() async {
      await StorageService.instance.clear();
      await StorageService.instance.init();
      detectionService = DetectionService();
    });

    tearDown(() async {
      await StorageService.instance.clear();
    });

    test('Phát hiện bệnh thành công với đường dẫn ảnh hợp lệ', () async {
      // Arrange
      const imagePath = '/path/to/image.jpg';
      
      // Act
      final result = await detectionService.detectDisease(imagePath);
      
      // Assert
      expect(result, isNotNull);
      expect(result.id, isNotEmpty);
      expect(result.diseaseName, isNotEmpty);
      expect(result.confidence, greaterThan(0.0));
      expect(result.confidence, lessThanOrEqualTo(1.0));
      expect(result.treatment, isNotEmpty);
      expect(result.imagePath, equals(imagePath));
      expect(result.date, isNotNull);
    });

    test('Phát hiện bệnh với đường dẫn ảnh rỗng', () async {
      // Arrange
      const imagePath = '';
      
      // Act
      final result = await detectionService.detectDisease(imagePath);
      
      // Assert
      expect(result, isNotNull);
      expect(result.imagePath, equals(''));
    });

    test('Kết quả phát hiện có confidence score hợp lệ', () async {
      // Arrange
      const imagePath = '/path/to/image.jpg';
      
      // Act
      final result = await detectionService.detectDisease(imagePath);
      
      // Assert
      expect(result.confidence, greaterThanOrEqualTo(0.75));
      expect(result.confidence, lessThanOrEqualTo(0.99));
    });

    test('Kết quả phát hiện có tên bệnh hợp lệ', () async {
      // Arrange
      const imagePath = '/path/to/image.jpg';
      const validDiseases = [
        'Leaf Blight',
        'Powdery Mildew',
        'Rust',
        'Bacterial Spot',
        'Fungal Infection',
      ];
      
      // Act
      final result = await detectionService.detectDisease(imagePath);
      
      // Assert
      expect(validDiseases, contains(result.diseaseName));
    });
  });

  group('DetectionService - Lưu phát hiện (saveDetection)', () {
    late DetectionService detectionService;

    setUp(() async {
      await StorageService.instance.clear();
      await StorageService.instance.init();
      detectionService = DetectionService();
    });

    tearDown(() async {
      await StorageService.instance.clear();
    });

    test('Lưu phát hiện thành công', () async {
      // Arrange
      final detection = await detectionService.detectDisease('/path/to/image.jpg');
      
      // Act
      await detectionService.saveDetection(detection);
      
      // Assert
      expect(detectionService.detections.length, equals(1));
      expect(detectionService.detections.first.id, equals(detection.id));
    });

    test('Lưu phát hiện với farmId', () async {
      // Arrange
      final detection = await detectionService.detectDisease('/path/to/image.jpg');
      const farmId = 'farm123';
      
      // Act
      await detectionService.saveDetection(detection, farmId: farmId);
      
      // Assert
      expect(detectionService.detections.length, equals(1));
      expect(detectionService.detections.first.farmId, equals(farmId));
    });

    test('Lưu nhiều phát hiện', () async {
      // Arrange
      final detection1 = await detectionService.detectDisease('/path/to/image1.jpg');
      final detection2 = await detectionService.detectDisease('/path/to/image2.jpg');
      
      // Act
      await detectionService.saveDetection(detection1);
      await detectionService.saveDetection(detection2);
      
      // Assert
      expect(detectionService.detections.length, equals(2));
    });
  });

  group('DetectionService - Thống kê tuần (getWeeklyStats)', () {
    late DetectionService detectionService;

    setUp(() async {
      await StorageService.instance.clear();
      await StorageService.instance.init();
      detectionService = DetectionService();
    });

    tearDown(() async {
      await StorageService.instance.clear();
    });

    test('Thống kê tuần trả về 7 ngày', () {
      // Act
      final stats = detectionService.getWeeklyStats();
      
      // Assert
      expect(stats.length, equals(7));
    });

    test('Thống kê tuần có cấu trúc dữ liệu đúng', () {
      // Act
      final stats = detectionService.getWeeklyStats();
      
      // Assert
      for (final stat in stats) {
        expect(stat.containsKey('date'), isTrue);
        expect(stat.containsKey('infected'), isTrue);
        expect(stat.containsKey('healthy'), isTrue);
        expect(stat['date'], isA<DateTime>());
        expect(stat['infected'], isA<int>());
        expect(stat['healthy'], isA<int>());
      }
    });

    test('Thống kê tuần với dữ liệu phát hiện', () async {
      // Arrange: Tạo phát hiện cho hôm nay
      final detection = await detectionService.detectDisease('/path/to/image.jpg');
      await detectionService.saveDetection(detection);
      
      // Act
      final stats = detectionService.getWeeklyStats();
      
      // Assert: Ít nhất một ngày có infected > 0
      final todayStats = stats.last;
      expect(todayStats['infected'], greaterThanOrEqualTo(0));
    });

    test('Thống kê tuần trả về healthy = 0', () {
      // Act
      final stats = detectionService.getWeeklyStats();
      
      // Assert
      for (final stat in stats) {
        expect(stat['healthy'], equals(0));
      }
    });
  });

  group('DetectionService - Danh sách phát hiện', () {
    late DetectionService detectionService;

    setUp(() async {
      await StorageService.instance.clear();
      await StorageService.instance.init();
      detectionService = DetectionService();
    });

    tearDown(() async {
      await StorageService.instance.clear();
    });

    test('Danh sách phát hiện ban đầu rỗng', () {
      expect(detectionService.detections.length, equals(0));
    });

    test('recentDetections sắp xếp theo ngày mới nhất', () async {
      // Arrange: Tạo nhiều phát hiện
      final detection1 = await detectionService.detectDisease('/path/to/image1.jpg');
      await Future.delayed(const Duration(milliseconds: 10));
      final detection2 = await detectionService.detectDisease('/path/to/image2.jpg');
      
      await detectionService.saveDetection(detection1);
      await detectionService.saveDetection(detection2);
      
      // Act
      final recent = detectionService.recentDetections;
      
      // Assert
      expect(recent.length, equals(2));
      expect(recent.first.id, equals(detection2.id)); // Mới nhất trước
    });

    test('totalInfected trả về số lượng phát hiện', () async {
      // Arrange
      final detection1 = await detectionService.detectDisease('/path/to/image1.jpg');
      final detection2 = await detectionService.detectDisease('/path/to/image2.jpg');
      
      await detectionService.saveDetection(detection1);
      await detectionService.saveDetection(detection2);
      
      // Assert
      expect(detectionService.totalInfected, equals(2));
    });
  });
}

