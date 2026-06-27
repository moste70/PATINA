import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
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
    await _markOnboardingCompleted();
    if (mounted) context.go('/projects');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Corpo schermate
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _Page1Welcome(onNext: () => _goTo(1)),
                  _Page2Permissions(
                    cameraGranted: _cameraGranted,
                    photosGranted: _photosGranted,
                    onRequest: _requestPermissions,
                    onSkip: () => _goTo(2),
                    onNext: () => _goTo(2),
                  ),
                  _Page3Ready(
                    onCreateProject: _finish,
                    onExplore: _finish,
                  ),
                ],
              ),
            ),
            // Indicatori di pagina
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
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
          PatinaMark(size: 120, monoColor: scheme.primary),
          const SizedBox(height: 40),
          Text('Benvenuto in Patina',
              style: tt.displayMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
            'Il taccuino digitale per i tuoi modelli in scala.',
            style: tt.bodyLarge?.copyWith(color: scheme.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Tieni traccia dei tuoi progetti, delle vernici e delle ricette di miscelazione — tutto offline, tutto tuo.',
            style: tt.bodyMedium?.copyWith(
                color: scheme.onSurface.withOpacity(0.6)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52)),
            child: const Text('Inizia'),
          ),
        ],
      ),
    );
  }
}

// ── Schermata 2 — Permessi ───────────────────────────────────────────────────

class _Page2Permissions extends StatelessWidget {
  final bool? cameraGranted;
  final bool? photosGranted;
  final VoidCallback onRequest;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  const _Page2Permissions({
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
          Text('Patina ha bisogno di accedere a:',
              style: tt.titleLarge),
          const SizedBox(height: 24),
          _PermissionTile(
            icon: Icons.camera_alt_outlined,
            title: 'Fotocamera',
            description:
                'Scatta foto dei tuoi modelli durante la lavorazione',
            granted: cameraGranted,
          ),
          const SizedBox(height: 12),
          _PermissionTile(
            icon: Icons.photo_library_outlined,
            title: 'Foto e file',
            description:
                'Importa immagini dalla galleria e salva i tuoi lavori',
            granted: photosGranted,
          ),
          const SizedBox(height: 36),
          FilledButton(
            onPressed: _allGranted ? onNext : onRequest,
            style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52)),
            child: Text(_allGranted ? 'Continua' : 'Concedi permessi'),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: onSkip,
              child: Text('Salta per ora',
                  style: TextStyle(
                      color: scheme.onSurface.withOpacity(0.5))),
            ),
          ),
          Center(
            child: Text(
              'Puoi abilitarli in qualsiasi momento da\nImpostazioni → App → Patina',
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

    final statusLabel = granted == true
        ? 'Concesso ✓'
        : granted == false
            ? 'Negato'
            : 'In attesa';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant,
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

// ── Schermata 3 — Pronto ─────────────────────────────────────────────────────

class _Page3Ready extends StatelessWidget {
  final VoidCallback onCreateProject;
  final VoidCallback onExplore;
  const _Page3Ready({required this.onCreateProject, required this.onExplore});

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
          Text('Sei pronto!',
              style: tt.displayMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
            'Crea il tuo primo progetto e inizia a documentare il tuo lavoro.',
            style: tt.bodyLarge?.copyWith(color: scheme.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: onCreateProject,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Crea il primo progetto'),
            style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onExplore,
            child: Text('Esplora l\'app',
                style: TextStyle(
                    color: scheme.onSurface.withOpacity(0.6))),
          ),
        ],
      ),
    );
  }
}
