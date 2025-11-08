import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:ai_detection/core/models/detection_model.dart';
import 'package:ai_detection/core/services/storage_service.dart';
import 'package:http/http.dart' as http;

class DetectionService extends ChangeNotifier {
  final List<DetectionModel> _detections = [];

  List<DetectionModel> get detections => List.unmodifiable(_detections);
  List<DetectionModel> get recentDetections => List.unmodifiable(
        _detections.toList()..sort((a, b) => b.date.compareTo(a.date)),
      );

  int get totalInfected => _detections.length;
  int get totalHealthy => 0;

  DetectionService() {
    _loadDetections();
  }

  Future<void> _loadDetections() async {
    final detectionsJson = StorageService.instance.getString('detections');
    if (detectionsJson != null) {
      final List<dynamic> decoded = jsonDecode(detectionsJson);
      _detections.clear();
      _detections.addAll(
        decoded.map((d) => DetectionModel.fromJson(d as Map<String, dynamic>)),
      );
      notifyListeners();
    }
  }

  Future<void> _saveDetections() async {
    final encoded = jsonEncode(_detections.map((d) => d.toJson()).toList());
    await StorageService.instance.saveString('detections', encoded);
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
        final confidence = (responseData['confidence'] as num?)?.toDouble() ?? 
                          (responseData['normalized_probability'] as num?)?.toDouble() ?? 0.0;
        
        // Generate treatment recommendation based on disease
        final treatment = _getTreatmentRecommendation(disease, plantName);
        
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

  String _getTreatmentRecommendation(String disease, String plant) {
    // Map common diseases to treatment recommendations
    final diseaseLower = disease.toLowerCase();
    
    if (diseaseLower.contains('healthy')) {
      return 'Plant appears healthy. Continue regular care and monitoring.';
    }
    
    if (diseaseLower.contains('blight')) {
      return 'Remove infected leaves immediately. Apply copper-based fungicide every 7-10 days. Improve air circulation and avoid overhead watering.';
    }
    
    if (diseaseLower.contains('powdery mildew')) {
      return 'Apply sulfur-based fungicide or neem oil. Prune affected areas. Ensure good air circulation and reduce humidity.';
    }
    
    if (diseaseLower.contains('rust')) {
      return 'Remove and destroy infected leaves. Apply fungicide containing myclobutanil or propiconazole. Avoid wetting foliage.';
    }
    
    if (diseaseLower.contains('bacterial spot')) {
      return 'Apply copper-based bactericide. Remove infected plant parts. Avoid overhead watering. Use crop rotation for prevention.';
    }
    
    if (diseaseLower.contains('leaf spot') || diseaseLower.contains('cercospora')) {
      return 'Remove infected leaves. Apply fungicide with chlorothalonil or mancozeb. Improve air circulation and reduce leaf wetness.';
    }
    
    if (diseaseLower.contains('mosaic virus')) {
      return 'Remove and destroy infected plants immediately. Control aphids and other vectors. Use virus-free planting material.';
    }
    
    if (diseaseLower.contains('scab')) {
      return 'Apply fungicide with captan or mancozeb. Prune to improve air circulation. Remove fallen leaves in autumn.';
    }
    
    if (diseaseLower.contains('rot') || diseaseLower.contains('black rot')) {
      return 'Remove infected parts immediately. Apply fungicide containing tebuconazole. Improve drainage and avoid overwatering.';
    }
    
    // Generic treatment for unknown diseases
    return 'Consult with a plant pathologist or agricultural expert for specific treatment recommendations. General care: remove infected parts, apply appropriate fungicide, improve growing conditions.';
  }

  Future<void> saveDetection(DetectionModel detection, {String? farmId}) async {
    final updated = DetectionModel(
      id: detection.id,
      diseaseName: detection.diseaseName,
      confidence: detection.confidence,
      treatment: detection.treatment,
      date: detection.date,
      imagePath: detection.imagePath,
      farmId: farmId,
    );
    _detections.add(updated);
    await _saveDetections();
  }

  List<Map<String, dynamic>> getWeeklyStats() {
    final now = DateTime.now();
    final stats = <Map<String, dynamic>>[];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayDetections = _detections.where((d) {
        return d.date.year == date.year &&
            d.date.month == date.month &&
            d.date.day == date.day;
      }).length;
      stats.add({
        'date': date,
        'infected': dayDetections,
        'healthy': 0,
      });
    }
    return stats;
  }
}

