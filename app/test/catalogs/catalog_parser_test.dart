import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Test eseguibili senza build_runner — nessuna dipendenza da codice generato.
// Runnare da app/: flutter test test/catalogs/catalog_parser_test.dart

void main() {
  const catalogsPath = 'assets/catalogs';

  const expectedFiles = [
    'vallejo_model_color.json',
    'vallejo_model_air.json',
    'citadel_base.json',
    'tamiya_xf.json',
    'tamiya_x.json',
    'gunze_aqueous.json',
    'gunze_mr_color.json',
    'gunze_mr_metal.json',
    'humbrol_enamel.json',
    'lifecolor_ua.json',
    'lifecolor_lc.json',
  ];

  Map<String, dynamic> _loadCatalog(String filename) {
    final file = File('$catalogsPath/$filename');
    expect(file.existsSync(), isTrue, reason: 'File non trovato: $filename');
    return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  group('Presenza file', () {
    test('tutti e 11 i cataloghi sono presenti', () {
      for (final name in expectedFiles) {
        expect(
          File('$catalogsPath/$name').existsSync(),
          isTrue,
          reason: '$name non trovato in assets/catalogs/',
        );
      }
    });
  });

  group('Struttura JSON', () {
    for (final filename in expectedFiles) {
      group(filename, () {
        late Map<String, dynamic> data;

        setUp(() => data = _loadCatalog(filename));

        test('contiene i campi root obbligatori', () {
          expect(data['brand'], isA<String>().having((s) => s, 'brand', isNotEmpty));
          expect(data['line'],  isA<String>().having((s) => s, 'line',  isNotEmpty));
          expect(data['version'], isA<String>());
          expect(data['paints'], isA<List>());
        });

        test('versione è 2024.1', () {
          expect(data['version'], equals('2024.1'));
        });

        test('paints non è vuota', () {
          final paints = data['paints'] as List;
          expect(paints, isNotEmpty);
        });

        test('ogni vernice ha code, name, hex validi', () {
          final paints = data['paints'] as List;
          for (final raw in paints) {
            final p = raw as Map<String, dynamic>;
            expect(p['code'], isA<String>().having((s) => s, 'code', isNotEmpty),
                reason: 'code mancante o vuoto in $filename');
            expect(p['name'], isA<String>().having((s) => s, 'name', isNotEmpty),
                reason: 'name mancante o vuoto in $filename: code=${p['code']}');
            expect(p['hex'], matches(RegExp(r'^#[0-9A-Fa-f]{6}$')),
                reason: 'hex non valido in $filename: code=${p['code']}, hex=${p['hex']}');
          }
        });

        test('nessun codice duplicato', () {
          final paints = data['paints'] as List;
          final codes = paints.map((p) => (p as Map)['code'] as String).toList();
          final duplicates = codes
              .where((c) => codes.where((x) => x == c).length > 1)
              .toSet();
          expect(duplicates, isEmpty,
              reason: 'Codici duplicati in $filename: $duplicates');
        });

        test('brand nel file corrisponde al nome file', () {
          final brand = data['brand'] as String;
          final filenameBrand = filename.split('_').first;
          expect(brand, equals(filenameBrand),
              reason: '$filename: brand="$brand" non corrisponde al nome file');
        });
      });
    }
  });

  group('Statistiche globali', () {
    test('totale colori > 900', () {
      var total = 0;
      for (final filename in expectedFiles) {
        final data = _loadCatalog(filename);
        total += (data['paints'] as List).length;
      }
      expect(total, greaterThan(900),
          reason: 'Troppi pochi colori: trovati $total, attesi > 900');
    });

    test('nessun HEX è #000000 o #FFFFFF (valori placeholder non validi)', () {
      const invalid = {'#000000', '#FFFFFF'};
      for (final filename in expectedFiles) {
        final data = _loadCatalog(filename);
        final paints = data['paints'] as List;
        for (final raw in paints) {
          final p = raw as Map<String, dynamic>;
          expect(invalid.contains(p['hex']), isFalse,
              reason:
                  'HEX placeholder rilevato in $filename: code=${p['code']}, hex=${p['hex']}');
        }
      }
    });
  });
}
