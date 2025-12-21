import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:ai_detection/core/models/detection_model.dart';
import 'package:ai_detection/core/services/storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class DetectionService extends ChangeNotifier {
  static late final DetectionService _instance = DetectionService._internal();
  static DetectionService get instance => _instance;
  final List<DetectionModel> _detections = [];
  String? _currentUserId;

  List<DetectionModel> get detections => List.unmodifiable(_detections);
  List<DetectionModel> get recentDetections => List.unmodifiable(
        _detections.toList()..sort((a, b) => b.date.compareTo(a.date)),
      );

  // Count all detections including those from farms (farmId/plantId may be set or null)
  int get totalInfected => _detections.where((d) => !d.diseaseName.toLowerCase().contains('healthy')).length;
  int get totalHealthy => _detections.where((d) => d.diseaseName.toLowerCase().contains('healthy')).length;

  DetectionService._internal();

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    _loadDetections();
  }

  void clearData() {
    _currentUserId = null;
    _detections.clear();
    notifyListeners();
  }

  Future<void> _loadDetections() async {
    // Always clear detections first to prevent showing old data for new users
    _detections.clear();
    final detectionsJson = StorageService.instance.getString('detections', userId: _currentUserId);
    if (detectionsJson != null) {
      final List<dynamic> decoded = jsonDecode(detectionsJson);
      final loadedDetections = decoded.map((d) => DetectionModel.fromJson(d as Map<String, dynamic>)).toList();
      
      // Remove duplicates by keeping only the first occurrence of each ID
      final seenIds = <String>{};
      _detections.addAll(
        loadedDetections.where((d) {
          if (seenIds.contains(d.id)) {
            return false; // Skip duplicate
          }
          seenIds.add(d.id);
          return true;
        }),
      );
      
      // If duplicates were found, save the cleaned list
      if (loadedDetections.length != _detections.length) {
        await _saveDetections();
      }
    }
    notifyListeners();
  }

  Future<void> _saveDetections() async {
    final encoded = jsonEncode(_detections.map((d) => d.toJson()).toList());
    await StorageService.instance.saveString('detections', encoded, userId: _currentUserId);
    notifyListeners();
  }

  Future<DetectionModel> detectDisease(String imagePath, {String? plant}) async {
    try {
      // Read image file
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Không tìm thấy file ảnh');
      }

      // Create multipart request
      final uri = Uri.parse('https://detecting-plant-diseases-1.onrender.com/predict');
      var request = http.MultipartRequest('POST', uri);
      
      // Add image file
      final fileName = imagePath.split(Platform.pathSeparator).last;
      final imageBytes = await imageFile.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: fileName,
        ),
      );

      // Add optional plant parameter
      if (plant != null && plant.isNotEmpty) {
        request.fields['plant'] = plant;
      }

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Hết thời gian chờ. Vui lòng kiểm tra kết nối internet và thử lại.');
        },
      );
      final response = await http.Response.fromStream(streamedResponse);

      // Handle response
      if (response.statusCode == 200) {
        Map<String, dynamic> responseData;
        try {
          responseData = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          throw Exception('Phản hồi từ server không hợp lệ. Vui lòng thử lại.');
        }
        
        // Extract data from API response
        final plantName = responseData['plant'] as String? ?? 'Unknown';
        final disease = responseData['disease'] as String? ?? 'Unknown';
        
        // Parse confidence with better error handling
        double confidence = 0.0;
        try {
          final confidenceValue = responseData['normalized_probability'];
          if (confidenceValue != null) {
            confidence = double.parse(confidenceValue.toString());
            // Ensure confidence is between 0 and 1, or already a percentage
            if (confidence > 1.0) {
              // Already a percentage, keep as is
            } else if (confidence < 0.0) {
              confidence = 0.0;
            }
          } else {
            // If normalized_probability is missing, try other possible fields
            final probValue = responseData['probability'] ?? responseData['confidence'] ?? responseData['prob'];
            if (probValue != null) {
              confidence = double.parse(probValue.toString());
              if (confidence > 1.0) {
                confidence = confidence / 100.0;
              }
            }
          }
        } catch (e) {
          // If parsing fails, default to 0.0
          confidence = 0.0;
        }
        
        print('Disease: $disease, Confidence: $confidence');
        // Generate treatment recommendation based on disease
        final treatment = await _getTreatmentRecommendation(disease, plantName);
        
        final detection = DetectionModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          diseaseName: disease,
          confidence: confidence,
          treatment: treatment,
          date: DateTime.now(),
          imagePath: imagePath,
        );
        
        return detection;
      } else if (response.statusCode == 422) {
        // Low confidence error - display Vietnamese message from API
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          final errorDetail = errorData['detail'] as String?;
          if (errorDetail != null && errorDetail.isNotEmpty) {
            throw Exception(errorDetail);
          } else {
            // Fallback if detail is null or empty
            throw Exception('Độ tự tin quá thấp. Vui lòng thử lại với ảnh rõ hơn.');
          }
        } catch (e) {
          if (e is Exception && !e.toString().contains('jsonDecode')) {
            rethrow;
          }
          // Fallback to Vietnamese message if JSON parsing fails
          throw Exception('Độ tự tin quá thấp. Vui lòng thử lại với ảnh rõ hơn.');
        }
      } else if (response.statusCode == 400) {
        // Bad request error - display Vietnamese message from API
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          final errorDetail = errorData['detail'] as String?;
          if (errorDetail != null && errorDetail.isNotEmpty) {
            throw Exception(errorDetail);
          } else {
            // Fallback if detail is null or empty
            throw Exception('Yêu cầu không hợp lệ. Vui lòng kiểm tra lại file ảnh.');
          }
        } catch (e) {
          if (e is Exception && !e.toString().contains('jsonDecode')) {
            rethrow;
          }
          // Fallback to Vietnamese message if JSON parsing fails
          throw Exception('Yêu cầu không hợp lệ. Vui lòng kiểm tra lại file ảnh.');
        }
      } else {
        throw Exception('Yêu cầu API thất bại với mã lỗi: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Lỗi khi phát hiện bệnh: $e');
    }
  }

  Future<String> _getTreatmentRecommendation(String disease, String plant) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Gemini API key không được cấu hình');
      }

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );

      final prompt = '''Bạn là một chuyên gia nông học và bệnh lý thực vật. 
Cây: $plant
Bệnh: $disease

Hãy cung cấp khuyến cáo điều trị cho bệnh này theo định dạng sau:

ĐỊNH DẠNG (không dùng markdown, chỉ dùng ký tự thường):

1. Nguyên nhân: [Nguyên nhân chính gây bệnh - 1 dòng]

2. Các biện pháp xử lý ngay lập tức:
   - [Biện pháp 1]
   - [Biện pháp 2]
   - [Biện pháp 3]

3. Điều trị hóa chất: [Loại thuốc/chất hóa học cụ thể - 1-2 dòng]

4. Phòng ngừa:
   - [Biện pháp phòng ngừa 1]
   - [Biện pháp phòng ngừa 2]
   - [Biện pháp phòng ngừa 3]

5. Thời gian khác phục: [Ước tính thời gian]

YÊU CẦU QUAN TRỌNG:
- KHÔNG dùng markdown, không dùng **, không dùng #, không dùng [ ]
- Viết bằng tiếng Việt
- Ngắn gọn, trực tiếp và dễ hiểu
- Tập trung vào giải pháp thực tế có thể áp dụng ngay
- Không vượt quá 200 từ
- Chỉ cung cấp thông tin chính xác dựa trên kiến thức nông học''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('Gemini API request timeout. Vui lòng thử lại.'),
      );
      
      return response.text ?? 'Không thể lấy được khuyến cáo. Vui lòng thử lại.';
    } catch (e) {
      // Fallback nếu Gemini API thất bại
      return _getFallbackTreatment(disease, plant);
    }
  }

  String _getFallbackTreatment(String disease, String plant) {
    // Fallback recommendations nếu Gemini API không khả dụng
    final diseaseLower = disease.toLowerCase();
    
    if (diseaseLower.contains('healthy')) {
      return '''Tình trạng: Cây khỏe mạnh

