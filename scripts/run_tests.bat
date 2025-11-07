@echo off
REM Script để chạy tất cả tests và tạo báo cáo HTML trên Windows

echo 🚀 Bắt đầu chạy tests...

REM Chạy unit tests
echo 📋 Đang chạy Unit Tests...
flutter test test/unit/ --reporter expanded

REM Chạy integration tests
echo.
echo 📋 Đang chạy Integration Tests...
flutter test integration_test/ --reporter expanded

REM Tạo báo cáo HTML từ kết quả tests thực tế
echo.
echo 📊 Đang tạo báo cáo HTML từ kết quả tests...
dart test/run_tests_and_generate_report.dart

echo.
echo ✅ Hoàn thành! Báo cáo đã được lưu tại: test_report.html
pause

