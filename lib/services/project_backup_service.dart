import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/project_model.dart';

/// Portable, offline backup/import format for AnimPro projects.
class ProjectBackupService {
  ProjectBackupService._();

  static Future<void> shareProject(ProjectModel project) async {
    final payload = <String, dynamic>{
      'format': 'animpro-project',
      'schemaVersion': 1,
      'name': project.name,
      'fps': project.fps,
      'createdAt': project.createdAt.toIso8601String(),
      'updatedAt': project.updatedAt.toIso8601String(),
      'frames': project.frames.map((frame) => frame.toJson()).toList(),
    };
    final bytes = utf8.encode(jsonEncode(payload));
    final archive = Archive()
      ..addFile(ArchiveFile('project.json', bytes.length, bytes));
    final zipped = ZipEncoder().encode(archive);
    if (zipped == null || zipped.isEmpty) {
      throw const FormatException('Não foi possível criar o backup.');
    }

    final directory = await getTemporaryDirectory();
    final safeName = project.name
        .replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    final fileName = safeName.isEmpty ? 'animpro-project' : safeName;
    final file = File('${directory.path}/${fileName}.animpro');
    await file.writeAsBytes(zipped, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path)],
        text: 'Backup do projeto ${project.name} criado com AnimPro.',
      ),
    );
  }

  static Future<ImportedProject> pickAndReadProject() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>['animpro'],
    );
    if (file == null) {
      throw const BackupCancelledException();
    }
    final byteLength = file.lengthSync();
    if (byteLength > 30 * 1024 * 1024) {
      throw const FormatException('O backup excede o limite de 30 MB ou não pode ser lido.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('Não foi possível ler o ficheiro escolhido.');
    }

    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    ArchiveFile? projectFile;
    for (final entry in archive.files) {
      if (entry.name == 'project.json' && entry.isFile) {
        projectFile = entry;
        break;
      }
    }
    if (projectFile == null) {
      throw const FormatException('O ficheiro não contém um projeto AnimPro válido.');
    }

    final content = utf8.decode(projectFile.content as List<int>);
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'animpro-project' ||
        decoded['schemaVersion'] != 1) {
      throw const FormatException('Formato de backup não suportado.');
    }

    final rawFrames = decoded['frames'];
    if (rawFrames is! List || rawFrames.isEmpty || rawFrames.length > 20000) {
      throw const FormatException('O backup não tem uma lista de frames válida.');
    }
    final frames = rawFrames
        .map((raw) {
          if (raw is! Map) {
            throw const FormatException('Um dos frames é inválido.');
          }
          return FrameModel.fromJson(Map<String, dynamic>.from(raw));
        })
        .toList(growable: false);

    final name = (decoded['name'] as String? ?? 'Projeto importado').trim();
    final fpsValue = decoded['fps'];
    final fps = fpsValue is num ? fpsValue.toInt().clamp(1, 60).toInt() : 12;
    return ImportedProject(
      name: name.isEmpty ? 'Projeto importado' : name,
      fps: fps,
      frames: frames,
    );
  }
}

class ImportedProject {
  const ImportedProject({
    required this.name,
    required this.fps,
    required this.frames,
  });

  final String name;
  final int fps;
  final List<FrameModel> frames;
}

class BackupCancelledException implements Exception {
  const BackupCancelledException();
}
