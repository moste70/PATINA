class AppConstants {
  static const List<String> projectCategories = [
    'tank', 'aircraft', 'figure', 'ship', 'diorama', 'other',
  ];

  static const List<String> projectStatuses = [
    'todo', 'in_progress', 'completed',
  ];

  static const Map<String, String> projectStatusLabels = {
    'todo': 'Da iniziare',
    'in_progress': 'In corso',
    'completed': 'Completato',
  };

  static const Map<String, String> categoryLabels = {
    'tank': 'Carro Armato',
    'aircraft': 'Aereo',
    'figure': 'Figura',
    'ship': 'Nave',
    'diorama': 'Diorama',
    'other': 'Altro',
  };

  static const List<String> paintQuantities = ['full', 'half', 'low', 'empty'];

  static const Map<String, String> quantityLabels = {
    'full': 'Piena',
    'half': 'Metà',
    'low': 'Quasi finita',
    'empty': 'Finita',
  };

  static const List<String> paintTechniques = ['brush', 'airbrush', 'sponge'];

  static const Map<String, String> techniqueLabels = {
    'brush': 'Pennello',
    'airbrush': 'Aerografo',
    'sponge': 'Spugnatura',
  };

  static const List<String> supportedBrands = ['vallejo', 'citadel', 'tamiya'];

  static const Map<String, String> brandLabels = {
    'vallejo': 'Vallejo',
    'citadel': 'Citadel',
    'tamiya': 'Tamiya',
  };
}
