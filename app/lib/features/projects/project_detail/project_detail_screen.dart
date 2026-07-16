import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_helpers.dart';
import '../../../shared/constants/app_constants.dart';
import '../project_repository.dart';
import '../create_project/create_project_wizard.dart';
import 'project_palette_sliver.dart';
import 'project_devlog_sliver.dart';
import 'pin_viewer_screen.dart';

// Provider per il singolo progetto
final projectByIdProvider = StreamProvider.autoDispose.family<Project, int>(
  (ref, id) => ref.watch(projectRepositoryProvider).watchProjectById(id),
);

class ProjectDetailScreen extends ConsumerWidget {
  final int projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final projectAsync = ref.watch(projectByIdProvider(projectId));

    return projectAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.errorGeneric(e.toString()))),
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
    final l = AppL10n.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) {
        final ll = AppL10n.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(ll.photoSourceCamera),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(ll.photoSourceGallery),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: Text(ll.actionCancel),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
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

  Future<void> _removeCoverPhoto() async {
    await ref.read(projectRepositoryProvider).updateProject(
      widget.project.id,
      ProjectsCompanion(
        coverPhoto: const Value(null),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  void _editProject() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CreateProjectWizard(project: widget.project),
      ),
    );
  }

  Future<void> _deleteProject() async {
    final l = AppL10n.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ll = AppL10n.of(ctx);
        return AlertDialog(
          title: Text(ll.projectDeleteTitle),
          content: Text(ll.projectDeleteBody),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ll.actionCancel)),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ll.actionDelete,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
          ],
        );
      },
    );
    if (confirm == true && mounted) {
      await ref
          .read(projectRepositoryProvider)
          .deleteProject(widget.project.id);
      if (mounted) context.go('/projects');
    }
  }

  void _showStatusSheet() {
    final l = AppL10n.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final ll = AppL10n.of(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ll.statusChangeTitle,
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 16),
              ...AppConstants.projectStatuses.map((s) => ListTile(
                    title: Text(ll.projectStatusLabel(s)),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
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
                  if (v == 'edit') _editProject();
                  if (v == 'status') _showStatusSheet();
                  if (v == 'cover') _updateCoverPhoto();
                  if (v == 'remove_cover') _removeCoverPhoto();
                  if (v == 'delete') _deleteProject();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'edit', child: Text(l.projectMenuEdit)),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                      value: 'status', child: Text(l.statusChangeTitle)),
                  PopupMenuItem(
                      value: 'cover',
                      child: Text(l.coverPhotoChange)),
                  if (p.coverPhoto != null)
                    PopupMenuItem(
                        value: 'remove_cover',
                        child: Text(l.coverPhotoRemove)),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                      value: 'delete',
                      child: Builder(
                        builder: (ctx) => Text(
                          AppL10n.of(ctx).actionDelete,
                          style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                        ),
                      )),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 56, 16),
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
                          color: scheme.surfaceContainerHigh,
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
                        stops: [0.35, 1.0],
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                  // Overlay info: status chip + brand/scala sopra il titolo
                  Positioned(
                    bottom: 44,
                    left: 16,
                    right: 16,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _StatusChip(
                          status: p.status,
                          onTap: _showStatusSheet,
                        ),
                        if (p.brand != null || p.scale != null) ...[
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              [p.brand, p.scale]
                                  .whereType<String>()
                                  .join(' · '),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                shadows: [
                                  Shadow(
                                      color: Colors.black54,
                                      blurRadius: 6)
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Galleria Foto ──
          _SectionHeader(title: l.sectionGallery),
          _GallerySliver(projectId: widget.project.id),

          // ── Note Progetto ──
          _SectionHeader(title: l.sectionNotes),
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
                          decoration: InputDecoration(
                            hintText: l.projectNotesHint,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  setState(() => _editingNotes = false),
                              child: Text(l.actionCancel),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _saveNotes,
                              child: Text(l.actionSave),
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
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          p.notes?.isNotEmpty == true
                              ? p.notes!
                              : l.projectNotesHint,
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

          // ── Palette del kit ──
          ProjectPaletteSliver(projectId: widget.project.id),

          // ── Devlog ──
          ProjectDevlogSliver(projectId: widget.project.id),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              child: Text(
                'Creato il ${_formatDate(p.createdAt)}  ·  Modificato ${_timeAgo(p.updatedAt)}',
                style: tt.bodySmall?.copyWith(
                  color: scheme.onSurface.withOpacity(0.35),
                ),
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
  final VoidCallback? onTap;
  const _StatusChip({required this.status, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final (bg, fg) = switch (status) {
      'in_progress' => (
          const Color(0xFFC87A20),
          Colors.white
        ),
      'completed' => (
          Theme.of(context).colorScheme.primary,
          Colors.black87
        ),
      'paused' => (
          Colors.blueGrey,
          Colors.white
        ),
      _ => (
          Colors.transparent,
          Colors.white
        ),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: status == 'todo'
              ? Border.all(color: Colors.white54)
              : Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.projectStatusLabel(status),
                style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.expand_more, color: fg, size: 14),
            ],
          ],
        ),
      ),
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

final _projectPhotosProvider =
    StreamProvider.autoDispose.family<List<ProjectPhoto>, int>(
  (ref, projectId) =>
      ref.watch(projectRepositoryProvider).watchProjectPhotos(projectId),
);

class _GallerySliver extends ConsumerWidget {
  final int projectId;
  const _GallerySliver({required this.projectId});

  Future<void> _addPhoto(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) {
        final ll = AppL10n.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(ll.photoSourceCamera),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(ll.photoSourceGallery),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: Text(ll.actionCancel),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
    if (source == null) return;
    try {
      final file = await ImagePicker().pickImage(source: source, imageQuality: 85);
      if (file != null) {
        await ref.read(projectRepositoryProvider).addProjectPhoto(projectId, file.path);
      }
    } catch (_) {}
  }

  Future<void> _deletePhoto(BuildContext context, WidgetRef ref, int photoId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ll = AppL10n.of(ctx);
        return AlertDialog(
          title: Text(ll.photoDeleteTitle),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ll.actionCancel)),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ll.actionDelete,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await ref.read(projectRepositoryProvider).deleteProjectPhoto(photoId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(_projectPhotosProvider(projectId));
    final photos = photosAsync.valueOrNull ?? [];

    final l = AppL10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (photos.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: InkWell(
            onTap: () => _addPhoto(context, ref),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 88,
              decoration: BoxDecoration(
                border: Border.all(
                  color: scheme.outline.withOpacity(0.4),
                  width: 1.5,
                  // ignore: deprecated_member_use
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 28, color: scheme.onSurfaceVariant.withOpacity(0.5)),
                  const SizedBox(width: 10),
                  Text(
                    l.photoGalleryEmptyHint,
                    style: tt.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 88,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _PhotoAddButton(onTap: () => _addPhoto(context, ref)),
            ...photos.map((photo) => _PhotoThumbnail(
              photo: photo,
              onDelete: () => _deletePhoto(context, ref, photo.id),
            )),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final ProjectPhoto photo;
  final VoidCallback onDelete;
  const _PhotoThumbnail({required this.photo, required this.onDelete});

  void _openFullscreen(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PinViewerScreen(photo: photo, onDelete: onDelete),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          image: DecorationImage(
            image: FileImage(File(photo.path)),
            fit: BoxFit.cover,
          ),
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
