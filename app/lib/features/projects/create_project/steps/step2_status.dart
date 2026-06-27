import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/constants/app_constants.dart';
import '../wizard_state.dart';

class Step2Status extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const Step2Status({super.key, required this.onNext, required this.onBack});

  @override
  ConsumerState<Step2Status> createState() => _Step2StatusState();
}

class _Step2StatusState extends ConsumerState<Step2Status> {
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: ref.read(createProjectProvider).notes ?? '');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createProjectProvider);
    final notifier = ref.read(createProjectProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Text('Stato Iniziale', style: tt.displaySmall),
        const SizedBox(height: 24),

        Text('Stato', style: tt.titleSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: AppConstants.projectStatuses.map((s) {
            final selected = state.status == s;
            return FilterChip(
              selected: selected,
              label: Text(AppConstants.projectStatusLabels[s] ?? s),
              onSelected: (_) => notifier.setStatus(s),
              selectedColor: scheme.primary.withOpacity(0.18),
              checkmarkColor: scheme.primary,
              side: BorderSide(
                color: selected ? scheme.primary : scheme.outline,
              ),
            );
          }).toList(),
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: state.status == 'todo'
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Avanzamento', style: tt.titleSmall),
                        Text('${state.progress}%',
                            style: tt.labelMedium
                                ?.copyWith(color: scheme.primary)),
                      ],
                    ),
                    Slider(
                      value: state.progress.toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      activeColor: scheme.primary,
                      onChanged: state.status == 'completed'
                          ? null
                          : (v) => notifier.setProgress(v.round()),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 24),
        TextField(
          controller: _notesCtrl,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Note iniziali',
            hintText: 'Aggiungi note, riferimenti, obiettivi…',
            alignLabelWithHint: true,
          ),
          onChanged: notifier.setNotes,
        ),
        const SizedBox(height: 32),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onBack,
                child: const Text('Indietro'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: widget.onNext,
                child: const Text('Avanti'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
