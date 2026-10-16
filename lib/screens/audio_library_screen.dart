import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart' hide Text;

import '../services/audio_library_service.dart';

class AudioLibraryScreen extends StatefulWidget {
  const AudioLibraryScreen({
    required this.projectUid,
    required this.initialFrame,
    required this.frameCount,
    required this.requirePro,
    super.key,
  });

  final String projectUid;
  final int initialFrame;
  final int frameCount;
  final Future<bool> Function(String feature) requirePro;

  @override
  State<AudioLibraryScreen> createState() => _AudioLibraryScreenState();
}

class _AudioLibraryScreenState extends State<AudioLibraryScreen> {
  final AudioPlayer _previewPlayer = AudioPlayer();
  final TextEditingController _frameController = TextEditingController();
  List<AudioCatalogItem> _items = <AudioCatalogItem>[];
  List<AudioTimelineClip> _clips = <AudioTimelineClip>[];
  bool _loading = true;
  bool _busy = false;
  String? _catalogError;
  String? _previewingId;
  String _filter = 'Tudo';

  @override
  void initState() {
    super.initState();
    _frameController.text = (widget.initialFrame + 1).toString();
    _load();
  }

  @override
  void dispose() {
    _frameController.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _catalogError = null;
    });
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        AudioLibraryService.fetchCatalog(),
        AudioLibraryService.loadClips(widget.projectUid),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<AudioCatalogItem>;
        _clips = results[1] as List<AudioTimelineClip>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      final local = await AudioLibraryService.loadClips(widget.projectUid);
      setState(() {
        _clips = local;
        _loading = false;
        _catalogError = 'Não foi possível atualizar a biblioteca online. Verifica a ligação e tenta novamente.';
      });
    }
  }

  Future<int?> _selectedStartFrame() async {
    final parsed = int.tryParse(_frameController.text.trim());
    if (parsed == null || parsed < 1 || parsed > 20000) {
      _message('Indica um frame válido, a partir de 1.', error: true);
      return null;
    }
    return parsed - 1;
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(value),
        backgroundColor: error ? const Color(0xFF8C3443) : null,
      ));
  }

  Future<void> _togglePreview(AudioCatalogItem item) async {
    if (_previewingId == item.id) {
      await _previewPlayer.stop();
      if (mounted) setState(() => _previewingId = null);
      return;
    }
    try {
      await _previewPlayer.stop();
      setState(() => _previewingId = item.id);
      await _previewPlayer.play(UrlSource(item.downloadUrl));
      _previewPlayer.onPlayerComplete.first.then((_) {
        if (mounted && _previewingId == item.id) setState(() => _previewingId = null);
      });
    } catch (_) {
      if (mounted) setState(() => _previewingId = null);
      _message('Não foi possível reproduzir a pré-visualização deste som.', error: true);
    }
  }

  Future<void> _placeCatalogItem(AudioCatalogItem item) async {
    if (_busy) return;
    final startFrame = await _selectedStartFrame();
    if (startFrame == null) return;
    if (item.isPro && !await widget.requirePro('Biblioteca de áudio Pro')) return;
    setState(() => _busy = true);
    try {
      var localPath = await AudioLibraryService.existingDownloadPath(item);
      localPath ??= await AudioLibraryService.downloadItem(item);
      final clip = AudioTimelineClip(
        instanceId: DateTime.now().microsecondsSinceEpoch.toString(),
        catalogId: item.id,
        title: item.title,
        localPath: localPath,
        startFrame: startFrame,
        volume: 1,
        isPro: item.isPro,
        credit: item.credit,
        license: item.license,
      );
      final updated = <AudioTimelineClip>[..._clips, clip]
        ..sort((a, b) => a.startFrame.compareTo(b.startFrame));
      await AudioLibraryService.saveClips(widget.projectUid, updated);
      if (!mounted) return;
      setState(() => _clips = updated);
      _message('“${item.title}” adicionado à timeline a partir do frame ${startFrame + 1}.');
    } catch (_) {
      _message('Não foi possível descarregar este som. Confirma a ligação à internet e tenta novamente.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importLocal() async {
    if (_busy) return;
    final startFrame = await _selectedStartFrame();
    if (startFrame == null) return;
    setState(() => _busy = true);
    try {
      final path = await AudioLibraryService.importLocalFile();
      if (path == null) return;
      final name = path.split(Platform.pathSeparator).last;
      final clip = AudioTimelineClip(
        instanceId: DateTime.now().microsecondsSinceEpoch.toString(),
        catalogId: 'local',
        title: name,
        localPath: path,
        startFrame: startFrame,
        volume: 1,
        isPro: false,
      );
      final updated = <AudioTimelineClip>[..._clips, clip]
        ..sort((a, b) => a.startFrame.compareTo(b.startFrame));
      await AudioLibraryService.saveClips(widget.projectUid, updated);
      if (!mounted) return;
      setState(() => _clips = updated);
      _message('Áudio importado e colocado no frame ${startFrame + 1}.');
    } catch (error) {
      _message(error is FormatException ? error.message ?? 'Formato de áudio inválido.' : 'Não foi possível importar este áudio.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeClip(AudioTimelineClip clip) async {
    final updated = _clips.where((value) => value.instanceId != clip.instanceId).toList();
    await AudioLibraryService.saveClips(widget.projectUid, updated);
    if (mounted) setState(() => _clips = updated);
  }

  Future<void> _changeVolume(AudioTimelineClip clip, double volume) async {
    final updated = _clips
        .map((value) => value.instanceId == clip.instanceId ? value.copyWith(volume: volume) : value)
        .toList();
    setState(() => _clips = updated);
    await AudioLibraryService.saveClips(widget.projectUid, updated);
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>['Tudo', ..._items.map((item) => item.category).toSet().toList()..sort()];
    final visibleItems = _filter == 'Tudo'
        ? _items
        : _items.where((item) => item.category == _filter).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca de áudio', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Atualizar biblioteca',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF202239),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF414668)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.graphic_eq_rounded, color: Color(0xFF61D7E8), size: 25),
                  SizedBox(width: 9),
                  Expanded(child: Text('Sons no tempo certo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                ]),
                const SizedBox(height: 8),
                const Text(
                  'Pré-visualiza primeiro; depois adiciona o som à timeline. Os clips são guardados localmente com este projeto. Durante a pré-visualização do editor, cada som começa no frame indicado.',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  const Expanded(child: Text('Colocar no frame', style: TextStyle(fontWeight: FontWeight.w800))),
                  SizedBox(
                    width: 88,
                    child: TextField(
                      controller: _frameController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        isDense: true,
                        suffixText: 'º',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _importLocal,
                    icon: const Icon(Icons.audio_file_rounded),
                    label: const Text('Importar áudio do dispositivo'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(children: [
            const Expanded(child: Text('Sons disponíveis', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900))),
            if (_busy) const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(26),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_catalogError != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF202332), borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_catalogError!, style: const TextStyle(color: Colors.white70)),
                TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
              ]),
            )
          else if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(color: const Color(0xFF202332), borderRadius: BorderRadius.circular(14)),
              child: const Text(
                'A biblioteca online ainda está vazia. Quando os ficheiros e as entradas forem adicionados a content/audio/catalog.json no repositório, aparecerão aqui automaticamente.',
                style: TextStyle(color: Colors.white70, height: 1.45),
              ),
            )
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: category == _filter,
                      onSelected: (_) => setState(() => _filter = category),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            for (final item in visibleItems) _catalogCard(item),
          ],
          const SizedBox(height: 22),
          Text('Timeline do projeto · ${_clips.length} clip(s)', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (_clips.isEmpty)
            const Text('Ainda não há áudio nesta timeline. Importa um ficheiro ou adiciona um som da biblioteca.',
                style: TextStyle(color: Colors.white60))
          else
            for (final clip in _clips) _clipCard(clip),
        ],
      ),
    );
  }

  Widget _catalogCard(AudioCatalogItem item) {
    final previewing = _previewingId == item.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30364C)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: const Color(0xFF2F3450), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.graphic_eq_rounded, color: item.isPro ? const Color(0xFFFFD36A) : const Color(0xFF73DDEB), size: 24),
          ),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(item.category, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            if (item.credit.isNotEmpty) Text('Crédito: ${item.credit}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ])),
          if (item.isPro)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF594A23), borderRadius: BorderRadius.circular(8)),
              child: const Text('PRO', style: TextStyle(color: Color(0xFFFFD36A), fontSize: 10, fontWeight: FontWeight.w900)),
            ),
        ]),
        const SizedBox(height: 11),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _togglePreview(item),
              icon: Icon(previewing ? Icons.stop_rounded : Icons.play_arrow_rounded),
              label: Text(previewing ? 'Parar preview' : 'Ouvir preview'),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _placeCatalogItem(item),
              icon: const Icon(Icons.add_to_queue_rounded),
              label: const Text('Adicionar'),
            ),
          ),
        ]),
        if (item.license.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Licença: ${item.license}', style: const TextStyle(fontSize: 10, color: Colors.white38)),
          ),
      ]),
    );
  }

  Widget _clipCard(AudioTimelineClip clip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(13, 11, 7, 10),
      decoration: BoxDecoration(color: const Color(0xFF202332), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.audio_file_outlined, color: Color(0xFF70D7E6)),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(clip.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('Começa no frame ${clip.startFrame + 1}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ])),
          IconButton(tooltip: 'Remover da timeline', onPressed: () => _removeClip(clip), icon: const Icon(Icons.delete_outline_rounded)),
        ]),
        Row(children: [
          const Icon(Icons.volume_down_rounded, size: 16, color: Colors.white54),
          Expanded(child: Slider(
            value: clip.volume.clamp(0, 1),
            min: 0,
            max: 1,
            divisions: 20,
            onChanged: (value) => _changeVolume(clip, value),
          )),
          Text('${(clip.volume * 100).round()}%', style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ]),
      ]),
    );
  }
}
