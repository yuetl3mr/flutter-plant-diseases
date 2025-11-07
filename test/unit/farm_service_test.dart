import 'package:flutter_test/flutter_test.dart';
import 'package:ai_detection/core/services/farm_service.dart';
import 'package:ai_detection/core/services/storage_service.dart';
import 'package:ai_detection/core/models/farm_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });
  
  group('FarmService - Thêm nông trại (addFarm)', () {
    late FarmService farmService;

    setUp(() async {
      await StorageService.instance.clear();
      await StorageService.instance.init();
      farmService = FarmService();
    });

    tearDown(() async {
      await StorageService.instance.clear();
    });

    test('Thêm nông trại thành công với thông tin hợp lệ', () async {
      // Act
      await farmService.addFarm('Farm A', 'Location A', 'Rice');
      
      // Assert
      expect(farmService.farms.length, greaterThan(0));
      final farm = farmService.farms.firstWhere((f) => f.name == 'Farm A');
      expect(farm.name, equals('Farm A'));
      expect(farm.location, equals('Location A'));
      expect(farm.cropType, equals('Rice'));
      expect(farm.plants.length, equals(0));
    });

    test('Thêm nhiều nông trại', () async {
      // Act
      await farmService.addFarm('Farm A', 'Location A', 'Rice');
      await farmService.addFarm('Farm B', 'Location B', 'Wheat');
      
      // Assert
      expect(farmService.farms.length, greaterThanOrEqualTo(2));
    });

    test('Thêm nông trại với tên trùng lặp', () async {
      // Act
      await farmService.addFarm('Farm A', 'Location A', 'Rice');
      await farmService.addFarm('Farm A', 'Location B', 'Wheat');
      
      // Assert: Cho phép tên trùng
      expect(farmService.farms.length, greaterThanOrEqualTo(2));
    });
  });

  group('FarmService - Lấy nông trại theo ID (getFarmById)', () {
    late FarmService farmService;
    String? farmId;

    setUp(() async {
      await StorageService.instance.clear();
      await StorageService.instance.init();
      farmService = FarmService();
      await farmService.addFarm('Farm A', 'Location A', 'Rice');
      farmId = farmService.farms.first.id;
    });

    tearDown(() async {
      await StorageService.instance.clear();
    });

    test('Lấy nông trại thành công với ID hợp lệ', () {
      // Act
      final farm = farmService.getFarmById(farmId!);
      
      // Assert
      expect(farm, isNotNull);
      expect(farm?.name, equals('Farm A'));
      expect(farm?.id, equals(farmId));
    });

    test('Lấy nông trại thất bại với ID không tồn tại', () {
      // Act
      final farm = farmService.getFarmById('nonexistent_id');
      
      // Assert
      expect(farm, isNull);
    });

    test('Lấy nông trại với ID rỗng', () {
      // Act
      final farm = farmService.getFarmById('');
      
      // Assert
      expect(farm, isNull);
    });
  });

  group('FarmService - Thêm cây vào nông trại (addPlantToFarm)', () {
    late FarmService farmService;
    String? farmId;

    setUp(() async {
      await StorageService.instance.clear();
      await StorageService.instance.init();
      farmService = FarmService();
      await farmService.addFarm('Farm A', 'Location A', 'Rice');
      farmId = farmService.farms.first.id;
    });

    tearDown(() async {
      await StorageService.instance.clear();
    });

    test('Thêm cây thành công vào nông trại', () async {
      // Act
      await farmService.addPlantToFarm(
        farmId!,
        'Plant 1',
        '/path/to/image.jpg',
        PlantStatus.healthy,
      );
      
      // Assert
      final farm = farmService.getFarmById(farmId!);
      expect(farm?.plants.length, equals(1));
      expect(farm?.plants.first.name, equals('Plant 1'));
      expect(farm?.plants.first.status, equals(PlantStatus.healthy));
    });

    test('Thêm nhiều cây vào nông trại', () async {
      // Act
      await farmService.addPlantToFarm(
        farmId!,
        'Plant 1',
        '/path/to/image1.jpg',
        PlantStatus.healthy,
      );
      await farmService.addPlantToFarm(
        farmId!,
        'Plant 2',
        '/path/to/image2.jpg',
        PlantStatus.infected,
      );
      
      // Assert
      final farm = farmService.getFarmById(farmId!);
      expect(farm?.plants.length, equals(2));
    });

    test('Thêm cây thất bại với farmId không tồn tại', () async {
      // Act
      await farmService.addPlantToFarm(
        'nonexistent_id',
        'Plant 1',
        '/path/to/image.jpg',
        PlantStatus.healthy,
      );
      
      // Assert: Không có lỗi, nhưng cây không được thêm
      final farm = farmService.getFarmById('nonexistent_id');
      expect(farm, isNull);
    });
  });

  group('FarmService - Xóa cây (deletePlant)', () {
    late FarmService farmService;
    String? farmId;
    String? plantId;

    setUp(() async {
      await StorageService.instance.clear();
      await StorageService.instance.init();
      farmService = FarmService();
      await farmService.addFarm('Farm A', 'Location A', 'Rice');
      farmId = farmService.farms.first.id;
      await farmService.addPlantToFarm(
        farmId!,
        'Plant 1',
        '/path/to/image.jpg',
        PlantStatus.healthy,
      );
      plantId = farmService.getFarmById(farmId!)!.plants.first.id;
    });

    tearDown(() async {
      await StorageService.instance.clear();
    });

    test('Xóa cây thành công', () async {
      // Arrange
      expect(farmService.getFarmById(farmId!)?.plants.length, equals(1));
      
      // Act
      await farmService.deletePlant(farmId!, plantId!);
      
      // Assert
      final farm = farmService.getFarmById(farmId!);
      expect(farm?.plants.length, equals(0));
    });

    test('Xóa cây thất bại với plantId không tồn tại', () async {
      // Arrange
      final initialCount = farmService.getFarmById(farmId!)!.plants.length;
      
      // Act
      await farmService.deletePlant(farmId!, 'nonexistent_plant_id');
      
      // Assert: Số lượng cây không thay đổi
      final farm = farmService.getFarmById(farmId!);
      expect(farm?.plants.length, equals(initialCount));
    });

    test('Xóa cây thất bại với farmId không tồn tại', () async {
      // Act: Không có lỗi xảy ra
      await farmService.deletePlant('nonexistent_farm_id', plantId!);
      
      // Assert: Không có lỗi
      expect(farmService.getFarmById(farmId!)?.plants.length, equals(1));
    });
  });

  group('FarmService - Xóa nông trại (deleteFarm)', () {
    late FarmService farmService;
    String? farmId;

    setUp(() async {
      await StorageService.instance.clear();
      await StorageService.instance.init();
      farmService = FarmService();
      await farmService.addFarm('Farm A', 'Location A', 'Rice');
      farmId = farmService.farms.first.id;
    });

    tearDown(() async {
      await StorageService.instance.clear();
    });

    test('Xóa nông trại thành công', () async {
      // Arrange
      final initialCount = farmService.farms.length;
      
      // Act
      await farmService.deleteFarm(farmId!);
      
      // Assert
      expect(farmService.farms.length, lessThan(initialCount));
      expect(farmService.getFarmById(farmId!), isNull);
    });

    test('Xóa nông trại với ID không tồn tại', () async {
      // Arrange
      final initialCount = farmService.farms.length;
      
      // Act
      await farmService.deleteFarm('nonexistent_id');
      
      // Assert: Số lượng không thay đổi
      expect(farmService.farms.length, equals(initialCount));
    });
  });

  group('FarmService - Cập nhật trạng thái cây (updatePlantStatus)', () {
    late FarmService farmService;
    String? farmId;
    String? plantId;

    setUp(() async {
      await StorageService.instance.clear();
      await StorageService.instance.init();
      farmService = FarmService();
      await farmService.addFarm('Farm A', 'Location A', 'Rice');
      farmId = farmService.farms.first.id;
      await farmService.addPlantToFarm(
        farmId!,
        'Plant 1',
        '/path/to/image.jpg',
        PlantStatus.healthy,
      );
      plantId = farmService.getFarmById(farmId!)!.plants.first.id;
    });

    tearDown(() async {
      await StorageService.instance.clear();
    });

    test('Cập nhật trạng thái cây thành công từ healthy sang infected', () async {
      // Act
      await farmService.updatePlantStatus(farmId!, plantId!, PlantStatus.infected);
      
      // Assert
      final farm = farmService.getFarmById(farmId!);
      final plant = farm?.plants.firstWhere((p) => p.id == plantId);
      expect(plant?.status, equals(PlantStatus.infected));
    });

    test('Cập nhật trạng thái cây thành công từ infected sang healthy', () async {
      // Arrange: Đặt trạng thái infected trước
      await farmService.updatePlantStatus(farmId!, plantId!, PlantStatus.infected);
      
      // Act: Cập nhật về healthy
      await farmService.updatePlantStatus(farmId!, plantId!, PlantStatus.healthy);
      
      // Assert
      final farm = farmService.getFarmById(farmId!);
      final plant = farm?.plants.firstWhere((p) => p.id == plantId);
      expect(plant?.status, equals(PlantStatus.healthy));
    });

    test('Cập nhật trạng thái cây thất bại với plantId không tồn tại', () async {
      // Arrange
      final initialStatus = farmService.getFarmById(farmId!)!
          .plants.firstWhere((p) => p.id == plantId).status;
      
      // Act
      await farmService.updatePlantStatus(farmId!, 'nonexistent_plant_id', PlantStatus.infected);
      
      // Assert: Trạng thái không thay đổi
      final farm = farmService.getFarmById(farmId!);
      final plant = farm?.plants.firstWhere((p) => p.id == plantId);
      expect(plant?.status, equals(initialStatus));
    });

    test('Cập nhật trạng thái cây thất bại với farmId không tồn tại', () async {
      // Act: Không có lỗi xảy ra
      await farmService.updatePlantStatus('nonexistent_farm_id', plantId!, PlantStatus.infected);
      
      // Assert: Trạng thái không thay đổi
      final farm = farmService.getFarmById(farmId!);
      final plant = farm?.plants.firstWhere((p) => p.id == plantId);
      expect(plant?.status, equals(PlantStatus.healthy));
    });
  });

  group('FarmService - Thống kê nông trại', () {
    late FarmService farmService;
    String? farmId;

    setUp(() async {
      await StorageService.instance.clear();
      await StorageService.instance.init();
      farmService = FarmService();
      await farmService.addFarm('Farm A', 'Location A', 'Rice');
      farmId = farmService.farms.first.id;
    });

    tearDown(() async {
      await StorageService.instance.clear();
    });

    test('Tính toán số lượng cây nhiễm bệnh', () async {
      // Arrange: Thêm cây nhiễm bệnh
      await farmService.addPlantToFarm(
        farmId!,
        'Plant 1',
        '/path/to/image1.jpg',
        PlantStatus.infected,
      );
      await farmService.addPlantToFarm(
        farmId!,
        'Plant 2',
        '/path/to/image2.jpg',
        PlantStatus.healthy,
      );
      
      // Assert
      final farm = farmService.getFarmById(farmId!);
      expect(farm?.infectedPlants, equals(1));
      expect(farm?.healthyPlants, equals(1));
      expect(farm?.totalPlants, equals(2));
    });
  });
}

