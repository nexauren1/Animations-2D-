import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class AudioCatalogItem {
  const AudioCatalogItem({
    required this.id,
    required this.title,
    required this.category,
    required this.file,
    required this.isPro,
    required this.credit,
    required this.license,
  });

  final String id;
  final String title;
  final String category;
  final String file;
  final bool isPro;
  final String credit;
  final String license;

  String get downloadUrl =>
      'https://raw.githubusercontent.com/nexauren1/Animations-2D-/main/content/audio/$file';

  factory AudioCatalogItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final category = json['category'];
    final file = json['file'];
    if (id is! String ||
        !RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(id) ||
        title is! String ||
        title.trim().isEmpty ||
        category is! String ||
        file is! String ||
        file.startsWith('/') ||
        file.contains('..') ||
        !RegExp(r'^[a-zA-Z0-9_/-]+\.(mp3|wav|ogg|m4a|aac)$', caseSensitive: false).hasMatch(file)) {
      throw const FormatException('Entrada inválida no catálogo de áudio.');
    }
    final pro = json['pro'];
    if (pro != null && pro is! bool) {
      throw const FormatException('A opção Pro do áudio tem um formato inválido.');
    }
    return AudioCatalogItem(
      id: id,
      title: title.trim(),
      category: category.trim().isEmpty ? 'Efeitos sonoros' : category.trim(),
      file: file,
      isPro: pro == true,
      credit: json['credit'] as String? ?? '',
      license: json['license'] as String? ?? '',
    );
  }
}

class AudioTimelineClip {
  const AudioTimelineClip({
    required this.instanceId,
    required this.catalogId,
    required this.title,
    required this.localPath,
    required this.startFrame,
    required this.volume,
    required this.isPro,
    this.credit = '',
    this.license = '',
  });

  final String instanceId;
  final String catalogId;
  final String title;
  final String localPath;
  final int startFrame;
  final double volume;
  final bool isPro;
  final String credit;
  final String license;

  AudioTimelineClip copyWith({int? startFrame, double? volume}) => AudioTimelineClip(
        instanceId: instanceId,
        catalogId: catalogId,
        title: title,
        localPath: localPath,
        startFrame: startFrame ?? this.startFrame,
        volume: volume ?? this.volume,
        isPro: isPro,
        credit: credit,
        license: license,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'instanceId': instanceId,
        'catalogId': catalogId,
        'title': title,
        'localPath': localPath,
        'startFrame': startFrame,
        'volume': volume,
        'isPro': isPro,
        'credit': credit,
        'license': license,
      };

  factory AudioTimelineClip.fromJson(Map<String, dynamic> json) {
    final path = json['localPath'];
    final start = json['startFrame'];
    final volume = json['volume'];
    if (path is! String || path.isEmpty || start is! num) {
      throw const FormatException('Clip de áudio inválido.');
    }
    return AudioTimelineClip(
      instanceId: json['instanceId'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      catalogId: json['catalogId'] as String? ?? 'local',
      title: json['title'] as String? ?? 'Áudio',
      localPath: path,
      startFrame: start.toInt().clamp(0, 20000),
      volume: (volume is num ? volume.toDouble() : 1).clamp(0, 1).toDouble(),
      isPro: json['isPro'] == true,
      credit: json['credit'] as String? ?? '',
      license: json['license'] as String? ?? '',
    );
  }
}

class AudioLibraryService {
  AudioLibraryService._();

  static const String catalogUrl =
      'https://raw.githubusercontent.com/nexauren1/Animations-2D-/main/content/audio/catalog.json';

  static Future<Directory> _root() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/animpro_audio_library');
    await root.create(recursive: true);
    return root;
  }

  static Future<File> _timelineFile(String projectUid) async {
    final safeUid = projectUid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final root = await _root();
    final timeline = Directory('${root.path}/timelines');
    await timeline.create(recursive: true);
    return File('${timeline.path}/${safeUid.isEmpty ? 'project' : safeUid}.json');
  }

