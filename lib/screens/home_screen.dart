import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/project_model.dart';
import '../services/project_store.dart';
import 'canvas_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.store, super.key});

  final ProjectStore store;

  Future<void> _newProject(BuildContext context) async {
    final controller = TextEditingController(text: 'Minha animação');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Novo projeto'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 48,
          decoration: const InputDecoration(
            labelText: 'Nome do projeto',
            hintText: 'Ex.: Raposa a correr',
          ),
          onSubmitted: (_) => Navigator.pop(dialogContext, controller.text),
        ),
        actions: <Widget>[
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
    await _openProject(context, project);
  }

  Future<void> _openProject(BuildContext context, ProjectModel project) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CanvasScreen(store: store, project: project),
      ),
    );
  }

  Future<void> _renameProject(
    BuildContext context,
    ProjectModel project,
  ) async {
    final controller = TextEditingController(text: project.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Renomear projeto'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 48,
          onSubmitted: (_) => Navigator.pop(dialogContext, controller.text),
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        actions: <Widget>[
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
    if (name == null || name.trim().isEmpty) return;
    await store.renameProject(project, name);
  }

  Future<void> _deleteProject(
    BuildContext context,
    ProjectModel project,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apagar projeto?'),
        content: Text('O projeto “${project.name}” será removido deste dispositivo.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD9485F),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await store.deleteProject(project);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          children: <Widget>[
            _AnimProMark(),
            SizedBox(width: 10),
            Text(
              'AnimPro',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Ajuda',
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'AnimPro',
              applicationVersion: '1.0.0',
              children: const <Widget>[
                Text('Desenha, cria frames e experimenta poses de animação 2D.'),
              ],
            ),
            icon: const Icon(Icons.help_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final projects = store.projects;
          return CustomScrollView(
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Vamos animar?',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Transforma os teus desenhos em movimento.',
                        style: TextStyle(color: Colors.white.withOpacity(.62)),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: FilledButton.icon(
                          onPressed: () => _newProject(context),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 25),
                          label: const Text(
                            'Novo Projeto',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6757F5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'Projetos recentes',
                              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            '${projects.length} projeto(s)',
                            style: TextStyle(color: Colors.white.withOpacity(.5)),
                          ),
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
                      padding: const EdgeInsets.fromLTRB(34, 0, 34, 90),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            height: 104,
                            width: 104,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2030),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: const Icon(
                              Icons.draw_rounded,
                              size: 48,
                              color: Color(0xFF8F83FF),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'O teu primeiro projeto começa aqui',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Cria um projeto e desenha o primeiro frame.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withOpacity(.58)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
                          onTap: () => _openProject(context, project),
                          onAction: (action) async {
                            switch (action) {
                              case 'rename':
                                await _renameProject(context, project);
                              case 'duplicate':
                                await store.duplicateProject(project);
                              case 'delete':
                                await _deleteProject(context, project);
                            }
                          },
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

class _AnimProMark extends StatelessWidget {
  const _AnimProMark();

  @override
  Widget build(BuildContext context) => Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFF6555F5), Color(0xFF8D50E8)],
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
    final frame = project.frames.isEmpty ? FrameModel.blank() : project.frames.first;
    final date = project.updatedAt;
    final dateLabel =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  CustomPaint(painter: _ThumbnailPainter(frame)),
                  Positioned(
                    top: 7,
                    right: 7,
                    child: PopupMenuButton<String>(
                      tooltip: 'Opções do projeto',
                      color: const Color(0xFF25283A),
                      onSelected: onAction,
                      itemBuilder: (_) => const <PopupMenuEntry<String>>[
                        PopupMenuItem(value: 'rename', child: Text('Renomear')),
                        PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
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
                      child: Text(
                        '${project.frames.length} frames',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    project.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: <Widget>[
                      Icon(Icons.access_time, size: 13, color: Colors.white.withOpacity(.5)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          dateLabel,
                          maxLines: 1,
                          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(.55)),
                        ),
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

/// Pré-visualização simples dos traços na grelha de projetos.
class _ThumbnailPainter extends CustomPainter {
  _ThumbnailPainter(this.frame);
  final FrameModel frame;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFF292D48);
    canvas.drawRect(Offset.zero & size, backgroundPaint);
    final allPoints = frame.layers.expand((layer) => layer.strokes).expand((s) => s.points).toList();
    if (allPoints.isEmpty) {
      final iconPaint = Paint()..color = const Color(0xFF8D86FF).withOpacity(.8);
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), 23, iconPaint);
      final linePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(
        Path()
          ..moveTo(size.width / 2 - 8, size.height / 2 - 12)
          ..lineTo(size.width / 2 + 11, size.height / 2)
          ..lineTo(size.width / 2 - 8, size.height / 2 + 12)
          ..close(),
        linePaint,
      );
      return;
    }

    var left = allPoints.first.dx;
    var right = left;
    var top = allPoints.first.dy;
    var bottom = top;
    for (final point in allPoints) {
      left = math.min(left, point.dx);
      right = math.max(right, point.dx);
      top = math.min(top, point.dy);
      bottom = math.max(bottom, point.dy);
    }
    final w = math.max(right - left, 1.0);
    final h = math.max(bottom - top, 1.0);
    final scale = math.min((size.width - 24) / w, (size.height - 24) / h);
    final dx = (size.width - w * scale) / 2 - left * scale;
    final dy = (size.height - h * scale) / 2 - top * scale;

    for (final layer in frame.layers.reversed) {
      if (!layer.visible) continue;
      for (final stroke in layer.strokes) {
        if (stroke.points.isEmpty) continue;
        final paint = Paint()
          ..color = Color(stroke.color)
          ..strokeWidth = math.max(1.0, stroke.width * scale)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;
        final path = Path()
          ..moveTo(stroke.points.first.dx * scale + dx, stroke.points.first.dy * scale + dy);
        for (final point in stroke.points.skip(1)) {
          path.lineTo(point.dx * scale + dx, point.dy * scale + dy);
        }
        if (stroke.points.length == 1) {
          canvas.drawCircle(
            Offset(stroke.points.first.dx * scale + dx, stroke.points.first.dy * scale + dy),
            math.max(1.5, stroke.width * scale / 2),
            paint..style = PaintingStyle.fill,
          );
        } else {
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ThumbnailPainter oldDelegate) => oldDelegate.frame != frame;
}
