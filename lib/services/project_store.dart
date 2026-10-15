import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';

import '../models/project_model.dart';

/// Centraliza as operações de persistência local dos projetos.
class ProjectStore extends ChangeNotifier {
  ProjectStore(this._isar);

  final Isar _isar;
  List<ProjectModel> _projects = <ProjectModel>[];

  List<ProjectModel> get projects => List<ProjectModel>.unmodifiable(_projects);

  Future<void> load() async {
    _projects = await _isar.projectModels.where().findAll();
    _projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
  }

  Future<ProjectModel> createProject(String name) async {
    final project = ProjectModel.create(name.trim().isEmpty ? 'Projeto sem título' : name.trim());
    await _isar.writeTxn(() async {
      await _isar.projectModels.put(project);
    });
    await load();
    return project;
  }

  Future<void> saveProject(
    ProjectModel project, {
    List<FrameModel>? frames,
  }) async {
    if (frames != null) project.frames = frames;
    project.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.projectModels.put(project);
    });
    await load();
  }

  Future<ProjectModel> duplicateProject(ProjectModel source) async {
    final now = DateTime.now();
    final duplicate = ProjectModel()
      ..uid = now.microsecondsSinceEpoch.toString()
      ..name = '${source.name} (cópia)'
      ..createdAt = now
      ..updatedAt = now
      ..fps = source.fps
      ..thumbnailPath = source.thumbnailPath
      ..frames = source.frames.map((frame) => frame.copy()).toList();

    await _isar.writeTxn(() async {
      await _isar.projectModels.put(duplicate);
    });
    await load();
    return duplicate;
  }

  Future<void> renameProject(ProjectModel project, String name) async {
    if (name.trim().isEmpty) return;
    project.name = name.trim();
    await saveProject(project);
  }

  Future<void> deleteProject(ProjectModel project) async {
    await _isar.writeTxn(() async {
      await _isar.projectModels.delete(project.id);
    });
    await load();
  }
}
