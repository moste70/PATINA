import 'package:flutter/material.dart';

/// Material 3 Window Size Classes adottate da PATINA (vedi CLAUDE.md — Fase 1F).
///
/// - [compact]  < 600 dp  — smartphone verticale
/// - [medium]   600–900 dp — tablet piccolo / smartphone landscape
/// - [expanded] > 900 dp  — tablet grande / foldable aperto
enum WindowSizeClass { compact, medium, expanded }

/// Espone il [WindowSizeClass] corrente a tutto l'albero dei widget sottostante,
/// calcolato una sola volta dalla larghezza disponibile (via [LayoutBuilder]).
///
/// Va installato una sola volta vicino alla radice dell'app (vedi `main.dart`,
/// `MaterialApp.router(builder: ...)`) così ogni schermata può leggere
/// `AdaptiveLayout.of(context)` invece di chiamare `MediaQuery.of(context).size.width`
/// direttamente (vietato da CLAUDE.md).
class AdaptiveLayout extends StatelessWidget {
  final Widget child;
  const AdaptiveLayout({super.key, required this.child});

  static const double compactMaxWidth = 600.0;
  static const double mediumMaxWidth = 900.0;

  static WindowSizeClass classify(double width) {
    if (width < compactMaxWidth) return WindowSizeClass.compact;
    if (width < mediumMaxWidth) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }

  static WindowSizeClass of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_WindowSizeClassScope>();
    assert(scope != null, 'AdaptiveLayout.of() chiamato senza un ancestor AdaptiveLayout');
    return scope!.sizeClass;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _WindowSizeClassScope(
          sizeClass: classify(constraints.maxWidth),
          child: child,
        );
      },
    );
  }
}

class _WindowSizeClassScope extends InheritedWidget {
  final WindowSizeClass sizeClass;
  const _WindowSizeClassScope({
    required this.sizeClass,
    required super.child,
  });

  @override
  bool updateShouldNotify(_WindowSizeClassScope oldWidget) =>
      oldWidget.sizeClass != sizeClass;
}

/// Vincola la larghezza massima dei contenuti a colonna singola su schermi
/// larghi (tablet/desktop), centrando il contenuto (1F.3).
///
/// Uso: `body: const AdaptiveMaxWidth(child: /* contenuto schermata */)`
class AdaptiveMaxWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const AdaptiveMaxWidth({super.key, required this.child, this.maxWidth = 840});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
