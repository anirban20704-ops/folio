class FolioFilters {
  static const List<double> original = [
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static const List<double> greyscale = [
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ];

  static const List<double> magicColor = [
    1.2, 0, 0, 0, 5,
    0, 1.2, 0, 0, 5,
    0, 0, 1.2, 0, 5,
    0, 0, 0, 1, 0,
  ];

  static const List<double> blackAndWhite = [
    1.5, 1.5, 1.5, 0, -255,
    1.5, 1.5, 1.5, 0, -255,
    1.5, 1.5, 1.5, 0, -255,
    0, 0, 0, 1, 0,
  ];

  static const Map<String, List<double>> all = {
    'Original': original,
    'Magic': magicColor,
    'B&W': blackAndWhite,
    'Grey': greyscale,
  };
}