import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/project_model.dart';
import '../services/template_catalog.dart';

/// Gallery of editable demo animations. The previews are drawn from the same
/// vector frames that will be copied into the user's project.
class TemplateGalleryScreen extends StatelessWidget {
  const TemplateGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final templates = TemplateCatalog.all;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projetos prontos', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF342C70), Color(0xFF25233E), Color(0xFF172A39)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(.08)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_rounded, color: Color(0xFFB5A8FF), size: 30),
                SizedBox(height: 12),
                Text('Começa com movimento, não com uma página vazia.',
                    style: TextStyle(fontSize: 20, height: 1.15, fontWeight: FontWeight.w900)),
                SizedBox(height: 7),
                Text('Cada exemplo inclui frames editáveis. Abre-o, estuda as poses e transforma-o na tua própria animação.',
                    style: TextStyle(color: Colors.white70, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final template in templates) ...[
            _TemplateCard(
              template: template,
              onUse: () => Navigator.of(context).pop(template),
            ),
            const SizedBox(height: 14),
          ],
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF171A28),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_outlined, color: Color(0xFFB5A8FF)),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Dica: usa a linha temporal e a sobreposição de frames para comparar as poses.',
                      style: TextStyle(color: Colors.white70, height: 1.35)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onUse});
  final AnimationTemplate template;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final tint = Color(template.tint);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF191C2B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 176,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TemplateAnimationPreview(template: template),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xCC111321),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(.14)),
                    ),
                    child: Text(template.tag,
                        style: TextStyle(color: tint, fontSize: 9, letterSpacing: 1.1, fontWeight: FontWeight.w900)),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xCC111321),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${template.frames().length} frames · ${template.fps} FPS',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(template.description,
                    style: TextStyle(color: Colors.white.withOpacity(.64), height: 1.3)),
                const SizedBox(height: 13),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onUse,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Abrir e editar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: tint.withOpacity(.18),
                      foregroundColor: tint,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                        side: BorderSide(color: tint.withOpacity(.35)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TemplateAnimationPreview extends StatefulWidget {
  const TemplateAnimationPreview({required this.template, super.key, this.borderRadius = 0});
  final AnimationTemplate template;
  final double borderRadius;

  @override
  State<TemplateAnimationPreview> createState() => _TemplateAnimationPreviewState();
}

class _TemplateAnimationPreviewState extends State<TemplateAnimationPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<FrameModel> _frames;

  @override
  void initState() {
    super.initState();
    _frames = widget.template.createFrames();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_frames.length * 1000 ~/ widget.template.fps).clamp(600, 1800)),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final index = (_controller.value * _frames.length).floor().clamp(0, _frames.length - 1);
          return CustomPaint(
            painter: _TemplateFramePainter(_frames[index], Color(widget.template.tint)),
            child: const SizedBox.expand(),
          );
        },
      );
}

class _TemplateFramePainter extends CustomPainter {
  _TemplateFramePainter(this.frame, this.tint);
  final FrameModel frame;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF272A41), Color(0xFF151725)],
    ).createShader(bounds));
    // Keep the stage proportions intact; stretching a portrait drawing into a
    // landscape card made circles oval and characters look amateurish.
    final scale = math.min(size.width / 320, size.height / 420)
        .clamp(0.05, 2.0).toDouble();
    canvas.save();
    canvas.translate((size.width - 320 * scale) / 2, (size.height - 420 * scale) / 2);
    canvas.scale(scale, scale);
    final stage = RRect.fromRectAndRadius(
      const Rect.fromLTWH(18, 18, 284, 384),
      const Radius.circular(13),
    );
    canvas.drawRRect(
      stage,
      Paint()
        ..color = const Color(0xFF202337)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(
      stage,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF30334D), Color(0xFF171A2A)],
        ).createShader(const Rect.fromLTWH(18, 18, 284, 384)),
    );
    canvas.drawRRect(
      stage,
      Paint()
        ..color = Colors.white.withOpacity(.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final step = 24.0;
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(.035)
      ..strokeWidth = .7;
    for (var x = 30.0; x <= 294; x += step) {
      canvas.drawLine(Offset(x, 28), Offset(x, 392), gridPaint);
    }
    for (var y = 30.0; y <= 390; y += step) {
      canvas.drawLine(Offset(24, y), Offset(296, y), gridPaint);
    }
    for (final layer in frame.layers.reversed) {
      if (!layer.visible) continue;
      for (final stroke in layer.strokes) {
        if (stroke.points.isEmpty) continue;
        final color = Color(stroke.color);
        final paint = Paint()
          ..color = color
          ..strokeWidth = stroke.width.clamp(1.0, 8.0).toDouble()
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;
        final points = stroke.points;
        if (stroke.kind == 'ellipse' && points.length >= 2) {
          canvas.drawOval(Rect.fromPoints(points.first, points.last), paint);
        } else if (stroke.kind == 'rectangle' && points.length >= 2) {
          canvas.drawRect(Rect.fromPoints(points.first, points.last), paint);
        } else if (points.length == 1) {
          canvas.drawCircle(points.first, paint.strokeWidth / 2, paint..style = PaintingStyle.fill);
        } else {
          final path = Path()..moveTo(points.first.dx, points.first.dy);
          for (final point in points.skip(1)) {
            path.lineTo(point.dx, point.dy);
          }
          canvas.drawPath(path, paint);
        }
      }
    }
    canvas.restore();
    final marker = Paint()..color = tint.withOpacity(.75);
    canvas.drawCircle(Offset(size.width - 12, 12), 3.5, marker);
  }

  @override
  bool shouldRepaint(covariant _TemplateFramePainter oldDelegate) =>
      oldDelegate.frame.uid != frame.uid || oldDelegate.tint != tint;
}