Xử lý: Tiếp tục chăm sóc thường xuyên
- Theo dõi sức khỏe định kỳ
- Đảm bảo điều kiện sinh trưởng tối ưu
- Tưới nước đủ và thích hợp''';
    }
    
    if (diseaseLower.contains('blight')) {
      return '''Bệnh: Bệnh áo lửa

Nguyên nhân: Do nấm Phytophthora gây ra

Xử lý ngay lập tức:
- Loại bỏ lá bị nhiễm ngay lập tức
- Cải thiện thông thoáng khí
- Tránh tưới nước từ trên

Điều trị: Dùng thuốc trừ nấm chứa đồng, phun mỗi 7-10 ngày

Phòng ngừa:
- Vệ sinh dụng cụ cắt tỉa
- Tránh môi trường quá ẩm
- Cách xa từng cây

Thời gian khác phục: 2-4 tuần với điều trị thích hợp''';
    }
    
    if (diseaseLower.contains('powdery mildew')) {
      return '''Bệnh: Bệnh phấn trắng

Nguyên nhân: Do nấm Oidium gây ra

Xử lý ngay lập tức:
- Cắt tỉa các phần bị hại
- Cải thiện thông thoáng khí
- Tăng tuần hoàn không khí quanh cây

Điều trị: Sử dụng thuốc diệt nấm lưu huỳnh hoặc dầu neem, phun 2 lần/tuần