  static Future<List<AudioCatalogItem>> fetchCatalog() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.getUrl(Uri.parse(catalogUrl)).timeout(const Duration(seconds: 15));
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('Catálogo de áudio indisponível (HTTP ${response.statusCode}).');
      }
      final bytes = await response.fold<List<int>>(<int>[], (all, chunk) {
        if (all.length + chunk.length > 512 * 1024) {
          throw const FormatException('O catálogo de áudio excede o tamanho permitido.');
        }
        all.addAll(chunk);
        return all;
      });
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map ||
          decoded['schemaVersion'] != 1 ||
          decoded['items'] is! List) {
        throw const FormatException('Formato do catálogo de áudio não suportado.');
      }
      final rawItems = decoded['items'] as List;
      if (rawItems.length > 300) {
        throw const FormatException('O catálogo contém demasiados sons.');
      }
      return rawItems
          .map((raw) {
            if (raw is! Map) throw const FormatException('Item de áudio inválido.');
            return AudioCatalogItem.fromJson(Map<String, dynamic>.from(raw));
          })
          .toList(growable: false);
    } finally {
      client.close(force: true);
    }
  }

  static Future<String?> importLocalFile() async {
    final selected = await FilePicker.pickFile(type: FileType.audio);
    if (selected == null) return null;
    final sourcePath = selected.path;
    if (sourcePath == null || sourcePath.isEmpty) {
      throw const FormatException('Não foi possível ler o ficheiro selecionado.');
    }
    final ext = selected.name.contains('.')
        ? selected.name.split('.').last.toLowerCase()
        : '';
    if (!const <String>{'mp3', 'wav', 'ogg', 'm4a', 'aac'}.contains(ext)) {
      throw const FormatException('Usa um ficheiro MP3, WAV, OGG, M4A ou AAC.');
    }
    final source = File(sourcePath);
    if (!await source.exists()) throw const FormatException('O ficheiro de áudio já não está disponível.');
    final length = await source.length();
    if (length <= 0 || length > 50 * 1024 * 1024) {
      throw const FormatException('O áudio está vazio ou excede o limite de 50 MB.');
    }
    final root = await _root();
    final destination = File('${root.path}/local_${DateTime.now().microsecondsSinceEpoch}.$ext');
    await source.copy(destination.path);
    return destination.path;
  }

  static Future<String?> existingDownloadPath(AudioCatalogItem item) async {
    final root = await _root();
    final safeId = item.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final ext = item.file.split('.').last.toLowerCase();
    final file = File('${root.path}/${safeId}.$ext');
    return await file.exists() && await file.length() > 0 ? file.path : null;
  }

  static Future<String> downloadItem(AudioCatalogItem item) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final uri = Uri.parse(item.downloadUrl);
      if (uri.host != 'raw.githubusercontent.com' || uri.scheme != 'https') {
        throw const FormatException('O endereço de áudio não é seguro.');
      }
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.userAgentHeader, 'AnimPro-Android');
      final response = await request.close().timeout(const Duration(seconds: 25));
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('O som não está disponível (HTTP ${response.statusCode}).');
      }
      final bytes = await response.fold<List<int>>(<int>[], (all, chunk) {
        if (all.length + chunk.length > 50 * 1024 * 1024) {
          throw const FormatException('O áudio excede o limite de 50 MB.');
        }
        all.addAll(chunk);
        return all;
      }).timeout(const Duration(seconds: 60));
      if (bytes.isEmpty) throw const FormatException('O ficheiro de áudio está vazio.');
      final root = await _root();
      final safeId = item.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final ext = item.file.split('.').last.toLowerCase();
      final destination = File('${root.path}/${safeId}.$ext');
      await destination.writeAsBytes(bytes, flush: true);
      return destination.path;
    } finally {
      client.close(force: true);
    }
  }

  static Future<List<AudioTimelineClip>> loadClips(String projectUid) async {
    final file = await _timelineFile(projectUid);
    if (!await file.exists()) return <AudioTimelineClip>[];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List || decoded.length > 1000) return <AudioTimelineClip>[];
      return decoded
          .whereType<Map>()
          .map((raw) => AudioTimelineClip.fromJson(Map<String, dynamic>.from(raw)))
          .where((clip) => File(clip.localPath).existsSync())
          .toList(growable: true);
    } catch (_) {
      return <AudioTimelineClip>[];
    }
  }

  static Future<void> saveClips(
    String projectUid,
    List<AudioTimelineClip> clips,
  ) async {
    if (clips.length > 1000) throw const FormatException('Limite de clips de áudio excedido.');
    final file = await _timelineFile(projectUid);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(clips.map((clip) => clip.toJson()).toList()),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }
}
