import 'app_localizations.dart';

extension AppL10nHelpers on AppL10n {
  String projectStatusLabel(String status) => switch (status) {
        'todo' => statusTodo,
        'in_progress' => statusInProgress,
        'completed' => statusCompleted,
        'paused' => statusPaused,
        _ => status,
      };

  String categoryLabel(String category) => switch (category) {
        'tank' => categoryTank,
        'aircraft' => categoryAircraft,
        'figure' => categoryFigure,
        'ship' => categoryShip,
        'car' => categoryCar,
        'motorcycle' => categoryMotorcycle,
        'diorama' => categoryDiorama,
        _ => categoryOther,
      };

  String paintLineLabel(String line) => switch (line) {
        'model_color' => paintLineModelColor,
        'model_air' => paintLineModelAir,
        'xf_flat' => paintLineXfFlat,
        'x_gloss' => paintLineXGloss,
        'lp_lacquer' => paintLineLpLacquer,
        'ts_spray' => paintLineTsSpray,
        'mr_color' => paintLineMrColor,
        'aqueous' => paintLineAqueous,
        'mr_metal' => paintLineMrMetal,
        'enamel' => paintLineEnamel,
        'lc' => paintLineLc,
        'ua' => paintLineUa,
        'base' => paintLineCitadelBase,
        _ => line,
      };
}
