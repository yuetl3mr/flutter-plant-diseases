# Hướng Dẫn Chạy Tests

## Tổng Quan

Dự án này bao gồm **Unit Tests** và **Integration Tests** cho ứng dụng Flutter AI Detection.

## Cấu Trúc Tests

### Unit Tests (`test/unit/`)
- `auth_service_test.dart` - Tests cho AuthService (đăng nhập, đăng ký, đăng xuất)
- `detection_service_test.dart` - Tests cho DetectionService (phát hiện bệnh, lưu kết quả, thống kê)
- `farm_service_test.dart` - Tests cho FarmService (quản lý nông trại, cây trồng)
- `storage_service_test.dart` - Tests cho StorageService (lưu trữ dữ liệu)

### Integration Tests (`integration_test/`)
- `login_flow_test.dart` - Tests luồng đăng nhập
- `register_flow_test.dart` - Tests luồng đăng ký
- `detection_flow_test.dart` - Tests luồng phát hiện bệnh
- `farm_management_flow_test.dart` - Tests luồng quản lý nông trại

## Cách Chạy Tests

### 1. Chạy Tất Cả Tests và Tạo Báo Cáo HTML

**Windows:**
```bash
scripts\run_tests.bat
```

**Linux/Mac:**
```bash
chmod +x scripts/run_tests.sh
./scripts/run_tests.sh
```

### 2. Chạy Unit Tests Riêng

```bash
flutter test test/unit/
```

### 3. Chạy Integration Tests Riêng

```bash
flutter test integration_test/
```

### 4. Chạy Test Cụ Thể

```bash
flutter test test/unit/auth_service_test.dart
```


## Xem Báo Cáo HTML

Sau khi chạy tests, mở file `test_report.html` trong trình duyệt để xem báo cáo chi tiết.

## Danh Sách Test Cases

### AuthService Tests
1. **Đăng nhập (Login)**
   - ✅ Đăng nhập thành công với email và password hợp lệ
   - ❌ Đăng nhập thất bại - Email không tồn tại
   - ❌ Đăng nhập thất bại - Email rỗng
   - ❌ Đăng nhập thất bại - Password rỗng

2. **Đăng ký (Register)**
   - ✅ Đăng ký thành công với thông tin hợp lệ
   - ❌ Đăng ký thất bại - Email đã tồn tại
   - ✅ Đăng ký thành công - Username khác nhau nhưng email khác
   - ✅ Đăng ký với thông tin rỗng

3. **Đăng xuất (Logout)**
   - ✅ Đăng xuất thành công sau khi đăng nhập
   - ✅ Đăng xuất khi chưa đăng nhập

### DetectionService Tests
1. **Phát hiện bệnh (detectDisease)**
   - ✅ Phát hiện bệnh thành công với đường dẫn ảnh hợp lệ
   - ✅ Phát hiện bệnh với đường dẫn ảnh rỗng
   - ✅ Kết quả phát hiện có confidence score hợp lệ
   - ✅ Kết quả phát hiện có tên bệnh hợp lệ

2. **Lưu phát hiện (saveDetection)**
   - ✅ Lưu phát hiện thành công
   - ✅ Lưu phát hiện với farmId
   - ✅ Lưu nhiều phát hiện

3. **Thống kê tuần (getWeeklyStats)**
   - ✅ Thống kê tuần trả về 7 ngày
   - ✅ Thống kê tuần có cấu trúc dữ liệu đúng
   - ✅ Thống kê tuần với dữ liệu phát hiện
   - ✅ Thống kê tuần trả về healthy = 0

### FarmService Tests
1. **Thêm nông trại (addFarm)**
   - ✅ Thêm nông trại thành công với thông tin hợp lệ
   - ✅ Thêm nhiều nông trại
   - ✅ Thêm nông trại với tên trùng lặp

2. **Lấy nông trại theo ID (getFarmById)**
   - ✅ Lấy nông trại thành công với ID hợp lệ
   - ❌ Lấy nông trại thất bại với ID không tồn tại
   - ❌ Lấy nông trại với ID rỗng

3. **Thêm cây vào nông trại (addPlantToFarm)**
   - ✅ Thêm cây thành công vào nông trại
   - ✅ Thêm nhiều cây vào nông trại
   - ❌ Thêm cây thất bại với farmId không tồn tại

4. **Xóa cây (deletePlant)**
   - ✅ Xóa cây thành công
   - ❌ Xóa cây thất bại với plantId không tồn tại
   - ❌ Xóa cây thất bại với farmId không tồn tại

5. **Xóa nông trại (deleteFarm)**
   - ✅ Xóa nông trại thành công
   - ❌ Xóa nông trại với ID không tồn tại

6. **Cập nhật trạng thái cây (updatePlantStatus)**
   - ✅ Cập nhật trạng thái cây thành công từ healthy sang infected
   - ✅ Cập nhật trạng thái cây thành công từ infected sang healthy
   - ❌ Cập nhật trạng thái cây thất bại với plantId không tồn tại
   - ❌ Cập nhật trạng thái cây thất bại với farmId không tồn tại

### StorageService Tests
1. **Lưu và lấy chuỗi (saveString/getString)**
   - ✅ Lưu và lấy chuỗi thành công
   - ✅ Lưu và lấy chuỗi rỗng
   - ✅ Lưu và lấy chuỗi dài
   - ❌ Lấy chuỗi không tồn tại trả về null
   - ✅ Ghi đè giá trị đã tồn tại

2. **Lưu và lấy danh sách chuỗi (saveStringList/getStringList)**
   - ✅ Lưu và lấy danh sách chuỗi thành công
   - ✅ Lưu và lấy danh sách rỗng
   - ❌ Lấy danh sách không tồn tại trả về null

3. **Xóa (remove)**
   - ✅ Xóa key thành công
   - ✅ Xóa key không tồn tại không gây lỗi

4. **Xóa tất cả (clear)**
   - ✅ Xóa tất cả dữ liệu thành công

5. **Avatar path**
   - ✅ Lưu và lấy đường dẫn avatar thành công
   - ❌ Lấy đường dẫn avatar không tồn tại trả về null
   - ✅ Ghi đè đường dẫn avatar

## Lưu Ý

- Đảm bảo đã cài đặt tất cả dependencies: `flutter pub get`
- Tests sử dụng SharedPreferences, cần khởi tạo StorageService trước khi chạy
- Integration tests có thể mất thời gian lâu hơn unit tests
- Báo cáo HTML được tạo tự động sau khi chạy tests

## Troubleshooting

### Lỗi: "StorageService not initialized"
- Đảm bảo `StorageService.instance.init()` được gọi trong `setUp()`

### Lỗi: "Test timeout"
- Tăng thời gian timeout trong test: `test('...', () async { ... }, timeout: Timeout(Duration(seconds: 30)));`

### Lỗi: "Widget not found"
- Đảm bảo đã gọi `await tester.pumpAndSettle()` sau các thao tác UI

