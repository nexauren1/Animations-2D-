import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/project_model.dart';
import '../services/project_store.dart';
import '../services/project_backup_service.dart';
import 'canvas_screen.dart';
import 'account_screen.dart';
import 'upgrade_screen.dart';
import 'legal_screen.dart';
import 'resource_center_screen.dart';
import 'template_gallery_screen.dart';
import '../services/template_catalog.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.store, super.key});
  final ProjectStore store;

  Future<void> _create(BuildContext context) async {
    final controller = TextEditingController(text: 'Minha animação');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Novo projeto'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 48,
          decoration: const InputDecoration(labelText: 'Nome do projeto'),
          onSubmitted: (_) => Navigator.pop(dialogContext, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            icon: const Icon(Icons.add),
            label: const Text('Criar'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    final project = await store.createProject(name);
    if (!context.mounted) return;
    await _open(context, project);
  }

  Future<void> _open(BuildContext context, ProjectModel project) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CanvasScreen(store: store, project: project),
    ));
  }

  Future<void> _rename(BuildContext context, ProjectModel project) async {
    final controller = TextEditingController(text: project.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Renomear projeto'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 48,
          decoration: const InputDecoration(labelText: 'Nome'),
          onSubmitted: (_) => Navigator.pop(dialogContext, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await store.renameProject(project, name);
    }
  }

  Future<void> _delete(BuildContext context, ProjectModel project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apagar projeto?'),
        content: Text('“${project.name}” será removido deste dispositivo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await store.deleteProject(project);
  }

  Future<void> _exportBackup(BuildContext context, ProjectModel project) async {
    try {
      await ProjectBackupService.shareProject(project);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível exportar o projeto: $error')),
      );
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    try {
      final imported = await ProjectBackupService.pickAndReadProject();
      final project = await store.createProject(imported.name);
      project.fps = imported.fps;
      await store.saveProject(project, frames: imported.frames);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Projeto "${project.name}" importado com sucesso.')),
      );
    } on BackupCancelledException {
      // Cancelar o seletor de ficheiros não é um erro.
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível importar o backup: $error')),
      );
    }
  }

  Future<void> _openResourceCenter(BuildContext context) async {
    final template = await Navigator.of(context).push<AnimationTemplate>(
      MaterialPageRoute<AnimationTemplate>(
        builder: (_) => const ResourceCenterScreen(),
      ),
    );
    if (template != null && context.mounted) {
      await _useTemplate(context, template);
    }
  }

  Future<void> _openTemplates(BuildContext context) async {
    final template = await Navigator.of(context).push<AnimationTemplate>(
      MaterialPageRoute<AnimationTemplate>(
        builder: (_) => const TemplateGalleryScreen(),
      ),
    );
    if (template != null && context.mounted) {
      await _useTemplate(context, template);
    }
  }

  Future<void> _useTemplate(BuildContext context, AnimationTemplate template) async {
    final project = await store.createProject(template.title);
    project.fps = template.fps;
    await store.saveProject(project, frames: template.createFrames());
    if (!context.mounted) return;
    await _open(context, project);
  }

  Future<void> _action(
    BuildContext context,
    ProjectModel project,
    String action,
  ) async {
    if (action == 'rename') {
      await _rename(context, project);
    } else if (action == 'duplicate') {
      await store.duplicateProject(project);
    } else if (action == 'delete') {
      await _delete(context, project);
    } else if (action == 'export') {
      await _exportBackup(context, project);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _BrandMark(),
            SizedBox(width: 10),
            Text('AnimPro', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
            if (const bool.fromEnvironment('ANIMPRO_TEST_BUILD')) ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFF4A3B13),
                  borderRadius: BorderRadius.all(Radius.circular(7)),
                  border: Border.fromBorderSide(BorderSide(color: Color(0xFFD6A842))),
                ),
                child: Text(
                  'TESTE',
                  style: TextStyle(
                    color: Color(0xFFFFD979),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'AnimPro Pro — planos e funções avançadas',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const UpgradeScreen()),
            ),
            icon: const Icon(Icons.workspace_premium_outlined, color: Color(0xFFFFD36A)),
          ),
          IconButton(
            tooltip: 'Centro de recursos e downloads',
            onPressed: () => _openResourceCenter(context),
            icon: const Icon(Icons.cloud_download_outlined),
          ),
          IconButton(
            tooltip: 'Conta AnimPro',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
            ),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Mais informações',
            onSelected: (value) {
              if (value == 'legal') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LegalScreen()),
                );
              } else if (value == 'about') {
                showAboutDialog(
                  context: context,
                  applicationName: 'AnimPro',
                  applicationVersion: '1.2.0',
                  children: const [
                    Text('Desenha, cria frames e experimenta poses 2D.'),
                  ],
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'legal',
                child: ListTile(
                  leading: Icon(Icons.privacy_tip_outlined),
                  title: Text('Site, privacidade e suporte'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'about',
                child: ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('Sobre o AnimPro'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final projects = store.projects;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vamos animar?',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text('Transforma os teus desenhos em movimento.',
                          style: TextStyle(color: Colors.white.withOpacity(.62))),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: FilledButton.icon(
                          onPressed: () => _create(context),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 25),
                          label: const Text('Novo Projeto',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6757F5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () => _importBackup(context),
                          icon: const Icon(Icons.file_open_rounded),
                          label: const Text('Importar backup de projeto (.animpro)'),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Começa por um exemplo',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          ),
                          TextButton(
                            onPressed: () => _openTemplates(context),
                            child: const Text('Ver todos'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 182,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: TemplateCatalog.all.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final template = TemplateCatalog.all[index];
                            final tint = Color(template.tint);
                            return SizedBox(
                              width: 154,
                              child: Material(
                                color: const Color(0xFF191C2B),
                                borderRadius: BorderRadius.circular(18),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => _useTemplate(context, template),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: TemplateAnimationPreview(template: template),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(template.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                            const SizedBox(height: 4),
                                            Text('${template.frames().length} frames · ${template.fps} FPS',
                                                style: TextStyle(color: tint, fontSize: 10, fontWeight: FontWeight.w700)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Projetos recentes',
                                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                          ),
                          Text('${projects.length} projeto(s)',
                              style: TextStyle(color: Colors.white.withOpacity(.5))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (projects.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(34, 0, 34, 70),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2030),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: const Icon(Icons.draw_rounded,
                                size: 48, color: Color(0xFF8F83FF)),
                          ),
                          const SizedBox(height: 18),
                          const Text('O teu primeiro projeto começa aqui',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text('Cria um projeto e desenha o primeiro frame.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withOpacity(.58))),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 13,
                      mainAxisSpacing: 15,
                      childAspectRatio: .76,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final project = projects[index];
                        return _ProjectCard(
                          project: project,
                          onTap: () => _open(context, project),
                          onAction: (action) => _action(context, project, action),
                        );
                      },
                      childCount: projects.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6555F5), Color(0xFF8D50E8)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
      );
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onAction,
  });
  final ProjectModel project;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    final frames = project.frames;
    final frame = frames.isEmpty ? FrameModel.blank() : frames.first;
    final date = project.updatedAt.toString().split(' ').first;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _ThumbnailPainter(frame)),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: PopupMenuButton<String>(
                      tooltip: 'Opções do projeto',
                      color: const Color(0xFF25283A),
                      onSelected: onAction,
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Renomear')),
                        PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
                        PopupMenuItem(value: 'export', child: Text('Exportar backup (.animpro)')),
                        PopupMenuItem(value: 'delete', child: Text('Apagar')),
                      ],
                      icon: const Icon(Icons.more_horiz, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${frames.length} frames',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 13, color: Colors.white.withOpacity(.5)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(date,
                            maxLines: 1,
                            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(.55))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbnailPainter extends CustomPainter {
  _ThumbnailPainter(this.frame);
  final FrameModel frame;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF292D48));
    final layers = frame.layers.where((layer) => layer.visible).toList().reversed;
    final points = layers.expand((layer) => layer.strokes)
        .expand((stroke) => stroke.points).toList();
    if (points.isEmpty) {
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), 23,
          Paint()..color = const Color(0xFF8D86FF).withOpacity(.8));
      final path = Path()
        ..moveTo(size.width / 2 - 7, size.height / 2 - 11)
        ..lineTo(size.width / 2 + 10, size.height / 2)
        ..lineTo(size.width / 2 - 7, size.height / 2 + 11)
        ..close();
      canvas.drawPath(path, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3);
      return;
    }

    var left = points.first.dx;
    var right = left;
    var top = points.first.dy;
    var bottom = top;
    for (final point in points) {
      if (point.dx < left) left = point.dx;
      if (point.dx > right) right = point.dx;
      if (point.dy < top) top = point.dy;
      if (point.dy > bottom) bottom = point.dy;
    }
    final double width = math.max(right - left, 1.0).toDouble();
    final double height = math.max(bottom - top, 1.0).toDouble();
    final double scale = math.min((size.width - 24) / width, (size.height - 24) / height).toDouble();
    final dx = (size.width - width * scale) / 2 - left * scale;
    final dy = (size.height - height * scale) / 2 - top * scale;

    for (final layer in layers) {
      for (final stroke in layer.strokes) {
        if (stroke.points.isEmpty) continue;
        final paint = Paint()
          ..color = Color(stroke.color)
          ..strokeWidth = math.max(1.0, stroke.width * scale).toDouble()
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;
        if (stroke.points.length == 1) {
          canvas.drawCircle(
            Offset(stroke.points.first.dx * scale + dx, stroke.points.first.dy * scale + dy),
            math.max(1.5, stroke.width * scale / 2).toDouble(),
            paint..style = PaintingStyle.fill,
          );
        } else {
          final path = Path()
            ..moveTo(stroke.points.first.dx * scale + dx, stroke.points.first.dy * scale + dy);
          for (final point in stroke.points.skip(1)) {
            path.lineTo(point.dx * scale + dx, point.dy * scale + dy);
          }
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ThumbnailPainter oldDelegate) => true;
}
