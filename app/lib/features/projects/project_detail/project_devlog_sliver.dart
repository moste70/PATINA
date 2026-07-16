import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../project_repository.dart';

final _devlogProvider =
    StreamProvider.autoDispose.family<List<ProjectLog>, int>(
  (ref, projectId) =>
      ref.watch(projectRepositoryProvider).watchProjectLogs(projectId),
);

// ── Public sliver ─────────────────────────────────────────────────────────────

class ProjectDevlogSliver extends ConsumerWidget {
  final int projectId;
  const ProjectDevlogSliver({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l = AppL10n.of(context);
    final logsAsync = ref.watch(_devlogProvider(projectId));
    final logs = logsAsync.valueOrNull ?? [];

    return SliverMainAxisGroup(slivers: [
      // Header
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
          child: Row(
            children: [
              Text(
                l.devlogSection,
                style: tt.titleSmall?.copyWith(color: scheme.primary),
              ),
              const SizedBox(width: 8),
              Expanded(child: Divider(color: scheme.outline, thickness: 1)),
              const SizedBox(width: 8),
              Tooltip(
                message: l.devlogAdd,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showAddSheet(context, ref);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.add, size: 20, color: scheme.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Empty state
      if (logs.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: InkWell(
              onTap: () => _showAddSheet(context, ref),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: scheme.outline.withOpacity(0.3),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit_note_outlined,
                        size: 22, color: scheme.onSurfaceVariant.withOpacity(0.45)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.devlogEmpty,
                        style: tt.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant.withOpacity(0.6)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _LogEntry(
                log: logs[i],
                isLast: i == logs.length - 1,
                scheme: scheme,
                tt: tt,
                onDelete: () => ref
                    .read(projectRepositoryProvider)
                    .deleteProjectLog(logs[i].id),
              ),
              childCount: logs.length,
            ),
          ),
        ),
    ]);
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddLogSheet(
        onAdd: (text, photoPath) =>
            ref.read(projectRepositoryProvider).addProjectLog(
                  projectId: projectId,
                  text: text,
                  photoPath: photoPath,
                ),
      ),
    );
  }
}

// ── Timeline entry ────────────────────────────────────────────────────────────

class _LogEntry extends StatelessWidget {
  final ProjectLog log;
  final bool isLast;
  final ColorScheme scheme;
  final TextTheme tt;
  final VoidCallback onDelete;

  const _LogEntry({
    required this.log,
    required this.isLast,
    required this.scheme,
    required this.tt,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(log.createdAt);
    final dateStr =
        '${date.day.toString().padLeft(2, '0')} ${_month(date.month)} ${date.year}';
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          color: scheme.error,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.delete_outline, color: scheme.onError),
      ),
      onDismissed: (_) => onDelete(),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Colonna sinistra: linea verticale + dot ──
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  // Dot
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Linea sotto il dot
                  if (!isLast)
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 2,
                          color: scheme.outline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // ── Contenuto ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Data + ora
                    Row(
                      children: [
                        Text(
                          dateStr,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeStr,
                          style: tt.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Testo
                    Text(log.body, style: tt.bodyMedium),
                    // Foto opzionale
                    if (log.photoPath != null) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _openPhoto(context),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(log.photoPath!),
                            width: double.infinity,
                            height: 160,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPhoto(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(File(log.photoPath!), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  String _month(int m) => const [
        '', 'gen', 'feb', 'mar', 'apr', 'mag', 'giu',
        'lug', 'ago', 'set', 'ott', 'nov', 'dic'
      ][m];
}

// ── Add log bottom sheet ──────────────────────────────────────────────────────

class _AddLogSheet extends StatefulWidget {
  final Future<void> Function(String text, String? photoPath) onAdd;
  const _AddLogSheet({required this.onAdd});

  @override
  State<_AddLogSheet> createState() => _AddLogSheetState();
}

class _AddLogSheetState extends State<_AddLogSheet> {
  final _textCtrl = TextEditingController();
  String? _photoPath;
  bool _saving = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) {
        final l = AppL10n.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(l.photoSourceCamera),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l.photoSourceGallery),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    if (source == null) return;
    final file =
        await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (file != null && mounted) setState(() => _photoPath = file.path);
  }

  Future<void> _save() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    await widget.onAdd(text, _photoPath);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: scheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(l.devlogAdd, style: tt.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _textCtrl,
            autofocus: true,
            maxLines: 4,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: l.devlogHint),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          // Anteprima foto selezionata
          if (_photoPath != null) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_photoPath!),
                    width: double.infinity,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => setState(() => _photoPath = null),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              // Bottone foto
              Tooltip(
                message: l.devlogAddPhoto,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _pickPhoto,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: _photoPath != null
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed:
                    _saving || _textCtrl.text.trim().isEmpty ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l.actionAdd),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
