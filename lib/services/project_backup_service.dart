import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/project_model.dart';
import 'audio_library_service.dart';

/// Portable, offline .animpro backup containing editable frames and project audio.
class ProjectBackupService {
  ProjectBackupService._();

  static const int _maxBackupBytes = 30 * 1024 * 1024;
  static const int _maxAudioBytes = 26 * 1024 * 1024;

  static Future<void> shareProject(ProjectModel project) async {
    final archive = Archive();
    final clips = await AudioLibraryService.loadClips(project.uid);
    final audioManifest = <Map<String, dynamic>>[];
    final audioEntries = <String, List<int>>{};
    var audioBytesTotal = 0;

    for (var index = 0; index < clips.length; index++) {
      final clip = clips[index];
      final source = File(clip.localPath);
      if (!await source.exists()) {
        throw const FormatException(
          'Um dos áudios deste projeto não está disponível. Abre a biblioteca de áudio e remove ou importa novamente o clip em falta.',
        );
      }

      final extension = source.path.split('.').last.toLowerCase();
      if (!_isSupportedAudioExtension(extension)) {
        throw const FormatException('O backup contém um formato de áudio não suportado.');
      }

      final audioBytes = await source.readAsBytes();
      audioBytesTotal += audioBytes.length;
      if (audioBytes.isEmpty || audioBytesTotal > _maxAudioBytes) {
        throw const FormatException(
          'Os áudios deste projeto excedem o limite de 26 MB ou contêm um ficheiro vazio. Remove clips não utilizados ou cria um backup mais pequeno.',
        );
      }

      final safeInstance = clip.instanceId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final archivePath = 'audio/clip_${index}_${safeInstance}.$extension';
      audioEntries[archivePath] = audioBytes;
      audioManifest.add(<String, dynamic>{
        ...clip.toJson(),
        'localPath': archivePath,
      });
    }

    final payload = <String, dynamic>{
      'format': 'animpro-project',
      'schemaVersion': 1,
      'name': project.name,
      'fps': project.fps,
      'createdAt': project.createdAt.toIso8601String(),
      'updatedAt': project.updatedAt.toIso8601String(),
      'frames': project.frames.map((frame) => frame.toJson()).toList(),
      'audioClips': audioManifest,
    };
    final projectBytes = utf8.encode(jsonEncode(payload));

    archive.addFile(ArchiveFile('project.json', projectBytes.length, projectBytes));
    for (final entry in audioEntries.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }

    final zipped = ZipEncoder().encode(archive);
    if (zipped.isEmpty || zipped.length > _maxBackupBytes) {
      throw const FormatException(
        'O backup excede o limite de 30 MB. Divide o projeto ou reduz o tamanho dos áudios.',
      );
    }

    final directory = await getTemporaryDirectory();
    final safeName = project.name
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    final fileName = safeName.isEmpty ? 'animpro-project' : safeName;
    final file = File('${directory.path}/${fileName}.animpro');
    await file.writeAsBytes(zipped, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path)],
        text: 'Backup do projeto ${project.name} criado com AnimPro. Inclui frames e clips de áudio associados.',
      ),
    );
  }

  static Future<ImportedProject> pickAndReadProject() async {
    final selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>['animpro'],
    );
    if (selected == null) throw const BackupCancelledException();

    final byteLength = selected.lengthSync() ?? await selected.length();
    if (byteLength == null || byteLength > _maxBackupBytes) {
      throw const FormatException('O backup excede o limite de 30 MB ou não pode ser lido.');
    }
    final bytes = await selected.readAsBytes();
    if (bytes.isEmpty) throw const FormatException('Não foi possível ler o ficheiro escolhido.');

    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final archiveFiles = <String, ArchiveFile>{};
    for (final entry in archive.files) {
      if (entry.isFile) archiveFiles[entry.name] = entry;
    }
    final projectFile = archiveFiles['project.json'];
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

    final restoredAudioClips = <AudioTimelineClip>[];
    final audioAssets = <String, List<int>>{};
    var restoredAudioBytes = 0;
    final rawAudio = decoded['audioClips'];
    if (rawAudio != null) {
      if (rawAudio is! List || rawAudio.length > 1000) {
        throw const FormatException('A lista de clips de áudio do backup é inválida.');
      }
      for (final raw in rawAudio) {
        if (raw is! Map) {
          throw const FormatException('Um clip de áudio do backup é inválido.');
        }
        final clip = AudioTimelineClip.fromJson(Map<String, dynamic>.from(raw));
        final archivePath = clip.localPath;
        if (!RegExp(
          r'^audio/[A-Za-z0-9_-]+\.(mp3|wav|ogg|m4a|aac)$',
          caseSensitive: false,
        ).hasMatch(archivePath)) {
          throw const FormatException('O caminho de áudio do backup não é válido.');
        }

        final entry = archiveFiles[archivePath];
        if (entry == null) {
          throw const FormatException('O backup referencia um áudio que não existe no arquivo.');
        }
        final fileBytes = entry.content as List<int>;
        restoredAudioBytes += fileBytes.length;
        if (fileBytes.isEmpty ||
            fileBytes.length > 50 * 1024 * 1024 ||
            restoredAudioBytes > _maxAudioBytes) {
          throw const FormatException('Um dos áudios do backup é inválido ou o total excede 26 MB.');
        }

        restoredAudioClips.add(clip);
        audioAssets[archivePath] = List<int>.from(fileBytes);
      }
    }

    final rawFrames = decoded['frames'];
    if (rawFrames is! List || rawFrames.isEmpty || rawFrames.length > 20000) {
      throw const FormatException('O backup não tem uma lista de frames válida.');
    }
    final frames = rawFrames
        .map((raw) {
          if (raw is! Map) throw const FormatException('Um dos frames é inválido.');
          return FrameModel.fromJson(Map<String, dynamic>.from(raw));
        })
        .toList(growable: false);

    final rawName = decoded['name'];
    final name = (rawName is String ? rawName : 'Projeto importado').trim();
    final rawFps = decoded['fps'];
    final fps = rawFps is num ? rawFps.toInt().clamp(1, 60).toInt() : 12;
    return ImportedProject(
      name: name.isEmpty ? 'Projeto importado' : name,
      fps: fps,
      frames: frames,
      audioClips: restoredAudioClips,
      audioAssets: audioAssets,
    );
  }

  static bool _isSupportedAudioExtension(String extension) =>
      const <String>{'mp3', 'wav', 'ogg', 'm4a', 'aac'}.contains(extension);
}

class ImportedProject {
  const ImportedProject({
    required this.name,
    required this.fps,
    required this.frames,
    this.audioClips = const <AudioTimelineClip>[],
    this.audioAssets = const <String, List<int>>{},
  });

  final String name;
  final int fps;
  final List<FrameModel> frames;

  /// Clips refer to their archive path until AudioLibraryService restores them.
  final List<AudioTimelineClip> audioClips;

  /// Raw bytes for each clip, keyed by the archive path in [audioClips].
  final Map<String, List<int>> audioAssets;
}

class BackupCancelledException implements Exception {
  const BackupCancelledException();
}
