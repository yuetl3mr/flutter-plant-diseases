class CropConstants {
  static const List<String> availableCrops = [
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

  static String formatCropName(String crop) {
    // Format crop names for better display
    return crop
        .replaceAll('_', ' ')
        .replaceAll('(including sour)', '(including sour)')
        .split(' ')
        .map((word) => word.isEmpty
            ? ''
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}
