import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ai_detection/main.dart' as app;
import 'package:ai_detection/core/services/auth_service.dart';
import 'package:ai_detection/core/services/storage_service.dart';
import 'package:ai_detection/core/services/farm_service.dart';
import 'package:ai_detection/core/models/farm_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Integration Test - Luồng quản lý nông trại (Farm Management Flow)', () {
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

    testWidgets('Thêm nông trại thành công', (WidgetTester tester) async {
      // Arrange
      final farmService = FarmService.instance;
      final initialCount = farmService.farms.length;

      // Act: Thêm nông trại
      await farmService.addFarm('Test Farm', 'Test Location', 'Rice');

      // Assert: Kiểm tra đã thêm nông trại
      expect(farmService.farms.length, equals(initialCount + 1));
      final farm = farmService.farms.firstWhere((f) => f.name == 'Test Farm');
      expect(farm.name, equals('Test Farm'));
      expect(farm.location, equals('Test Location'));
      expect(farm.cropType, equals('Rice'));
    });

    testWidgets('Lấy nông trại theo ID thành công', (WidgetTester tester) async {
      // Arrange
      final farmService = FarmService.instance;
      await farmService.addFarm('Test Farm', 'Test Location', 'Rice');
      final farmId = farmService.farms.firstWhere((f) => f.name == 'Test Farm').id;

      // Act: Lấy nông trại theo ID
      final farm = farmService.getFarmById(farmId);

      // Assert: Kiểm tra thông tin nông trại
      expect(farm, isNotNull);
      expect(farm?.name, equals('Test Farm'));
      expect(farm?.id, equals(farmId));
    });

    testWidgets('Thêm cây vào nông trại thành công', (WidgetTester tester) async {
      // Arrange
      final farmService = FarmService.instance;
      await farmService.addFarm('Test Farm', 'Test Location', 'Rice');
      final farmId = farmService.farms.firstWhere((f) => f.name == 'Test Farm').id;

      // Act: Thêm cây vào nông trại
      await farmService.addPlantToFarm(
        farmId,
        'Plant 1',
        '/path/to/image.jpg',
        PlantStatus.healthy,
      );

      // Assert: Kiểm tra đã thêm cây
      final farm = farmService.getFarmById(farmId);
      expect(farm?.plants.length, equals(1));
      expect(farm?.plants.first.name, equals('Plant 1'));
      expect(farm?.plants.first.status, equals(PlantStatus.healthy));
    });

    testWidgets('Xóa cây khỏi nông trại thành công', (WidgetTester tester) async {
      // Arrange
      final farmService = FarmService.instance;
      await farmService.addFarm('Test Farm', 'Test Location', 'Rice');
      final farmId = farmService.farms.firstWhere((f) => f.name == 'Test Farm').id;
      await farmService.addPlantToFarm(
        farmId,
        'Plant 1',
        '/path/to/image.jpg',
        PlantStatus.healthy,
      );
      final plantId = farmService.getFarmById(farmId)!.plants.first.id;

      // Act: Xóa cây
      await farmService.deletePlant(farmId, plantId);

      // Assert: Kiểm tra đã xóa cây
      final farm = farmService.getFarmById(farmId);
      expect(farm?.plants.length, equals(0));
    });

    testWidgets('Cập nhật trạng thái cây thành công', (WidgetTester tester) async {
      // Arrange
      final farmService = FarmService.instance;
      await farmService.addFarm('Test Farm', 'Test Location', 'Rice');
      final farmId = farmService.farms.firstWhere((f) => f.name == 'Test Farm').id;
      await farmService.addPlantToFarm(
        farmId,
        'Plant 1',
        '/path/to/image.jpg',
        PlantStatus.healthy,
      );
      final plantId = farmService.getFarmById(farmId)!.plants.first.id;

      // Act: Cập nhật trạng thái
      await farmService.updatePlantStatus(farmId, plantId, PlantStatus.infected);

      // Assert: Kiểm tra trạng thái đã được cập nhật
      final farm = farmService.getFarmById(farmId);
      final plant = farm?.plants.firstWhere((p) => p.id == plantId);
      expect(plant?.status, equals(PlantStatus.infected));
    });

    testWidgets('Xóa nông trại thành công', (WidgetTester tester) async {
      // Arrange
      final farmService = FarmService.instance;
      await farmService.addFarm('Test Farm', 'Test Location', 'Rice');
      final farmId = farmService.farms.firstWhere((f) => f.name == 'Test Farm').id;
      final initialCount = farmService.farms.length;

      // Act: Xóa nông trại
      await farmService.deleteFarm(farmId);

      // Assert: Kiểm tra đã xóa nông trại
      expect(farmService.farms.length, lessThan(initialCount));
      expect(farmService.getFarmById(farmId), isNull);
    });

    testWidgets('Tính toán thống kê nông trại', (WidgetTester tester) async {
      // Arrange
      final farmService = FarmService.instance;
      await farmService.addFarm('Test Farm', 'Test Location', 'Rice');
      final farmId = farmService.farms.firstWhere((f) => f.name == 'Test Farm').id;
      
      // Thêm cây với các trạng thái khác nhau
      await farmService.addPlantToFarm(
        farmId,
        'Plant 1',
        '/path/to/image1.jpg',
        PlantStatus.healthy,
      );
      await farmService.addPlantToFarm(
        farmId,
        'Plant 2',
        '/path/to/image2.jpg',
        PlantStatus.infected,
      );
      await farmService.addPlantToFarm(
        farmId,
        'Plant 3',
        '/path/to/image3.jpg',
        PlantStatus.healthy,
      );

      // Act: Lấy thống kê
      final farm = farmService.getFarmById(farmId);

      // Assert: Kiểm tra thống kê
      expect(farm?.totalPlants, equals(3));
      expect(farm?.healthyPlants, equals(2));
      expect(farm?.infectedPlants, equals(1));
    });
  });
}

