import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import '../services/app_locale.dart';

import '../services/resource_pack_service.dart';
import 'audio_library_screen.dart';
import 'template_gallery_screen.dart';
import '../services/template_catalog.dart';

/// Online-first library for downloadable, editable scene and character packs.
class ResourceCenterScreen extends StatefulWidget {
  const ResourceCenterScreen({super.key});

  @override
  State<ResourceCenterScreen> createState() => _ResourceCenterScreenState();
}

class _ResourceCenterScreenState extends State<ResourceCenterScreen> {
  List<DownloadableResourcePack> _available = <DownloadableResourcePack>[];
  List<DownloadedResourcePack> _downloaded = <DownloadedResourcePack>[];
  bool _loading = true;
  bool _catalogLoading = true;
  String? _downloading;
  String? _previewing;
  int _usedBytes = 0;
  String? _error;
  String _category = 'Todos';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _catalogLoading = true;
        _error = null;
      });
    }
    List<DownloadableResourcePack> available = <DownloadableResourcePack>[];
    List<DownloadedResourcePack> downloaded = <DownloadedResourcePack>[];
    String? error;
    try {
      available = await ResourcePackService.loadAvailable();
    } catch (_) {
      error = 'Não foi possível carregar o catálogo online. Verifica a internet e tenta novamente.';
    }
    try {
      downloaded = await ResourcePackService.loadDownloaded();
    } catch (_) {
      error ??= 'Não foi possível ler os pacotes guardados neste telefone.';
    }
    var usedBytes = 0;
    for (final pack in downloaded) {
      try {
        final file = File(pack.filePath);
        if (await file.exists()) usedBytes += await file.length();
      } catch (_) {
        // Storage information should never prevent a library from opening.
      }
    }
    if (!mounted) return;
    setState(() {
      _available = available;
      _downloaded = downloaded;
      _usedBytes = usedBytes;
      _loading = false;
      _catalogLoading = false;
      _error = error;
      if (!_available.any((pack) => pack.category == _category)) {
        _category = 'Todos';
      }
    });
  }

  Future<void> _download(DownloadableResourcePack pack) async {
    setState(() {
      _downloading = pack.id;
      _error = null;
    });
    try {
      final downloaded = await ResourcePackService.download(pack);
      if (!mounted) return;
      setState(() {
        _downloaded = <DownloadedResourcePack>[
          ..._downloaded.where((item) => item.id != downloaded.id),
          downloaded,
        ]..sort((a, b) => a.title.compareTo(b.title));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${downloaded.title}" foi descarregado e está disponível offline.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error is FormatException
          ? error.message
          : 'Não foi possível concluir o download. Verifica a ligação e tenta novamente.');
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
  }

  Future<void> _preview(DownloadableResourcePack pack) async {
    setState(() {
      _previewing = pack.id;
      _error = null;
    });
    try {
      final templates = await ResourcePackService.preview(pack);
      if (!mounted) return;
      final selected = await showModalBottomSheet<AnimationTemplate>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF171A28),
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .86,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
              children: [
                Text(pack.title,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(
                  'Pré-visualização online · ${pack.sizeLabel} · ${templates.length} modelos',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 14),
                for (final template in templates)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF202337),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: Colors.white.withOpacity(.08)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 180,
                          child: TemplateAnimationPreview(template: template),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(template.title,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(template.description,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(height: 9),
                              Row(
                                children: [
                                  Text(
                                    '${template.createFrames().length} frames · ${template.fps} FPS',
                                    style: const TextStyle(color: Color(0xFF8DE1DE), fontSize: 11),
                                  ),
                                  const Spacer(),
                                  FilledButton.tonalIcon(
                                    onPressed: () => Navigator.of(sheetContext).pop(template),
                                    icon: const Icon(Icons.edit_rounded, size: 16),
                                    label: const Text('Usar modelo'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Fechar pré-visualização'),
                ),
              ],
            ),
          ),
        ),
      );
      if (selected != null && mounted) _useTemplate(selected);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error is FormatException
          ? error.message
          : 'Não foi possível obter a pré-visualização. Verifica a ligação e tenta novamente.');
    } finally {
      if (mounted) setState(() => _previewing = null);
    }
  }

  Future<void> _remove(DownloadedResourcePack pack) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover pacote?'),
        content: Text('"${pack.title}" será removido do armazenamento deste dispositivo. Os projetos que já criaste não serão alterados.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ResourcePackService.delete(pack.id);
    await _refresh();
  }

  void _useTemplate(AnimationTemplate template) {
    Navigator.of(context).pop(template);
  }

  IconData _categoryIcon(String category) {
    final value = category.toLowerCase();
    if (value.contains('céu') || value.contains('espaço')) return Icons.cloud_rounded;
    if (value.contains('floresta') || value.contains('natureza')) return Icons.forest_rounded;
    if (value.contains('casa') || value.contains('interior')) return Icons.weekend_rounded;
    if (value.contains('cidade') || value.contains('urbano')) return Icons.location_city_rounded;
    if (value.contains('ação') || value.contains('personagem')) return Icons.sports_martial_arts_rounded;
    if (value.contains('fantasia')) return Icons.auto_awesome_rounded;
    return Icons.layers_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>[
      'Todos',
      ..._available.map((pack) => pack.category).toSet().toList()..sort(),
    ];
    final query = _search.trim().toLowerCase();
    final visible = _available.where((pack) {
      final matchesCategory = _category == 'Todos' || pack.category == _category;
      final searchable = '${pack.title} ${pack.description} ${pack.tags.join(' ')}'.toLowerCase();
      return matchesCategory && (query.isEmpty || searchable.contains(query));
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca AnimPro', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Abrir biblioteca de áudio',
            onPressed: () {
              Navigator.of(context).push<AudioLibrarySelection>(
                MaterialPageRoute<AudioLibrarySelection>(
                  builder: (_) => const AudioLibraryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.library_music_rounded),
          ),
          IconButton(
            tooltip: 'Atualizar catálogo',
            onPressed: _catalogLoading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF203F4C), Color(0xFF242344), Color(0xFF30265A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(23),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cloud_download_rounded, color: Color(0xFF8DE1DE), size: 31),
                  SizedBox(height: 12),
                  Text('Cenários e sons, dentro do AnimPro.',
                      style: TextStyle(fontSize: 22, height: 1.12, fontWeight: FontWeight.w900)),
                  SizedBox(height: 8),
                  Text(
                    'Céus, florestas, interiores, cidades, personagens e cenas de ação. Entra nas bibliotecas de cenários e de áudio sem sair da aplicação. Os ficheiros completos só são descarregados quando escolhes usá-los.',
                    style: TextStyle(color: Colors.white70, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Pesquisar cenários, personagens e objetos…',
                filled: true,
                fillColor: const Color(0xFF191C2B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (categories.length > 1)
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final category in categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: category == _category,
                          onSelected: (_) => setState(() => _category = category),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 15),
            Row(
              children: [
                const Expanded(
                  child: Text('CATÁLOGO ONLINE',
                      style: TextStyle(fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w900, color: Color(0xFFB5A8FF))),
                ),
                if (_catalogLoading)
                  const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Text('${visible.length} pacotes',
                      style: TextStyle(color: Colors.white.withOpacity(.52), fontSize: 11)),
              ],
            ),
            const SizedBox(height: 9),
            if (_catalogLoading && _available.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (visible.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF191C2B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _available.isEmpty
                      ? 'O catálogo ainda não está disponível. Liga-te à internet e atualiza a página.'
                      : 'Não há pacotes nesta pesquisa. Experimenta outra palavra ou categoria.',
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
              )
            else
              for (final pack in visible) _availableCard(pack),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFF48282C),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFFFC6C6))),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text('Conteúdo instalado',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                ),
                Text(
                  '${_downloaded.length} pacotes · ${(_usedBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
                  style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(22),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_downloaded.isEmpty)
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: const Color(0xFF171A28),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: Colors.white.withOpacity(.06)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: Colors.white54, size: 27),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Ainda não instalaste pacotes extra. Os modelos não ocupam espaço no APK; só são guardados no telefone quando os descarregas.',
                          style: TextStyle(color: Colors.white70, height: 1.35)),
                    ),
                  ],
                ),
              )
            else
              for (final pack in _downloaded) _downloadedCard(pack),
            const SizedBox(height: 12),
            Text(
              'Os pacotes são transferidos do site quando pedes, verificados por SHA-256 e guardados para utilização offline. Podes removê-los daqui sem apagar os projetos que já criaste.',
              style: TextStyle(color: Colors.white.withOpacity(.48), fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _availableCard(DownloadableResourcePack pack) {
    final matching = _downloaded.where((item) => item.id == pack.id);
    final downloaded = matching.isEmpty ? null : matching.first;
    final downloading = _downloading == pack.id;
    const tint = Color(0xFF8DE1DE);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF191C2B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: tint.withOpacity(.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_categoryIcon(pack.category), color: tint, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(pack.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                    Text(pack.sizeLabel,
                        style: const TextStyle(color: Color(0xFF8DE1DE), fontWeight: FontWeight.w800, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(pack.description,
                    style: TextStyle(color: Colors.white.withOpacity(.63), fontSize: 12, height: 1.3)),
                const SizedBox(height: 6),
                Text(
                  '${pack.category} · ${pack.templateCount} modelos${pack.tags.isEmpty ? '' : ' · ${pack.tags.take(2).join(', ')}'}',
                  style: TextStyle(color: Colors.white.withOpacity(.47), fontSize: 10),
                ),
                const SizedBox(height: 8),
                if (downloading)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('A verificar e a descarregar…', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  )
                else if (downloaded != null)
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF79D9AB), size: 17),
                      const SizedBox(width: 5),
                      const Text('Instalado', style: TextStyle(color: Color(0xFF79D9AB), fontWeight: FontWeight.w800, fontSize: 12)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _remove(downloaded),
                        child: const Text('Remover'),
                      ),
                    ],
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _previewing == null ? () => _preview(pack) : null,
                        icon: _previewing == pack.id
                            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.visibility_rounded, size: 16),
                        label: const Text('Pré-visualizar'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: const Color(0xFF8DE1DE),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _downloading == null ? () => _download(pack) : null,
                        icon: const Icon(Icons.download_rounded, size: 17),
                        label: const Text('Descarregar'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: const Color(0xFFB5A8FF),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _downloadedCard(DownloadedResourcePack pack) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF151E24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF79D9AB).withOpacity(.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_special_rounded, color: Color(0xFF79D9AB)),
              const SizedBox(width: 9),
              Expanded(
                child: Text(pack.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
              ),
              TextButton(
                onPressed: () => _remove(pack),
                child: const Text('Remover'),
              ),
            ],
          ),
          if (pack.description.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(pack.description, style: TextStyle(color: Colors.white.withOpacity(.59), fontSize: 12)),
          ],
          const SizedBox(height: 11),
          for (final template in pack.templates)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: Color(template.tint).withOpacity(.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(Icons.animation_rounded, color: Color(template.tint)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(template.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${template.createFrames().length} frames · ${template.fps} FPS',
                            style: TextStyle(color: Colors.white.withOpacity(.48), fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.tonal(
                    onPressed: () => _useTemplate(template),
                    child: const Text('Usar'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
