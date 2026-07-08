import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import 'wizard_state.dart';
import 'steps/step1_kit.dart';
import 'steps/step2_status.dart';
import 'steps/step3_photo.dart';

class CreateProjectWizard extends ConsumerStatefulWidget {
  /// Se fornito, il wizard opera in modalità modifica (pre-popola i campi e fa update).
  final Project? project;
  const CreateProjectWizard({super.key, this.project});

  @override
  ConsumerState<CreateProjectWizard> createState() =>
      _CreateProjectWizardState();
}

class _CreateProjectWizardState extends ConsumerState<CreateProjectWizard> {
  final _pageController = PageController();

  bool get _isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      ref.read(createProjectProvider.notifier).initFromProject(widget.project!);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    ref.read(createProjectProvider.notifier).goToStep(step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _save() async {
    final l = AppL10n.of(context);
    try {
      if (_isEditing) {
        await ref
            .read(createProjectProvider.notifier)
            .update(widget.project!.id);
        if (mounted) Navigator.of(context).pop();
      } else {
        final id = await ref.read(createProjectProvider.notifier).save();
        if (mounted) {
          Navigator.of(context).pop();
          context.go('/projects/$id');
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.errorSaveRetry)),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_isEditing) return true;
    final state = ref.read(createProjectProvider);
    if (!state.hasData) return true;
    final l = AppL10n.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ll = AppL10n.of(ctx);
        return AlertDialog(
          title: Text(ll.projectDiscardTitle),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ll.actionCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ll.actionDiscard),
            ),
          ],
        );
      },
    );
    return confirm ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final state = ref.watch(createProjectProvider);
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _onWillPop()) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              if (await _onWillPop()) Navigator.of(context).pop();
            },
          ),
          title: Text(_isEditing ? l.projectEditTitle : l.projectNewTitle),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: _StepIndicator(
              currentStep: state.currentStep,
              totalSteps: 3,
              color: scheme.primary,
            ),
          ),
        ),
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Step1Kit(onNext: () => _goTo(1)),
            Step2Status(onNext: () => _goTo(2), onBack: () => _goTo(0)),
            Step3Photo(
              onBack: () => _goTo(1),
              onSave: _save,
              saveLabel: _isEditing ? l.actionSaveChanges : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final Color color;

  const _StepIndicator({
    required this.currentStep,
    required this.totalSteps,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (i) {
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 3,
            margin: EdgeInsets.only(right: i < totalSteps - 1 ? 2 : 0),
            color: i <= currentStep
                ? color
                : color.withOpacity(0.18),
          ),
        );
      }),
    );
  }
}
