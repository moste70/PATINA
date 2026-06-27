import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../database/app_database.dart';
import '../project_repository.dart';

class CreateProjectState {
  final String name;
  final String? brand;
  final String? scale;
  final String? category;
  final String status;
  final String? notes;
  final String? coverPhotoPath;
  final int currentStep;
  final bool isSaving;

  const CreateProjectState({
    this.name = '',
    this.brand,
    this.scale,
    this.category,
    this.status = 'todo',
    this.notes,
    this.coverPhotoPath,
    this.currentStep = 0,
    this.isSaving = false,
  });

  bool get step1Valid => name.trim().isNotEmpty && category != null;
  bool get hasData => name.isNotEmpty || category != null || brand != null;

  CreateProjectState copyWith({
    String? name,
    Object? brand = _sentinel,
    Object? scale = _sentinel,
    Object? category = _sentinel,
    String? status,
    Object? notes = _sentinel,
    Object? coverPhotoPath = _sentinel,
    int? currentStep,
    bool? isSaving,
  }) {
    return CreateProjectState(
      name: name ?? this.name,
      brand: brand == _sentinel ? this.brand : brand as String?,
      scale: scale == _sentinel ? this.scale : scale as String?,
      category: category == _sentinel ? this.category : category as String?,
      status: status ?? this.status,
      notes: notes == _sentinel ? this.notes : notes as String?,
      coverPhotoPath: coverPhotoPath == _sentinel
          ? this.coverPhotoPath
          : coverPhotoPath as String?,
      currentStep: currentStep ?? this.currentStep,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

const _sentinel = Object();

class CreateProjectNotifier extends StateNotifier<CreateProjectState> {
  final ProjectRepository _repo;

  CreateProjectNotifier(this._repo) : super(const CreateProjectState());

  void setName(String v) => state = state.copyWith(name: v);
  void setBrand(String v) =>
      state = state.copyWith(brand: v.trim().isEmpty ? null : v.trim());
  void setScale(String v) =>
      state = state.copyWith(scale: v.trim().isEmpty ? null : v.trim());
  void setCategory(String v) => state = state.copyWith(category: v);
  void setStatus(String v) => state = state.copyWith(status: v);
  void setNotes(String v) =>
      state = state.copyWith(notes: v.trim().isEmpty ? null : v.trim());
  void setCoverPhoto(String? path) => state = state.copyWith(coverPhotoPath: path);
  void goToStep(int step) => state = state.copyWith(currentStep: step);

  Future<int> save() async {
    state = state.copyWith(isSaving: true);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await _repo.createProject(ProjectsCompanion(
      name: Value(state.name.trim()),
      brand: state.brand != null ? Value(state.brand) : const Value.absent(),
      scale: state.scale != null ? Value(state.scale) : const Value.absent(),
      category:
          state.category != null ? Value(state.category) : const Value.absent(),
      coverPhoto: state.coverPhotoPath != null
          ? Value(state.coverPhotoPath)
          : const Value.absent(),
      status: Value(state.status),
      notes: state.notes != null ? Value(state.notes) : const Value.absent(),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    state = state.copyWith(isSaving: false);
    return id;
  }
}

final createProjectProvider =
    StateNotifierProvider.autoDispose<CreateProjectNotifier, CreateProjectState>(
  (ref) => CreateProjectNotifier(ref.watch(projectRepositoryProvider)),
);
