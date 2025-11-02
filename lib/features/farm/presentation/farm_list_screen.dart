import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_detection/core/routes/app_router.dart';
import 'package:ai_detection/core/services/farm_service.dart';
import 'package:ai_detection/features/farm/widgets/add_farm_dialog.dart';

class FarmListScreen extends StatelessWidget {
  const FarmListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final farmService = context.watch<FarmService>();
    final farms = farmService.farms;

    return Scaffold(
      appBar: AppBar(title: const Text('Farm Management')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: farms.length,
        itemBuilder: (context, index) {
          final farm = farms[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: const Icon(Icons.agriculture, color: Colors.white),
              ),
              title: Text(
                farm.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Location: ${farm.location}'),
                  Text('Crop Type: ${farm.cropType}'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Chip(
                        label: Text('${farm.totalPlants} plants'),
                        backgroundColor: Colors.blue.shade50,
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text('${farm.infectedPlants} infected'),
                        backgroundColor: Colors.red.shade50,
                      ),
                    ],
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRouter.farmDetail,
                  arguments: farm.id,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const AddFarmDialog(),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Farm'),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: OutlinedButton(
          onPressed: () {
            Navigator.pushReplacementNamed(context, AppRouter.dashboard);
          },
          child: const Text('Back to Dashboard'),
        ),
      ),
    );
  }
}

