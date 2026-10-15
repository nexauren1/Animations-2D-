import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/project_model.dart';
import 'template_catalog.dart';

class DownloadableResourcePack {
  const DownloadableResourcePack({
    required this.id,
    required this.title,
    required this.description,
    required this.sizeLabel,
    required this.fileName,
    required this.url,
  });

  final String id;
  final String title;
  final String description;
  final String sizeLabel;
  final String fileName;
  final String url;
}

class DownloadedResourcePack {
  const DownloadedResourcePack({
    required this.id,
    required this.title,
    required this.description,
    required this.templates,
    required this.filePath,
  });

  final String id;
  final String title;
  final String description;
  final List<AnimationTemplate> templates;
  final String filePath;
}

/// Packs contain small JSON vector projects. Nothing downloads until the user
/// taps Download; packs are stored in app support storage rather than bundled
/// into the initial APK.
class ResourcePackService {
  ResourcePackService._();

  static const List<DownloadableResourcePack> available = <DownloadableResourcePack>[
    DownloadableResourcePack(
      id: 'space-pack',
      title: 'Espaço e movimento',
      description: 'Planeta com anéis e estrela cadente, prontos para editar.',
      sizeLabel: '~12 KB',
      fileName: 'space-pack.json',
      url: 'https://raw.githubusercontent.com/nexauren1/Animations-2D-/main/content/packs/space-pack.json',
    ),
    DownloadableResourcePack(
      id: 'character-pack',
      title: 'Personagens expressivos',
      description: 'Cara animada com olhos, boca e quatro poses.',
      sizeLabel: '~4 KB',
      fileName: 'character-pack.json',
      url: 'https://raw.githubusercontent.com/nexauren1/Animations-2D-/main/content/packs/character-pack.json',
    ),
  ];

  static Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/animpro_content_packs');
    await directory.create(recursive: true);
    return directory;
  }

  static Future<bool> isDownloaded(String id) async {
    final directory = await _directory();
    return File('${directory.path}/$id.json').exists();
  }

  static Future<DownloadedResourcePack> download(DownloadableResourcePack pack) async {
    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(pack.id)) {
      throw const FormatException('Identificador de pacote inválido.');
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(pack.url)).timeout(const Duration(seconds: 20));
      request.headers.set(HttpHeaders.userAgentHeader, 'AnimPro-Android');
      final response = await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('O servidor respondeu com HTTP ${response.statusCode}.');
      }

      final bytes = await response.fold<List<int>>(<int>[], (collected, chunk) {
        if (collected.length + chunk.length > 5 * 1024 * 1024) {
          throw const FormatException('Este pacote excede o limite de 5 MB.');
        }
        collected.addAll(chunk);
        return collected;
      }).timeout(const Duration(seconds: 45));

      final decoded = _parsePack(utf8.decode(bytes));
      if (decoded.id != pack.id) {
        throw const FormatException('O pacote recebido não corresponde ao selecionado.');
      }

      final directory = await _directory();
      final file = File('${directory.path}/${pack.id}.json');
      await file.writeAsBytes(bytes, flush: true);
      return DownloadedResourcePack(
        id: decoded.id,
        title: decoded.title,
        description: decoded.description,
        templates: decoded.templates,
        filePath: file.path,
      );
    } finally {
      client.close(force: true);
    }
  }

  static Future<List<DownloadedResourcePack>> loadDownloaded() async {
    final directory = await _directory();
    final files = await directory.list().where((entity) => entity is File && entity.path.endsWith('.json')).cast<File>().toList();
    final packs = <DownloadedResourcePack>[];
    for (final file in files) {
      try {
        final result = _parsePack(await file.readAsString());
        packs.add(DownloadedResourcePack(
          id: result.id,
          title: result.title,
          description: result.description,
          templates: result.templates,
          filePath: file.path,
        ));
      } catch (_) {
        // Ignore a partially written or outdated local pack; users can download it again.
      }
    }
    packs.sort((a, b) => a.title.compareTo(b.title));
    return packs;
  }

  static Future<void> delete(String id) async {
    final directory = await _directory();
    final file = File('${directory.path}/$id.json');
    if (await file.exists()) await file.delete();
  }

  static _DecodedPack _parsePack(String source) {
    if (source.length > 5 * 1024 * 1024) {
      throw const FormatException('Pacote demasiado grande.');
    }
    final decoded = jsonDecode(source);
    if (decoded is! Map) throw const FormatException('Formato de pacote inválido.');
    final json = Map<String, dynamic>.from(decoded);
    if (json['schemaVersion'] != 1 ||
        json['id'] is! String ||
        json['name'] is! String ||
        json['templates'] is! List) {
      throw const FormatException('Versão ou estrutura do pacote não suportada.');
    }

    final rawTemplates = json['templates'] as List<dynamic>;
    if (rawTemplates.isEmpty || rawTemplates.length > 30) {
      throw const FormatException('O pacote não contém uma quantidade válida de modelos.');
    }
    final templates = rawTemplates.map((raw) {
      if (raw is! Map) throw const FormatException('Modelo inválido no pacote.');
      final templateJson = Map<String, dynamic>.from(raw);
      final rawFrames = templateJson['frames'];
      if (rawFrames is! List || rawFrames.isEmpty || rawFrames.length > 500) {
        throw const FormatException('Um modelo tem uma quantidade inválida de frames.');
      }
      final frames = rawFrames.map((rawFrame) {
        if (rawFrame is! Map) throw const FormatException('Frame inválido no pacote.');
        return FrameModel.fromJson(Map<String, dynamic>.from(rawFrame));
      }).toList(growable: false);

      return AnimationTemplate(
        id: templateJson['id'] as String? ?? 'downloaded-template',
        title: templateJson['name'] as String? ?? 'Projeto descarregado',
        description: templateJson['description'] as String? ?? 'Modelo vetorial editável.',
        iconCodePoint: (templateJson['iconCodePoint'] as num?)?.toInt() ?? 0xe3c9,
        tint: (templateJson['tint'] as num?)?.toInt() ?? 0xFF9F8BFF,
        fps: ((templateJson['fps'] as num?)?.toInt() ?? 12).clamp(1, 60).toInt(),
        tag: 'DESCARREGADO',
        frames: () => frames,
      );
    }).toList(growable: false);

    return _DecodedPack(
      id: json['id'] as String,
      title: json['name'] as String,
      description: json['description'] as String? ?? '',
      templates: templates,
    );
  }
}

class _DecodedPack {
  const _DecodedPack({
    required this.id,
    required this.title,
    required this.description,
    required this.templates,
  });

  final String id;
  final String title;
  final String description;
  final List<AnimationTemplate> templates;
}
