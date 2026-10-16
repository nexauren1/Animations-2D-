import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart' hide Text;
import '../services/app_locale.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../services/pro_access_service.dart';
import 'upgrade_screen.dart';

class AudioLibrarySelection {
  const AudioLibrarySelection({
    required this.id,
    required this.name,
    required this.path,
    required this.isPro,
  });

  final String id;
  final String name;
  final String path;
  final bool isPro;
}

class _AudioLibraryItem {
  const _AudioLibraryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.file,
    required this.preview,
    required this.isPro,
    required this.license,
    required this.sourceUrl,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final String file;
  final String preview;
  final bool isPro;
  final String license;
  final String sourceUrl;

  factory _AudioLibraryItem.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString();
    final file = (json['file'] ?? '').toString();
    final preview = (json['preview'] ?? file).toString();
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id) ||
        !_safeRelativeAudioPath(file) ||
        !_safeRelativeAudioPath(preview)) {
      throw const FormatException('Invalid audio library entry');
    }
    return _AudioLibraryItem(
      id: id,
      name: (json['name'] ?? id).toString(),
      category: (json['category'] ?? 'Efeitos').toString(),
      description: (json['description'] ?? '').toString(),
      file: file,
      preview: preview,
      isPro: json['pro'] == true,
      license: (json['license'] ?? '').toString(),
      sourceUrl: (json['sourceUrl'] ?? '').toString(),
    );
  }

  static bool _safeRelativeAudioPath(String path) =>
      path.isNotEmpty &&
      !path.startsWith('/') &&
      !path.contains('..') &&
      RegExp(r'^[a-zA-Z0-9_./-]+\.(mp3|wav|ogg|m4a)$', caseSensitive: false)
          .hasMatch(path);
}

class AudioLibraryScreen extends StatefulWidget {
  const AudioLibraryScreen({super.key});

  @override
  State<AudioLibraryScreen> createState() => _AudioLibraryScreenState();
}

class _AudioLibraryScreenState extends State<AudioLibraryScreen> {
  static final Uri _catalogUri = Uri.parse(
    'https://nexauren1.github.io/Animations-2D/audio/catalog.json',
  );
  static final Uri _audioBaseUri = Uri.parse(
    'https://nexauren1.github.io/Animations-2D/audio/',
  );
  final AudioPlayer _player = AudioPlayer();
  List<_AudioLibraryItem> _items = const [];
  String? _previewingId;
  String _category = 'Todos';
  String _search = '';
  bool _loading = true;
  bool _playing = false;
  String? _error;
  final Set<String> _downloading = <String>{};

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playing = state == PlayerState.playing);
    });
    _loadCatalog();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.get(_catalogUri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw HttpException('Catálogo indisponível (HTTP ${response.statusCode}).');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) throw const FormatException('Invalid audio catalog');
      final items = decoded
          .whereType<Map>()
          .map((entry) => _AudioLibraryItem.fromJson(Map<String, dynamic>.from(entry)))
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar a biblioteca. Verifica a internet e tenta novamente.';
      });
    }
  }

  Uri _urlFor(String relativePath) => _audioBaseUri.resolve(relativePath);

  Future<void> _togglePreview(_AudioLibraryItem item) async {
    try {
      if (_previewingId == item.id && _playing) {
        await _player.pause();
        return;
      }
      await _player.stop();
      setState(() => _previewingId = item.id);
      await _player.setSourceUrl(_urlFor(item.preview).toString());
      await _player.resume();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível reproduzir a pré-escuta deste áudio.')),
        );
      }
    }
  }

  Future<void> _download(_AudioLibraryItem item) async {
    if (item.isPro && !await ProAccessService.requirePro(context, feature: 'Biblioteca de áudio Pro')) {
      return;
    }
    if (!mounted) return;
    setState(() => _downloading.add(item.id));
    try {
      final response = await http.get(_urlFor(item.file)).timeout(const Duration(seconds: 45));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw HttpException('Não foi possível transferir o áudio.');
      }
      if (response.bodyBytes.length > 35 * 1024 * 1024) {
        throw const FormatException('O ficheiro de áudio excede 35 MB.');
      }
      final root = await getApplicationDocumentsDirectory();
      final directory = Directory('${root.path}/audio_library');
      await directory.create(recursive: true);
      final extension = item.file.split('.').last.toLowerCase();
      final output = File('${directory.path}/${item.id}.$extension');
      await output.writeAsBytes(response.bodyBytes, flush: true);
      if (!await output.exists() || await output.length() == 0) {
        throw StateError('O áudio transferido está vazio.');
      }
      await _player.stop();
      if (!mounted) return;
      Navigator.of(context).pop(AudioLibrarySelection(
        id: item.id,
        name: item.name,
        path: output.path,
        isPro: item.isPro,
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error is FormatException
              ? 'Este áudio não pode ser transferido: o ficheiro é demasiado grande ou o catálogo está incorreto.'
              : 'O download falhou. Verifica a internet e tenta novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>['Todos', ..._items.map((item) => item.category).toSet()];
    final filtered = _items.where((item) {
      final matchesCategory = _category == 'Todos' || item.category == _category;
      final query = _search.trim().toLowerCase();
      return matchesCategory &&
          (query.isEmpty ||
              item.name.toLowerCase().contains(query) ||
              item.description.toLowerCase().contains(query));
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca de áudio'),
        actions: [
          IconButton(
            tooltip: 'Atualizar biblioteca',
            onPressed: _loading ? null : _loadCatalog,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Pesquisar sons e efeitos',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (categories.length > 1)
            SizedBox(
              height: 48,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final category in categories)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_rounded, size: 42),
                              const SizedBox(height: 12),
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _loadCatalog,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.library_music_outlined, size: 52, color: Color(0xFF9D91FF)),
                                  const SizedBox(height: 14),
                                  const Text('Ainda não há áudios publicados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                                  const SizedBox(height: 8),
                                  const Text('A biblioteca atualiza-se pelo catálogo online. Os novos sons podem ser publicados no site sem atualizar o APK.', textAlign: TextAlign.center),
                                  const SizedBox(height: 8),
                                  TextButton(onPressed: _loadCatalog, child: const Text('Atualizar catálogo')),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 22),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final isPreviewing = _previewingId == item.id && _playing;
                              return Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B1E2D),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF303449)),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF332B61),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(item.isPro ? Icons.workspace_premium_rounded : Icons.graphic_eq_rounded, color: const Color(0xFFC0B5FF)),
                                  ),
                                  title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text('${item.category} · ${item.description}', maxLines: 2, overflow: TextOverflow.ellipsis),
                                  trailing: Wrap(
                                    spacing: 2,
                                    children: [
                                      IconButton(
                                        tooltip: isPreviewing ? 'Pausar pré-escuta' : 'Ouvir pré-escuta',
                                        onPressed: () => _togglePreview(item),
                                        icon: Icon(isPreviewing ? Icons.pause_circle_filled_rounded : Icons.play_circle_outline_rounded),
                                      ),
                                      IconButton(
                                        tooltip: item.isPro ? 'Transferir áudio Pro' : 'Transferir áudio',
                                        onPressed: _downloading.contains(item.id) ? null : () => _download(item),
                                        icon: _downloading.contains(item.id)
                                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                            : const Icon(Icons.download_rounded),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
