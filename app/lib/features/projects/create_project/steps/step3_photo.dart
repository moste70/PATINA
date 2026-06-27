import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../wizard_state.dart';

class Step3Photo extends ConsumerWidget {
  final VoidCallback onBack;
  final Future<void> Function() onSave;
  const Step3Photo({super.key, required this.onBack, required this.onSave});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(createProjectProvider);
    final notifier = ref.read(createProjectProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Text('Foto Copertina', style: tt.displaySmall),
        const SizedBox(height: 8),
        Text('Opzionale — puoi aggiungerla in qualsiasi momento',
            style: tt.bodySmall),
        const SizedBox(height: 24),

        // Preview / placeholder
        AspectRatio(
          aspectRatio: 1,
          child: state.coverPhotoPath != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(state.coverPhotoPath!),
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        icon: const Icon(Icons.close, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(32, 32),
                        ),
                        onPressed: () => notifier.setCoverPhoto(null),
                      ),
                    ),
                  ],
                )
              : Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: scheme.outline, width: 1.5,
                        style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 48, color: scheme.onSurface.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text('Aggiungi copertina',
                          style: tt.bodyMedium?.copyWith(
                              color: scheme.onSurface.withOpacity(0.4))),
                    ],
                  ),
                ),
        ),

        if (state.coverPhotoPath == null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Fotocamera'),
                  onPressed: () => _pick(context, notifier, ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Galleria'),
                  onPressed: () => _pick(context, notifier, ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 32),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: state.isSaving ? null : onBack,
                child: const Text('Indietro'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: state.isSaving ? null : onSave,
                child: state.isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Crea Progetto'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pick(
    BuildContext context,
    CreateProjectNotifier notifier,
    ImageSource source,
  ) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, imageQuality: 85);
      if (file != null) notifier.setCoverPhoto(file.path);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile accedere alle foto')),
        );
      }
    }
  }
}
