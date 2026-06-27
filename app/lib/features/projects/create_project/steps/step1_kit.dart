import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/constants/app_constants.dart';
import '../wizard_state.dart';

class Step1Kit extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  const Step1Kit({super.key, required this.onNext});

  @override
  ConsumerState<Step1Kit> createState() => _Step1KitState();
}

class _Step1KitState extends ConsumerState<Step1Kit> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _scaleCtrl;
  bool _nameTouched = false;

  static const _scaleChips = ['1/35', '1/48', '1/72', '1/100', '1/144'];
  static const _categoryIcons = {
    'tank': Icons.military_tech_outlined,
    'aircraft': Icons.flight_outlined,
    'figure': Icons.person_outline,
    'ship': Icons.directions_boat_outlined,
    'diorama': Icons.landscape_outlined,
    'other': Icons.category_outlined,
  };

  @override
  void initState() {
    super.initState();
    final s = ref.read(createProjectProvider);
    _nameCtrl = TextEditingController(text: s.name);
    _brandCtrl = TextEditingController(text: s.brand ?? '');
    _scaleCtrl = TextEditingController(text: s.scale ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createProjectProvider);
    final notifier = ref.read(createProjectProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final nameError = _nameTouched && state.name.trim().isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Text('Il Kit', style: tt.displaySmall),
        const SizedBox(height: 24),

        // Nome
        TextField(
          controller: _nameCtrl,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Nome modello *',
            hintText: 'es. Tiger I Ausf. E',
            errorText: nameError ? 'Il nome è obbligatorio' : null,
            counterText: '${_nameCtrl.text.length}/80',
          ),
          onChanged: (v) {
            setState(() => _nameTouched = true);
            notifier.setName(v);
          },
        ),
        const SizedBox(height: 16),

        // Marca
        TextField(
          controller: _brandCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Marca kit',
            hintText: 'es. Tamiya, Revell, Hasegawa',
          ),
          onChanged: notifier.setBrand,
        ),
        const SizedBox(height: 16),

        // Scala
        TextField(
          controller: _scaleCtrl,
          decoration: const InputDecoration(
            labelText: 'Scala',
            hintText: 'es. 1/35',
          ),
          onChanged: notifier.setScale,
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _scaleChips.map((chip) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(chip),
                  onPressed: () {
                    _scaleCtrl.text = chip;
                    notifier.setScale(chip);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),

        // Categoria
        Text('Categoria *', style: tt.titleSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: AppConstants.projectCategories.map((cat) {
            final selected = state.category == cat;
            return FilterChip(
              selected: selected,
              avatar: Icon(
                _categoryIcons[cat] ?? Icons.category_outlined,
                size: 16,
                color: selected ? scheme.primary : scheme.onSurface,
              ),
              label: Text(AppConstants.categoryLabels[cat] ?? cat),
              onSelected: (_) => notifier.setCategory(cat),
              selectedColor: scheme.primary.withOpacity(0.18),
              checkmarkColor: scheme.primary,
              side: BorderSide(
                color: selected ? scheme.primary : scheme.outline,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),

        FilledButton(
          onPressed: state.step1Valid
              ? () {
                  setState(() => _nameTouched = true);
                  if (state.step1Valid) widget.onNext();
                }
              : () => setState(() => _nameTouched = true),
          child: const Text('Avanti'),
        ),
      ],
    );
  }
}
