#!/bin/bash

# Script để chạy tất cả tests và tạo báo cáo HTML

echo "🚀 Bắt đầu chạy tests..."

# Chạy unit tests
echo "📋 Đang chạy Unit Tests..."
flutter test test/unit/ --reporter expanded

# Chạy integration tests (nếu có)
echo ""
echo "📋 Đang chạy Integration Tests..."
flutter test integration_test/ --reporter expanded

# Tạo báo cáo HTML từ kết quả tests thực tế
echo ""
echo "📊 Đang tạo báo cáo HTML từ kết quả tests..."
dart test/run_tests_and_generate_report.dart

echo ""
echo "✅ Hoàn thành! Báo cáo đã được lưu tại: test_report.html"

