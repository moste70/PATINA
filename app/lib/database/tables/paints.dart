import 'package:drift/drift.dart';

class CatalogPaints extends Table {
  // brand+code sono la chiave naturale stabile — non usare l'ID come riferimento
  IntColumn get id => integer().autoIncrement()();
  TextColumn get brand => text()();          // vallejo|citadel|tamiya
  TextColumn get line => text()();           // model_color|base|xf|…
  TextColumn get code => text()();           // es. "70.950"
  TextColumn get name => text()();
  TextColumn get hex => text()();            // es. "#4A3728"

  @override
  List<Set<Column>> get uniqueKeys => [
        {brand, code},
      ];
}

// Vernici inserite manualmente dall'utente per marche/codici non in catalogo.
// brand+code sono obbligatori e formano la chiave naturale.
// Al momento dell'aggiornamento catalogo, se brand+code coincide con un nuovo
// record in catalog_paints, la voce custom viene rimossa automaticamente.
class CustomPaints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get brand => text()();          // obbligatorio — es. "scale75"
  TextColumn get code => text()();           // obbligatorio — es. "SC-01"
  TextColumn get name => text()();
  TextColumn get hex => text()();            // es. "#2A1F18"
  IntColumn get createdAt => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {brand, code},
      ];
}

// L'inventario referenzia le vernici tramite brand+code (chiave naturale),
// non tramite ID autoincrement, per restare stabile agli aggiornamenti catalogo.
// Se catalogBrand/catalogCode sono valorizzati → vernice da catalogo ufficiale.
// Se customBrand/customCode sono valorizzati → vernice da CustomPaints.
class InventoryPaints extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Riferimento a CatalogPaints (chiave naturale)
  TextColumn get catalogBrand => text().nullable()();
  TextColumn get catalogCode => text().nullable()();
  // Riferimento a CustomPaints (chiave naturale)
  TextColumn get customBrand => text().nullable()();
  TextColumn get customCode => text().nullable()();
  // Dati comuni
  TextColumn get quantity => text().withDefault(const Constant('full'))();  // full|half|low|empty
  TextColumn get notes => text().nullable()();
  IntColumn get purchasedAt => integer().nullable()();
}
