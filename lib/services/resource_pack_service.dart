import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/project_model.dart';
import 'template_catalog.dart';

class DownloadableResourcePack {
  const DownloadableResourcePack({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.path,
    required this.sha256,
    required this.sizeBytes,
    required this.templateCount,
    this.tags = const <String>[],
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String path;
  final String sha256;
  final int sizeBytes;
  final int templateCount;
  final List<String> tags;

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '~${(sizeBytes / 1024).ceil()} KB';
    }
    return '~${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
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

/// Scene packs are hosted outside the APK. The small catalogue is refreshed
/// online, while the selected vector pack is transferred and verified only
/// when the user previews or downloads it.
class ResourcePackService {
  ResourcePackService._();

  static final Uri _catalogUri = Uri.parse(
    'https://nexauren1.github.io/Animations-2D-/packs/catalog.json',
  );
  static final Uri _packsBaseUri = Uri.parse(
    'https://nexauren1.github.io/Animations-2D-/packs/',
  );
  static const int _maxPackBytes = 5 * 1024 * 1024;

  static Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/animpro_content_packs');
    await directory.create(recursive: true);
    return directory;
  }

  static bool _validId(String value) =>
      RegExp(r'^[a-z0-9-]{1,80}$').hasMatch(value);

  static bool _safePackPath(String value) =>
      value.isNotEmpty &&
      !value.startsWith('/') &&
      !value.contains('..') &&
      RegExp(r'^[a-zA-Z0-9_./-]+\.json$').hasMatch(value);

  /// Parses the manifest without a network request so its contract can be tested.
  static List<DownloadableResourcePack> parseCatalogJson(String source) {
    if (source.length > 256 * 1024) {
      throw const FormatException('O catálogo de recursos é demasiado grande.');
    }
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Formato do catálogo de recursos inválido.');
    }
    final json = Map<String, dynamic>.from(decoded);
    if (json['schemaVersion'] != 1 || json['packs'] is! List) {
      throw const FormatException('Versão do catálogo de recursos não suportada.');
    }
    final rawPacks = json['packs'] as List<dynamic>;
    if (rawPacks.length > 100) {
      throw const FormatException('O catálogo contém demasiados pacotes.');
    }

    final seen = <String>{};
    return rawPacks.map((raw) {
      if (raw is! Map) {
        throw const FormatException('Entrada de pacote inválida.');
      }
      final entry = Map<String, dynamic>.from(raw);
      final id = (entry['id'] ?? '').toString();
      final path = (entry['path'] ?? '').toString();
      final digest = (entry['sha256'] ?? '').toString().toLowerCase();
      final size = (entry['sizeBytes'] as num?)?.toInt() ?? 0;
      final templateCount = (entry['templateCount'] as num?)?.toInt() ?? 0;
      if (!_validId(id) ||
          !seen.add(id) ||
          !_safePackPath(path) ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest) ||
          size < 1 ||
          size > _maxPackBytes ||
          templateCount < 1 ||
          templateCount > 30) {
        throw const FormatException('Um pacote tem metadados inválidos.');
      }
      final title = (entry['title'] ?? '').toString().trim();
      final category = (entry['category'] ?? '').toString().trim();
      if (title.isEmpty || category.isEmpty) {
        throw const FormatException('Um pacote não tem nome ou categoria.');
      }
      final rawTags = entry['tags'];
      final tags = rawTags is List
          ? rawTags.whereType<String>().map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).take(12).toList(growable: false)
          : const <String>[];
      return DownloadableResourcePack(
        id: id,
        title: title,
        description: (entry['description'] ?? '').toString(),
        category: category,
        path: path,
        sha256: digest,
        sizeBytes: size,
        templateCount: templateCount,
        tags: tags,
      );
    }).toList(growable: false);
  }

  /// Refreshes the online manifest, falling back to the last good catalogue
  /// while offline.
  static Future<List<DownloadableResourcePack>> loadAvailable() async {
    final directory = await _directory();
    final cache = File('${directory.path}/catalog-cache.json');
    try {
      final response = await http.get(_catalogUri).timeout(const Duration(seconds: 18));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Catálogo indisponível (HTTP ${response.statusCode}).');
      }
      final source = utf8.decode(response.bodyBytes);
      final packs = parseCatalogJson(source);
      await cache.writeAsString(source, flush: true);
      return packs;
    } catch (_) {
      if (await cache.exists()) {
        try {
          return parseCatalogJson(await cache.readAsString());
        } catch (_) {
          // Ignore a broken cached catalogue and surface the online error.
        }
      }
      rethrow;
    }
  }

  static Future<bool> isDownloaded(String id) async {
    if (!_validId(id)) return false;
    final directory = await _directory();
    return File('${directory.path}/$id.json').exists();
  }

  static Future<_VerifiedPack> _fetchVerified(DownloadableResourcePack pack) async {
    if (!_validId(pack.id) ||
        !_safePackPath(pack.path) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(pack.sha256) ||
        pack.sizeBytes < 1 ||
        pack.sizeBytes > _maxPackBytes) {
      throw const FormatException('Identificador ou endereço de pacote inválido.');
    }

    final uri = _packsBaseUri.resolve(pack.path);
    if (uri.scheme != 'https' ||
        uri.host != _packsBaseUri.host ||
        !uri.path.startsWith(_packsBaseUri.path)) {
      throw const FormatException('O pacote não pertence ao servidor oficial do AnimPro.');
    }

    final response = await http.get(uri).timeout(const Duration(seconds: 45));
    if (response.statusCode != HttpStatus.ok || response.bodyBytes.isEmpty) {
      throw HttpException('O servidor não conseguiu entregar este pacote.');
    }
    final bytes = response.bodyBytes;
    if (bytes.length > _maxPackBytes || bytes.length != pack.sizeBytes) {
      throw const FormatException('O tamanho do pacote não corresponde ao catálogo.');
    }
    if (sha256.convert(bytes).toString() != pack.sha256) {
      throw const FormatException('A verificação de integridade do pacote falhou.');
    }

    final decoded = _parsePack(utf8.decode(bytes));
    if (decoded.id != pack.id) {
      throw const FormatException('O pacote recebido não corresponde ao selecionado.');
    }
    return _VerifiedPack(bytes: bytes, decoded: decoded);
  }

  /// Loads the vector templates for a preview without persisting the pack.
  static Future<List<AnimationTemplate>> preview(DownloadableResourcePack pack) async {
    final verified = await _fetchVerified(pack);
    return verified.decoded.templates;
  }

  static Future<DownloadedResourcePack> download(DownloadableResourcePack pack) async {
    final verified = await _fetchVerified(pack);
    final directory = await _directory();
    final file = File('${directory.path}/${pack.id}.json');
    final temporary = File('${file.path}.download');
    await temporary.writeAsBytes(verified.bytes, flush: true);
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
    return DownloadedResourcePack(
      id: verified.decoded.id,
      title: verified.decoded.title,
      description: verified.decoded.description,
      templates: verified.decoded.templates,
      filePath: file.path,
    );
  }

  static Future<List<DownloadedResourcePack>> loadDownloaded() async {
    final directory = await _directory();
    final files = await directory
        .list()
        .where((entity) =>
            entity is File &&
            entity.path.endsWith('.json') &&
            !entity.path.endsWith('catalog-cache.json'))
        .cast<File>()
        .toList();
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
        // Ignore a damaged local file; users can download it again.
      }
    }
    packs.sort((a, b) => a.title.compareTo(b.title));
    return packs;
  }

  static Future<void> delete(String id) async {
    if (!_validId(id)) return;
    final directory = await _directory();
    final file = File('${directory.path}/$id.json');
    if (await file.exists()) await file.delete();
  }

  static _DecodedPack _parsePack(String source) {
    if (source.length > _maxPackBytes) {
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
      final layerCount = frames.fold<int>(0, (total, frame) => total + frame.layers.length);
      final strokeCount = frames.fold<int>(
        0,
        (total, frame) => total + frame.layers.fold<int>(
          0,
          (layerTotal, layer) => layerTotal + layer.strokes.length,
        ),
      );
      if (layerCount > 500 || strokeCount > 12000) {
        throw const FormatException('O modelo contém demasiados elementos vetoriais.');
      }
      return AnimationTemplate(
        id: templateJson['id'] as String? ?? 'downloaded-template',
        title: templateJson['name'] as String? ?? 'Projeto descarregado',
        description: templateJson['description'] as String? ?? 'Modelo vetorial editável.',
        iconCodePoint: (templateJson['iconCodePoint'] as num?)?.toInt() ?? 0xe3c9,
        tint: (templateJson['tint'] as num?)?.toInt() ?? 0xFF9F8BFF,
        fps: ((templateJson['fps'] as num?)?.toInt() ?? 12).clamp(1, 60).toInt(),
        tag: templateJson['tag'] as String? ?? 'DESCARREGADO',
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

class _VerifiedPack {
  const _VerifiedPack({required this.bytes, required this.decoded});
  final List<int> bytes;
  final _DecodedPack decoded;
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
