import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_detection/core/models/farm_model.dart';
import 'package:ai_detection/core/services/farm_service.dart';
import 'package:ai_detection/core/services/detection_service.dart';
import 'package:ai_detection/core/theme/app_theme.dart';
import 'package:ai_detection/core/widgets/modern_card.dart';
import 'package:ai_detection/core/widgets/modern_button.dart';
import 'package:ai_detection/core/widgets/plant_selection_dialog.dart';
import 'package:image_picker/image_picker.dart';

class PlantDetailScreen extends StatelessWidget {
  final String farmId;
  final String plantId;

  const PlantDetailScreen({
    super.key,
    required this.farmId,
    required this.plantId,
  });

  String _formatConfidence(double confidence) {
    // Convert to percentage if needed
    double percentage = confidence > 1 ? confidence : confidence * 100;
    // Floor to 2 decimal places (don't round up)
    double floored = ((percentage * 100).truncate() / 100.0);
    return floored.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final farmService = context.watch<FarmService>();
    final detectionService = context.watch<DetectionService>();
    final farm = farmService.getFarmById(farmId);
    
    if (farm == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            'Plant Details',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        body: Center(
          child: Text(
            'Farm not found',
            style: GoogleFonts.inter(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final plant = farm.plants.firstWhere(
      (p) => p.id == plantId,
      orElse: () => throw Exception('Plant not found'),
    );

    // Find detection by imagePath or plantId
    final detection = detectionService.getDetectionByPlantId(plantId) ??
        detectionService.getDetectionByImagePath(plant.imagePath);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          plant.name,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Plant Image
            Hero(
              tag: 'plant_${plant.id}',
              child: ModernCard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: plant.imagePath.isNotEmpty
                      ? Image.file(
                          File(plant.imagePath),
                          fit: BoxFit.cover,
                          height: 300,
                          width: double.infinity,
                        )
                      : Container(
                          height: 300,
                          color: AppTheme.accentBlue,
                          child: Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 80,
                              color: AppTheme.textSecondary.withOpacity(0.5),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Plant Information
            ModernCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plant Information',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(
                    context,
                    'Name',
                    plant.name,
                    Icons.eco_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    context,
                    'Status',
                    plant.status == PlantStatus.healthy ? 'Healthy' : 'Infected',
                    plant.status == PlantStatus.healthy
                        ? Icons.check_circle_outlined
                        : Icons.warning_outlined,
                    color: plant.status == PlantStatus.healthy
                        ? AppTheme.successGreen
                        : AppTheme.errorRed,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    context,
                    'Added Date',
                    _formatDate(plant.createdAt),
                    Icons.calendar_today_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Detection Information (if available)
            if (detection != null) ...[
              ModernCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.bug_report_outlined,
                            color: AppTheme.errorRed,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Disease Detection',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildInfoRow(
                      context,
                      'Disease',
                      detection.diseaseName,
                      Icons.health_and_safety_outlined,
                      color: AppTheme.errorRed,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      context,
                      'Confidence',
                      '${_formatConfidence(detection.confidence)}%',
                      Icons.analytics_outlined,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      context,
                      'Detection Date',
                      _formatDate(detection.date),
                      Icons.access_time_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Treatment Recommendation
              ModernCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.medical_services_outlined,
                            color: AppTheme.primaryGreen,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Treatment Recommendation',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.accentBlue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        detection.treatment,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ] else if (plant.status == PlantStatus.infected) ...[
              ModernCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 48,
                      color: AppTheme.textSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No detection data available',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use re-detect to get disease information',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Action Buttons
            if (plant.status == PlantStatus.infected)
              ModernButton(
                label: 'Re-detect Disease',
                icon: Icons.search_rounded,
                onPressed: () => _redetectPlant(context, plant),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(
                'Back',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: color ?? AppTheme.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color ?? AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _redetectPlant(BuildContext context, PlantModel plant) async {
    if (!context.mounted) return;
    
    final detectionService = context.read<DetectionService>();
    final farmService = context.read<FarmService>();
    final imagePicker = ImagePicker();
    
    final image = await showDialog<XFile>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Select Image for Re-detection',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text('Take Photo', style: GoogleFonts.inter()),
              onTap: () async {
                final photo = await imagePicker.pickImage(source: ImageSource.camera);
                if (photo != null && context.mounted) {
                  Navigator.pop(context, photo);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('Choose from Gallery', style: GoogleFonts.inter()),
              onTap: () async {
                final photo = await imagePicker.pickImage(source: ImageSource.gallery);
                if (photo != null && context.mounted) {
                  Navigator.pop(context, photo);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );

    if (image == null || !context.mounted) return;

    try {
      // Show plant selection dialog first
      final selectedPlant = await showDialog<String>(
        context: context,
        builder: (context) => const PlantSelectionDialog(),
      );
      
      if (selectedPlant == null || !context.mounted) {
        return;
      }
      
      // Show loading dialog
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      final detection = await detectionService.detectDisease(
        image.path,
        plant: selectedPlant,
      );
      await detectionService.saveDetection(
        detection,
        farmId: farmId,
        plantId: plant.id,
      );
      
      await farmService.updatePlantStatus(farmId, plant.id, PlantStatus.infected);
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Re-detection completed: ${detection.diseaseName}',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
              style: GoogleFonts.inter(),
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

