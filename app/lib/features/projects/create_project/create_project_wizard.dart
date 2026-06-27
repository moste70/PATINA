import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'wizard_state.dart';
import 'steps/step1_kit.dart';
import 'steps/step2_status.dart';
import 'steps/step3_photo.dart';

class CreateProjectWizard extends ConsumerStatefulWidget {
  const CreateProjectWizard({super.key});

  @override
  ConsumerState<CreateProjectWizard> createState() =>
      _CreateProjectWizardState();
}

class _CreateProjectWizardState extends ConsumerState<CreateProjectWizard> {
  final _pageController = PageController();

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
    try {
      final id = await ref.read(createProjectProvider.notifier).save();
      if (mounted) {
        Navigator.of(context).pop();
        // Navigate to the new project detail screen
        // context.push('/projects/$id');
        // Uncomment above when project detail screen is implemented (1A.2)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progetto creato!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nel salvataggio, riprova')),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    final state = ref.read(createProjectProvider);
    if (!state.hasData) return true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vuoi scartare il progetto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Scarta'),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  @override
  Widget build(BuildContext context) {
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
          title: const Text('Nuovo Progetto'),
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
            Step3Photo(onBack: () => _goTo(1), onSave: _save),
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
