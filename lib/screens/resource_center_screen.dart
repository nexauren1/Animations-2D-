import 'package:flutter/material.dart';

import '../services/resource_pack_service.dart';
import '../services/template_catalog.dart';

/// Optional template packs are fetched only when the user requests them.
class ResourceCenterScreen extends StatefulWidget {
  const ResourceCenterScreen({super.key});

  @override
  State<ResourceCenterScreen> createState() => _ResourceCenterScreenState();
}

class _ResourceCenterScreenState extends State<ResourceCenterScreen> {
  List<DownloadedResourcePack> _downloaded = <DownloadedResourcePack>[];
  bool _loading = true;
  String? _downloading;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final packs = await ResourcePackService.loadDownloaded();
      if (!mounted) return;
      setState(() {
        _downloaded = packs;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível ler os pacotes guardados: $error';
      });
    }
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
        SnackBar(content: Text('Pacote "${downloaded.title}" guardado no dispositivo.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Download não concluído: $error');
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
  }

  Future<void> _remove(DownloadedResourcePack pack) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover pacote?'),
        content: Text('"${pack.title}" será removido do armazenamento deste dispositivo.'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de recursos', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
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
                Text('Instala só o conteúdo que precisas.',
                    style: TextStyle(fontSize: 22, height: 1.12, fontWeight: FontWeight.w900)),
                SizedBox(height: 8),
                Text('Os pacotes contêm projetos vetoriais pequenos. São descarregados quando pedes, guardados no telefone e podem ser removidos depois.',
                    style: TextStyle(color: Colors.white70, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text('PACOTES DISPONÍVEIS',
              style: TextStyle(fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w900, color: Color(0xFFB5A8FF))),
          const SizedBox(height: 10),
          for (final pack in ResourcePackService.available) _availableCard(pack),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text('Conteúdo instalado',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              ),
              Text('${_downloaded.length} pacote(s)',
                  style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 12)),
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
                    child: Text('Ainda não instalaste pacotes extra. Escolhe um dos pacotes acima quando tiveres internet disponível.',
                        style: TextStyle(color: Colors.white70, height: 1.35)),
                  ),
                ],
              ),
            )
          else
            for (final pack in _downloaded) _downloadedCard(pack),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF48282C),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(_error!, style: const TextStyle(color: Color(0xFFFFC6C6))),
            ),
          ],
          const SizedBox(height: 16),
          Text('Usa Wi-Fi quando possível. Os pacotes disponíveis indicam o tamanho aproximado antes do download.',
              style: TextStyle(color: Colors.white.withOpacity(.48), fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }

  Widget _availableCard(DownloadableResourcePack pack) {
    final matching = _downloaded.where((item) => item.id == pack.id);
    final downloaded = matching.isEmpty ? null : matching.first;
    final downloading = _downloading == pack.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
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
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF8A7DFF).withOpacity(.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              pack.id == 'space-pack' ? Icons.public_rounded : Icons.face_retouching_natural_rounded,
              color: const Color(0xFFB5A8FF),
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pack.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 4),
                Text(pack.description,
                    style: TextStyle(color: Colors.white.withOpacity(.61), fontSize: 12, height: 1.3)),
                const SizedBox(height: 7),
                Text(pack.sizeLabel,
                    style: const TextStyle(color: Color(0xFF8DE1DE), fontWeight: FontWeight.w800, fontSize: 11)),
                const SizedBox(height: 8),
                if (downloading)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('A descarregar…', style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                  OutlinedButton.icon(
                    onPressed: _downloading == null ? () => _download(pack) : null,
                    icon: const Icon(Icons.download_rounded, size: 17),
                    label: const Text('Baixar pacote'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: const Color(0xFFB5A8FF),
                    ),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('${template.createFrames().length} frames · ${template.fps} FPS',
                            style: TextStyle(color: Colors.white.withOpacity(.52), fontSize: 11)),
                      ],
                    ),
                  ),
                  TextButton(
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
