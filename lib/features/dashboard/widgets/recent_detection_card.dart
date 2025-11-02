import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ai_detection/core/models/detection_model.dart';

class RecentDetectionCard extends StatelessWidget {
  final DetectionModel detection;

  const RecentDetectionCard({super.key, required this.detection});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.shade100,
          child: const Icon(Icons.bug_report, color: Colors.red),
        ),
        title: Text(
          detection.diseaseName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confidence: ${(detection.confidence * 100).toStringAsFixed(1)}%'),
            Text(DateFormat('MMM dd, yyyy HH:mm').format(detection.date)),
          ],
        ),
        trailing: Chip(
          label: Text(
            '${(detection.confidence * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: Colors.red.shade50,
        ),
      ),
    );
  }
}

