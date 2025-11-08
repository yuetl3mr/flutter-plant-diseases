import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_detection/core/theme/app_theme.dart';
import 'package:ai_detection/core/widgets/modern_card.dart';

class PlantSelectionDialog extends StatefulWidget {
  final String? selectedPlant;

  const PlantSelectionDialog({super.key, this.selectedPlant});

  @override
  State<PlantSelectionDialog> createState() => _PlantSelectionDialogState();
}

class _PlantSelectionDialogState extends State<PlantSelectionDialog> {
  static const List<String> plants = [
    'Apple',
    'Blueberry',
    'Cherry_(including_sour)',
    'Corn_(maize)',
    'Grape',
    'Orange',
    'Peach',
    'Pepper,_bell',
    'Potato',
    'Raspberry',
    'Soybean',
    'Squash',
    'Strawberry',
    'Tomato',
  ];

  String? _selectedPlant;

  @override
  void initState() {
    super.initState();
    _selectedPlant = widget.selectedPlant;
  }

  String _formatPlantName(String plant) {
    // Format plant names for better display
    return plant
        .replaceAll('_', ' ')
        .replaceAll('(including sour)', '(including sour)')
        .split(' ')
        .map((word) => word.isEmpty
            ? ''
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 400,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.eco_rounded,
                      color: AppTheme.primaryGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Select Plant Type',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context, null),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: plants.length,
                  itemBuilder: (context, index) {
                    final plant = plants[index];
                    final isSelected = _selectedPlant == plant;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ModernCard(
                        padding: EdgeInsets.zero,
                        color: isSelected 
                            ? AppTheme.accentGreen.withOpacity(0.3)
                            : Colors.white,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryGreen
                                  : AppTheme.accentGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.eco_rounded,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.primaryGreen,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            _formatPlantName(plant),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: AppTheme.primaryGreen,
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedPlant = plant;
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _selectedPlant == null
                          ? null
                          : () => Navigator.pop(context, _selectedPlant),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Continue',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
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
