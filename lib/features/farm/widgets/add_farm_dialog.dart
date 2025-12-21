import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ai_detection/core/services/farm_service.dart';
import 'package:ai_detection/core/theme/app_theme.dart';
import 'package:ai_detection/core/widgets/modern_button.dart';
import 'package:ai_detection/core/constants/crop_constants.dart';

class AddFarmDialog extends StatefulWidget {
  const AddFarmDialog({super.key});

  @override
  State<AddFarmDialog> createState() => _AddFarmDialogState();
}

class _AddFarmDialogState extends State<AddFarmDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final Set<String> _selectedCropTypes = {};
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _handleAdd() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCropTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select at least one crop type',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    final farmService = context.read<FarmService>();
    await farmService.addFarm(
      _nameController.text.trim(),
      _locationController.text.trim(),
      _selectedCropTypes.join(', '),
    );
    setState(() => _isLoading = false);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Farm added successfully',
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
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
                        Icons.agriculture_rounded,
                        color: AppTheme.primaryGreen,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Add New Farm',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Farm Name',
                    prefixIcon: const Icon(Icons.agriculture_outlined),
                    labelStyle: GoogleFonts.inter(),
                  ),
                  style: GoogleFonts.inter(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter farm name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    labelStyle: GoogleFonts.inter(),
                  ),
                  style: GoogleFonts.inter(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter location';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Crop Types',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.textSecondary.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Wrap(
                      children: CropConstants.availableCrops.map((crop) {
                        final isSelected = _selectedCropTypes.contains(crop);
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: FilterChip(
                            label: Text(
                              CropConstants.formatCropName(crop),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: isSelected ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                            selected: isSelected,
                            backgroundColor: Colors.transparent,
                            selectedColor: AppTheme.primaryGreen,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedCropTypes.add(crop);
                                } else {
                                  _selectedCropTypes.remove(crop);
                                }
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ModernButton(
                        label: 'Add Farm',
                        icon: Icons.add_rounded,
                        onPressed: _isLoading ? null : _handleAdd,
                        isLoading: _isLoading,
                      ),
                    ),
                  ],
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
