import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/utils/permissions.dart';
import '../../shared/widgets/patina_logo.dart';

const _kOnboardingKey = 'onboarding_completed';

Future<bool> isOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingKey) ?? false;
}

Future<void> _markOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingKey, true);
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  // Stato permessi
  bool? _cameraGranted;
  bool? _photosGranted;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final camera = await Permission.camera.isGranted;
    final photos = await PermissionService.isPhotosGranted();
    if (mounted) setState(() {
      _cameraGranted = camera;
      _photosGranted = photos;
    });
  }

  void _goTo(int page) {
    setState(() => _page = page);
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _requestPermissions() async {
    final camera = await PermissionService.requestCamera();
    final photos = await PermissionService.requestPhotos();
    if (mounted) setState(() {
      _cameraGranted = camera;
      _photosGranted = photos;
    });
  }

  Future<void> _finish() async {
    final db = ref.read(databaseProvider);
    await db.initializeDemoProject();
    await _markOnboardingCompleted();
    if (mounted) context.go('/projects');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (_page > 0) _goTo(_page - 1);
      },
      child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Corpo schermate
            Expanded(
              child: PageView(
                controller: _controller,
                // Blocca swipe indietro dalla prima schermata
                physics: _page == 0
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _Page1Welcome(onNext: () => _goTo(1)),
                  _Page2Features(onNext: () => _goTo(2)),
                  _Page3Permissions(
                    cameraGranted: _cameraGranted,
                    photosGranted: _photosGranted,
                    onRequest: _requestPermissions,
                    onSkip: () => _goTo(3),
                    onNext: () => _goTo(3),
                  ),
                  _Page4Ready(onFinish: _finish),
                ],
              ),
            ),
            // Indicatori di pagina
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? scheme.primary
                          : scheme.primary.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ── Schermata 1 — Benvenuto ──────────────────────────────────────────────────

class _Page1Welcome extends StatelessWidget {
  final VoidCallback onNext;
  const _Page1Welcome({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const PatinaMark(size: 120),
          const SizedBox(height: 40),
          Text(AppL10n.of(context).onboardingWelcomeTitle,
              style: tt.displayMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
            AppL10n.of(context).onboardingWelcomeSubtitle,
            style: tt.bodyLarge?.copyWith(color: scheme.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            AppL10n.of(context).onboardingWelcomeBody,
            style: tt.bodyMedium?.copyWith(
                color: scheme.onSurface.withOpacity(0.6)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52)),
            child: Text(AppL10n.of(context).actionStart),
          ),
        ],
      ),
    );
  }
}

// ── Schermata 2 — Cosa puoi fare ─────────────────────────────────────────────

class _Page2Features extends StatelessWidget {
  final VoidCallback onNext;
  const _Page2Features({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppL10n.of(context).onboardingFeaturesTitle, style: tt.displayMedium),
          const SizedBox(height: 8),
          Text(
            AppL10n.of(context).onboardingFeaturesSubtitle,
            style: tt.bodyMedium
                ?.copyWith(color: scheme.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 28),
          _FeatureCard(
            icon: Icons.view_module_outlined,
            title: AppL10n.of(context).onboardingFeatureProjectsTitle,
            description: AppL10n.of(context).onboardingFeatureProjectsDesc,
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.palette_outlined,
            title: AppL10n.of(context).onboardingFeaturePaintsTitle,
            description: AppL10n.of(context).onboardingFeaturePaintsDesc,
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.science_outlined,
            title: AppL10n.of(context).onboardingFeatureRecipesTitle,
            description: AppL10n.of(context).onboardingFeatureRecipesDesc,
          ),
          const SizedBox(height: 12),
          _FeatureCard(
            icon: Icons.push_pin_outlined,
            title: AppL10n.of(context).onboardingFeaturePinsTitle,
            description: AppL10n.of(context).onboardingFeaturePinsDesc,
          ),
          const SizedBox(height: 36),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52)),
            child: Text(AppL10n.of(context).actionNext),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withOpacity(0.12),
            ),
            child: Icon(icon, color: scheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.titleSmall),
                const SizedBox(height: 2),
                Text(description,
                    style: tt.bodySmall?.copyWith(
                        color: scheme.onSurface.withOpacity(0.6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Schermata 3 — Permessi ───────────────────────────────────────────────────

class _Page3Permissions extends StatelessWidget {
  final bool? cameraGranted;
  final bool? photosGranted;
  final VoidCallback onRequest;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _Page3Permissions({
    required this.cameraGranted,
    required this.photosGranted,
    required this.onRequest,
    required this.onSkip,
    required this.onNext,
  });

  bool get _allGranted => (cameraGranted ?? false) && (photosGranted ?? false);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppL10n.of(context).onboardingPermissionsTitle,
              style: tt.titleLarge),
          const SizedBox(height: 24),
          _PermissionTile(
            icon: Icons.camera_alt_outlined,
            title: AppL10n.of(context).onboardingPermissionsCamera,
            description: AppL10n.of(context).onboardingPermissionsCameraDesc,
            granted: cameraGranted,
          ),
          const SizedBox(height: 12),
          _PermissionTile(
            icon: Icons.photo_library_outlined,
            title: AppL10n.of(context).onboardingPermissionsPhotos,
            description: AppL10n.of(context).onboardingPermissionsPhotosDesc,
            granted: photosGranted,
          ),
          const SizedBox(height: 36),
          FilledButton(
            onPressed: _allGranted ? onNext : onRequest,
            style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52)),
            child: Text(_allGranted
                ? AppL10n.of(context).actionContinue
                : AppL10n.of(context).onboardingPermissionsGrant),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: onSkip,
              child: Text(AppL10n.of(context).actionSkip,
                  style: TextStyle(
                      color: scheme.onSurface.withOpacity(0.5))),
            ),
          ),
          Center(
            child: Text(
              AppL10n.of(context).onboardingPermissionsHint,
              style: tt.bodySmall?.copyWith(
                  color: scheme.onSurface.withOpacity(0.4)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool? granted;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final statusColor = granted == true
        ? const Color(0xFF2F8F57)
        : granted == false
            ? const Color(0xFFC8503B)
            : scheme.onSurface.withOpacity(0.4);

    final l = AppL10n.of(context);
    final statusLabel = granted == true
        ? l.onboardingPermissionsGranted
        : granted == false
            ? l.onboardingPermissionsDenied
            : l.onboardingPermissionsPending;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.titleSmall),
                const SizedBox(height: 2),
                Text(description,
                    style: tt.bodySmall?.copyWith(
                        color: scheme.onSurface.withOpacity(0.6))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(statusLabel,
              style: tt.labelSmall?.copyWith(color: statusColor)),
        ],
      ),
    );
  }
}

// ── Schermata 4 — Pronto ─────────────────────────────────────────────────────

class _Page4Ready extends StatelessWidget {
  final VoidCallback onFinish;
  const _Page4Ready({required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withOpacity(0.12),
            ),
            child: Icon(Icons.check_rounded,
                size: 56, color: scheme.primary),
          ),
          const SizedBox(height: 40),
          Text(AppL10n.of(context).onboardingReadyTitle,
              style: tt.displayMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
            AppL10n.of(context).onboardingReadyBody,
            style: tt.bodyLarge?.copyWith(color: scheme.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: onFinish,
            style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52)),
            child: Text(AppL10n.of(context).actionStart),
          ),
        ],
      ),
    );
  }
}
