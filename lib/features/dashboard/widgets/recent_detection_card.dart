import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:ai_detection/core/models/detection_model.dart';
import 'package:ai_detection/core/services/detection_service.dart';
import 'package:ai_detection/core/theme/app_theme.dart';
import 'package:ai_detection/core/widgets/modern_card.dart';
import 'package:ai_detection/core/routes/app_router.dart';
import 'package:ai_detection/features/detection/presentation/detection_detail_screen.dart';

class RecentDetectionCard extends StatelessWidget {
  final DetectionModel detection;

  const RecentDetectionCard({super.key, required this.detection});

  String _formatConfidence(double confidence) {
    // Convert to percentage if needed
    double percentage = confidence > 1 ? confidence : confidence * 100;
    // Floor to 2 decimal places (don't round up)
    double floored = ((percentage * 100).truncate() / 100.0);
    return floored.toStringAsFixed(2);
  }

  Future<void> _handleDelete(BuildContext context) async {
    final detectionService = context.read<DetectionService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Detection',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this detection?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorRed,
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await detectionService.deleteDetection(detection.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Detection deleted',
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'detection_${detection.id}',
      child: GestureDetector(
        onLongPress: () => _handleDelete(context),
        child: ModernCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetectionDetailScreen(detection: detection),
              ),
            );
          },
        child: Builder(
          builder: (context) {
            final isHealthy = detection.diseaseName.toLowerCase().contains('healthy');
            final statusColor = isHealthy ? AppTheme.successGreen : AppTheme.errorRed;
            final statusIcon = isHealthy ? Icons.check_circle_rounded : Icons.bug_report_rounded;
            
            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        detection.diseaseName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatConfidence(detection.confidence)}% confidence',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy • HH:mm').format(detection.date),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        detection.treatment.split('\n').first,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_formatConfidence(detection.confidence)}%',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        ),
      ),
    );
  }
}
