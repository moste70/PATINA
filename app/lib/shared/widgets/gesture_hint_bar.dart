import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// One-time dismissable hint bar. Shows on first visit, then never again.
// Usage: GestureHintBar(hintKey: 'hint_inventory', message: '...')
class GestureHintBar extends StatefulWidget {
  final String hintKey;
  final String message;

  const GestureHintBar({
    super.key,
    required this.hintKey,
    required this.message,
  });

  @override
  State<GestureHintBar> createState() => _GestureHintBarState();
}

class _GestureHintBarState extends State<GestureHintBar>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _checkShouldShow();
  }

  Future<void> _checkShouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(widget.hintKey) ?? false;
    if (!seen && mounted) {
      setState(() => _visible = true);
      _ctrl.forward();
    }
  }

  Future<void> _dismiss() async {
    await _ctrl.reverse();
    if (!mounted) return;
    setState(() => _visible = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.hintKey, true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withOpacity(0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: scheme.primary.withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.touch_app_outlined, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withOpacity(0.75),
                    ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 16, color: scheme.onSurface.withOpacity(0.4)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Chiudi',
              onPressed: _dismiss,
            ),
          ],
        ),
      ),
    );
  }
}
