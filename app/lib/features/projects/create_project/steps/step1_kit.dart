import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/l10n_helpers.dart';
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
  bool _brandTouched = false;
  bool _scaleTouched = false;
  bool _categoryTouched = false;

  static const _scaleChips = ['1/12', '1/24', '1/35', '1/48', '1/72', '1/100', '1/144'];
  static const _categoryIcons = {
    'tank': Icons.military_tech_outlined,
    'aircraft': Icons.flight_outlined,
    'figure': Icons.person_outline,
    'ship': Icons.directions_boat_outlined,
    'car': Icons.directions_car_outlined,
    'motorcycle': Icons.two_wheeler_outlined,
    'diorama': Icons.landscape_outlined,
    'other': Icons.category_outlined,
  };

  static final _scaleRegex = RegExp(r'^1\/\d+$');

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
    final l = AppL10n.of(context);
    final state = ref.watch(createProjectProvider);
    final notifier = ref.read(createProjectProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final nameError = _nameTouched && state.name.trim().isEmpty;
    final brandError = _brandTouched && (state.brand == null || state.brand!.trim().isEmpty);
    final scaleValue = state.scale ?? '';
    final scaleError = _scaleTouched && scaleValue.trim().isEmpty
        ? l.errorScaleRequired
        : _scaleTouched && scaleValue.trim().isNotEmpty && !_scaleRegex.hasMatch(scaleValue.trim())
            ? l.errorScaleFormat
            : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Text(l.projectStepKit, style: tt.displaySmall),
        const SizedBox(height: 24),

        // Nome
        TextField(
          controller: _nameCtrl,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l.projectNameLabelRequired,
            hintText: l.projectNameHint,
            errorText: nameError ? l.errorNameRequired : null,
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
          decoration: InputDecoration(
            labelText: l.projectBrandLabelRequired,
            hintText: l.projectBrandHint,
            errorText: brandError ? l.errorBrandRequired : null,
          ),
          onChanged: (v) {
            setState(() => _brandTouched = true);
            notifier.setBrand(v);
          },
        ),
        const SizedBox(height: 16),

        // Scala
        TextField(
          controller: _scaleCtrl,
          decoration: InputDecoration(
            labelText: l.projectScaleLabelRequired,
            hintText: l.projectScaleHint,
            errorText: scaleError,
          ),
          onChanged: (v) {
            setState(() => _scaleTouched = true);
            notifier.setScale(v);
          },
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
        Builder(builder: (ctx) {
          final categoryError = _categoryTouched && state.category == null;
          final labelColor = categoryError ? Theme.of(ctx).colorScheme.error : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.projectCategoryLabelRequired,
                style: tt.titleSmall?.copyWith(color: labelColor),
              ),
              if (categoryError) ...[
                const SizedBox(height: 4),
                Text(
                  l.errorCategoryRequired,
                  style: tt.bodySmall?.copyWith(color: Theme.of(ctx).colorScheme.error),
                ),
              ],
            ],
          );
        }),
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
              label: Text(l.categoryLabel(cat)),
              onSelected: (_) {
                setState(() => _categoryTouched = true);
                notifier.setCategory(cat);
              },
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
          onPressed: () {
            setState(() {
              _nameTouched = true;
              _brandTouched = true;
              _scaleTouched = true;
              _categoryTouched = true;
            });
            if (state.step1Valid) widget.onNext();
          },
          child: Text(l.actionNext),
        ),
      ],
    );
  }
}
