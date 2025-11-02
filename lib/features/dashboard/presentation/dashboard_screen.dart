import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_detection/core/routes/app_router.dart';
import 'package:ai_detection/core/services/auth_service.dart';
import 'package:ai_detection/core/services/detection_service.dart';
import 'package:ai_detection/features/dashboard/widgets/stats_card.dart';
import 'package:ai_detection/features/dashboard/widgets/recent_detection_card.dart';
import 'package:ai_detection/features/dashboard/widgets/plants_chart.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final detectionService = context.watch<DetectionService>();
    final recentDetections = detectionService.recentDetections.take(5).toList();
    final weeklyStats = detectionService.getWeeklyStats();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, AppRouter.login);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (authService.currentUser != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          authService.currentUser!.username[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Welcome, ${authService.currentUser!.username}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: StatsCard(
                      title: 'Total Infected',
                      value: detectionService.totalInfected.toString(),
                      icon: Icons.warning,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StatsCard(
                      title: 'Total Healthy',
                      value: detectionService.totalHealthy.toString(),
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              PlantsChart(stats: weeklyStats),
              const SizedBox(height: 24),
              Text(
                'Recent Detections',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              if (recentDetections.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No detections yet')),
                  ),
                )
              else
                ...recentDetections.map(
                  (detection) => RecentDetectionCard(detection: detection),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRouter.detection);
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Go to Detection Page'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRouter.farmList);
                      },
                      icon: const Icon(Icons.agriculture),
                      label: const Text('Go to Farm Management Page'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

