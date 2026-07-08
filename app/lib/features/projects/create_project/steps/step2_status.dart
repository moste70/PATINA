import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/l10n_helpers.dart';
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
    final l = AppL10n.of(context);
    final state = ref.watch(createProjectProvider);
    final notifier = ref.read(createProjectProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Text(l.projectStep2StatusTitle, style: tt.displaySmall),
        const SizedBox(height: 24),

        Text(l.projectStatusSectionLabel, style: tt.titleSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          // 'paused' non ha senso come stato iniziale alla creazione
          children: AppConstants.projectStatuses
              .where((s) => s != 'paused')
              .map((s) {
            final selected = state.status == s;
            return FilterChip(
              selected: selected,
              label: Text(l.projectStatusLabel(s)),
              onSelected: (_) => notifier.setStatus(s),
              selectedColor: scheme.primary.withOpacity(0.18),
              checkmarkColor: scheme.primary,
              side: BorderSide(
                color: selected ? scheme.primary : scheme.outline,
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
        TextField(
          controller: _notesCtrl,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: l.projectNotesInitialLabel,
            hintText: l.projectNotesInitialHint,
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
                child: Text(l.actionBack),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: widget.onNext,
                child: Text(l.actionNext),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
