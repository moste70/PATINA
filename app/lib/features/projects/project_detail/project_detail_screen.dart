import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../database/app_database.dart';
import '../../../shared/constants/app_constants.dart';
import '../project_repository.dart';

// Provider per il singolo progetto
final projectByIdProvider = StreamProvider.autoDispose.family<Project, int>(
  (ref, id) => ref.watch(projectRepositoryProvider).watchProjectById(id),
);

class ProjectDetailScreen extends ConsumerWidget {
  final int projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectByIdProvider(projectId));

    return projectAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Errore: $e')),
      ),
      data: (project) => _ProjectDetailContent(project: project),
    );
  }
}

class _ProjectDetailContent extends ConsumerStatefulWidget {
  final Project project;
  const _ProjectDetailContent({required this.project});

  @override
  ConsumerState<_ProjectDetailContent> createState() =>
      _ProjectDetailContentState();
}

class _ProjectDetailContentState
    extends ConsumerState<_ProjectDetailContent> {
  late final TextEditingController _notesCtrl;
  bool _editingNotes = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl =
        TextEditingController(text: widget.project.notes ?? '');
  }

  @override
  void didUpdateWidget(_ProjectDetailContent old) {
    super.didUpdateWidget(old);
    if (old.project.notes != widget.project.notes && !_editingNotes) {
      _notesCtrl.text = widget.project.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    final repo = ref.read(projectRepositoryProvider);
    await repo.updateProject(
      widget.project.id,
      ProjectsCompanion(
        notes: Value(_notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim()),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    if (mounted) setState(() => _editingNotes = false);
  }

  Future<void> _updateStatus(String status) async {
    await ref.read(projectRepositoryProvider).updateProject(
      widget.project.id,
      ProjectsCompanion(
        status: Value(status),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> _updateCoverPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Fotocamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galleria'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Annulla'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final file =
          await ImagePicker().pickImage(source: source, imageQuality: 85);
      if (file != null) {
        await ref.read(projectRepositoryProvider).updateProject(
          widget.project.id,
          ProjectsCompanion(
            coverPhoto: Value(file.path),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _deleteProject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina progetto?'),
        content: const Text("L'azione è irreversibile."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Elimina',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref
          .read(projectRepositoryProvider)
          .deleteProject(widget.project.id);
      if (mounted) context.go('/projects');
    }
  }

  void _showStatusSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cambia stato',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 16),
            ...AppConstants.projectStatuses.map((s) => ListTile(
                  title:
                      Text(AppConstants.projectStatusLabels[s] ?? s),
                  trailing: widget.project.status == s
                      ? Icon(Icons.check,
                          color: Theme.of(ctx).colorScheme.primary)
                      : null,
                  onTap: () {
                    _updateStatus(s);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── SliverAppBar collassabile ──
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            stretch: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/projects'),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (v) {
                  if (v == 'status') _showStatusSheet();
                  if (v == 'cover') _updateCoverPhoto();
                  if (v == 'delete') _deleteProject();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'status', child: Text('Cambia stato')),
                  PopupMenuItem(
                      value: 'cover',
                      child: Text('Cambia foto copertina')),
                  PopupMenuDivider(),
                  PopupMenuItem(
                      value: 'delete',
                      child:
                          Text('Elimina', style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              titlePadding:
                  const EdgeInsets.fromLTRB(16, 0, 56, 52),
              title: Text(
                p.name,
                style: tt.titleMedium?.copyWith(
                  color: Colors.white,
                  shadows: [
                    const Shadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0, 1))
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover photo o placeholder
                  p.coverPhoto != null
                      ? Image.file(File(p.coverPhoto!),
                          fit: BoxFit.cover)
                      : Container(
                          color: scheme.surfaceVariant,
                          child: Icon(Icons.view_module_outlined,
                              size: 64,
                              color: scheme.onSurface.withOpacity(0.2)),
                        ),
                  // Gradiente scuro in basso
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.4, 1.0],
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                  // Chip stato in alto a sinistra
                  Positioned(
                    top: 56,
                    left: 16,
                    child: _StatusChip(status: p.status),
                  ),
                ],
              ),
            ),
          ),

          // ── Barra avanzamento + brand/scala ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.brand != null || p.scale != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        [p.brand, p.scale]
                            .whereType<String>()
                            .join(' · '),
                        style: tt.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Galleria Foto ──
          _SectionHeader(title: 'Galleria'),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 88,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Bottone aggiungi
                  _PhotoAddButton(onTap: () {}),
                ],
              ),
            ),
          ),

          // ── Note Progetto ──
          _SectionHeader(title: 'Note'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _editingNotes
                  ? Column(
                      children: [
                        TextField(
                          controller: _notesCtrl,
                          maxLines: null,
                          minLines: 3,
                          maxLength: 500,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText:
                                'Aggiungi note, riferimenti, obiettivi del progetto…',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  setState(() => _editingNotes = false),
                              child: const Text('Annulla'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _saveNotes,
                              child: const Text('Salva'),
                            ),
                          ],
                        ),
                      ],
                    )
                  : GestureDetector(
                      onTap: () =>
                          setState(() => _editingNotes = true),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          p.notes?.isNotEmpty == true
                              ? p.notes!
                              : 'Aggiungi note, riferimenti, obiettivi del progetto…',
                          style: tt.bodyMedium?.copyWith(
                            color: p.notes?.isNotEmpty == true
                                ? null
                                : scheme.onSurface.withOpacity(0.4),
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
            ),
          ),

          // ── Info Progetto ──
          _SectionHeader(title: 'Info'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Text(
                'Creato il ${_formatDate(p.createdAt)}  ·  Ultima modifica ${_timeAgo(p.updatedAt)}',
                style: tt.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.day.toString().padLeft(2, '0')} '
        '${_monthName(d.month)} ${d.year}';
  }

  String _timeAgo(int ts) {
    final diff = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (diff.inDays > 30) return _formatDate(ts);
    if (diff.inDays > 1) return '${diff.inDays} giorni fa';
    if (diff.inDays == 1) return 'ieri';
    if (diff.inHours > 1) return '${diff.inHours} ore fa';
    return 'poco fa';
  }

  String _monthName(int m) => const [
        '',
        'gen',
        'feb',
        'mar',
        'apr',
        'mag',
        'giu',
        'lug',
        'ago',
        'set',
        'ott',
        'nov',
        'dic'
      ][m];
}

// ── Widget ausiliari ──

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'in_progress' => (
          'In corso',
          const Color(0xFFC87A20),
          Colors.white
        ),
      'completed' => (
          'Completato',
          Theme.of(context).colorScheme.primary,
          Colors.black87
        ),
      _ => (
          'Da iniziare',
          Colors.transparent,
          Colors.white
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: status == 'todo'
            ? Border.all(color: Colors.white54)
            : null,
      ),
      child: Text(label,
          style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
        child: Row(
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: scheme.primary)),
            const SizedBox(width: 8),
            Expanded(
                child: Divider(color: scheme.outline, thickness: 1)),
          ],
        ),
      ),
    );
  }
}

class _PhotoAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PhotoAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          border: Border.all(
              color: scheme.outline, width: 1.5,
              style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.add_photo_alternate_outlined,
            color: scheme.onSurface.withOpacity(0.4), size: 28),
      ),
    );
  }
}