Phòng ngừa:
- Giảm độ ẩm và tăng nắng
- Cắt tỉa thường xuyên
- Không tưới lá

Thời gian khác phục: 1-3 tuần''';
    }
    
    if (diseaseLower.contains('leaf spot') || diseaseLower.contains('cercospora')) {
      return '''Bệnh: Bệnh đốm lá

Nguyên nhân: Do nấm Cercospora gây ra

Xử lý ngay lập tức:
- Loại bỏ lá bị nhiễm ngay lập tức
- Tránh tưới nước lên lá
- Dọn sạch lá rơi vừng

Điều trị: Sử dụng thuốc trừ nấm chứa chlorothalonil hoặc mancozeb

Phòng ngừa:
- Cải thiện thông thoáng khí
- Giảm độ ẩm xung quanh
- Tránh tưới nước vào lá

Thời gian khác phục: 2-4 tuần''';
    }
    
    if (diseaseLower.contains('rust')) {
      return '''Bệnh: Bệnh gỉ

Nguyên nhân: Do nấm Rust gây ra

Xử lý ngay lập tức:
- Loại bỏ lá bị hư
- Tránh làm ướt lá khi tưới
- Cải thiện thông thoáng khí

Điều trị: Dùng thuốc chứa myclobutanil hoặc propiconazole

Phòng ngừa:
- Giảm độ ẩm
- Cắt tỉa đều đặn
- Tránh tưới từ trên

Thời gian khác phục: 2-3 tuần''';
    }
    
    // Generic treatment for unknown diseases
    return '''Khuyến cáo chung cho bệnh không xác định:

Biện pháp xử lý:
1. Loại bỏ các phần bị hại
2. Cải thiện điều kiện sinh trưởng
3. Áp dụng thuốc trừ nấm phù hợp

Điều kiện tối ưu:
- Tăng thông thoáng khí
- Giảm độ ẩm
- Tránh tưới nước từ trên

Khi nào liên hệ chuyên gia:
- Nếu tình trạng không cải thiện sau 2 tuần
- Nếu bệnh lây lan nhanh
- Nếu cây bắt đầu héo''';
  }

  Future<void> saveDetection(DetectionModel detection, {String? farmId, String? plantId}) async {
    final updated = DetectionModel(
      id: detection.id,
      diseaseName: detection.diseaseName,
      confidence: detection.confidence,
      treatment: detection.treatment,
      date: detection.date,
      imagePath: detection.imagePath,
      farmId: farmId ?? detection.farmId,
      plantId: plantId ?? detection.plantId,
    );
    
    // Check if detection already exists (by ID) and update instead of adding duplicate
    final existingIndex = _detections.indexWhere((d) => d.id == detection.id);
    if (existingIndex >= 0) {
      _detections[existingIndex] = updated;
    } else {
      _detections.add(updated);
    }
    
    await _saveDetections();
  }

  Future<void> deleteDetection(String detectionId) async {
    // Remove only the first occurrence to prevent deleting duplicates
    final index = _detections.indexWhere((d) => d.id == detectionId);
    if (index >= 0) {
      _detections.removeAt(index);
      await _saveDetections();
    }
  }

  DetectionModel? getDetectionByPlantId(String plantId) {
    try {
      return _detections.firstWhere((d) => d.plantId == plantId);
    } catch (_) {
      return null;
    }
  }

  DetectionModel? getDetectionByImagePath(String imagePath) {
    try {
      return _detections.where((d) => d.imagePath == imagePath)
          .toList()
          .isNotEmpty
          ? _detections.where((d) => d.imagePath == imagePath).first
          : null;
    } catch (_) {
      return null;
    }
  }

  // Get weekly stats including all detections (from dashboard and farms)
  List<Map<String, dynamic>> getWeeklyStats() {
    final now = DateTime.now();
    final stats = <Map<String, dynamic>>[];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      // Count all detections for this day (including those from farms)
      final dayDetections = _detections.where((d) {
        return d.date.year == date.year &&
            d.date.month == date.month &&
            d.date.day == date.day;
      });
      final infected = dayDetections.where((d) => !d.diseaseName.toLowerCase().contains('healthy')).length;
      final healthy = dayDetections.where((d) => d.diseaseName.toLowerCase().contains('healthy')).length;
      stats.add({
        'date': date,
        'infected': infected,
        'healthy': healthy,
      });
    }
    return stats;
  }
}

