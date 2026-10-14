import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/project_model.dart';

/// Rigging simples com seis controlos e deformação gradual dos pontos próximos.
class RiggingScreen extends StatefulWidget {
  const RiggingScreen({required this.frame, required this.onSavePose, super.key});
  final FrameModel frame;
  final ValueChanged<FrameModel> onSavePose;

  @override
  State<RiggingScreen> createState() => _RiggingScreenState();
}

class _RiggingScreenState extends State<RiggingScreen> {
  static const _labels = <String>['Cabeça', 'Mão E', 'Mão D', 'Pé E', 'Pé D', 'Corpo'];
  late final FrameModel _baseFrame;
  late FrameModel _posedFrame;
  late final Rect _bounds;
  late final List<Offset> _basePoints;
  late List<Offset> _rigPoints;
  int? _dragIndex;
  Offset _dragStart = Offset.zero;

  @override
  void initState() {
    super.initState();
    _baseFrame = widget.frame.copy();
    _posedFrame = _baseFrame.copy();
    _bounds = _getBounds(_baseFrame);
    _basePoints = _createPoints(_bounds);
    _rigPoints = List<Offset>.from(_basePoints);
  }

  List<Offset> _pointsOf(FrameModel frame) => frame.layers
      .expand((layer) => layer.strokes)
      .expand((stroke) => stroke.points)
      .toList();

  Rect _getBounds(FrameModel frame) {
    final points = _pointsOf(frame);
    if (points.isEmpty) return const Rect.fromLTWH(0, 0, 320, 240);
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
    final double width = math.max(right - left, 80.0).toDouble();
    final double height = math.max(bottom - top, 80.0).toDouble();
    return Rect.fromCenter(
      center: Offset((left + right) / 2, (top + bottom) / 2),
      width: width,
      height: height,
    );
  }

  List<Offset> _createPoints(Rect r) {
    final w = r.width;
    final h = r.height;
    final cx = r.center.dx;
    return <Offset>[
      Offset(cx, r.top + h * .14),
      Offset(r.left + w * .12, r.top + h * .40),
      Offset(r.right - w * .12, r.top + h * .40),
      Offset(r.left + w * .27, r.bottom - h * .05),
      Offset(r.right - w * .27, r.bottom - h * .05),
      Offset(cx, r.top + h * .56),
    ];
  }

  void _startDrag(Offset viewPosition, _Transform transform) {
    var closest = -1;
    double distance = 30;
    for (var i = 0; i < _rigPoints.length; i++) {
      final currentDistance = (transform.toView(_rigPoints[i]) - viewPosition).distance;
      if (currentDistance < distance) {
        closest = i;
        distance = currentDistance;
      }
    }
    if (closest == -1) return;
    setState(() {
      _dragIndex = closest;
      _dragStart = _basePoints[closest];
    });
  }

  void _updateDrag(Offset viewPosition, _Transform transform) {
    final index = _dragIndex;
    if (index == null) return;
    final movedControl = transform.toModel(viewPosition);
    final delta = movedControl - _dragStart;
    final radius = math.max(_bounds.width, _bounds.height).toDouble() * .42;
    final newRig = List<Offset>.from(_basePoints)..[index] = movedControl;
    final alteredFrame = _baseFrame.copy();

    for (final layer in alteredFrame.layers) {
      for (var i = 0; i < layer.strokes.length; i++) {
        final stroke = layer.strokes[i];
        final movedPoints = stroke.points.map((point) {
          final d = (point - _basePoints[index]).distance;
          if (d >= radius) return point;
          final double weight = math.pow(1 - d / radius, 2).toDouble();
          return point + delta * weight;
        }).toList();
        layer.strokes[i] = StrokeModel(
          points: movedPoints,
          color: stroke.color,
          width: stroke.width,
        );
      }
    }

    setState(() {
      _rigPoints = newRig;
      _posedFrame = alteredFrame;
    });
  }

  void _endDrag() {
    if (_dragIndex == null) return;
    setState(() => _dragIndex = null);
  }

  void _resetPose() {
    setState(() {
      _posedFrame = _baseFrame.copy();
      _rigPoints = List<Offset>.from(_basePoints);
      _dragIndex = null;
    });
  }

  void _savePose() {
    widget.onSavePose(_posedFrame.copy());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * .78,
      decoration: const BoxDecoration(
        color: Color(0xFF141725),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.hub_rounded, color: Color(0xFF30DDF2), size: 26),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text('Rigging',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    tooltip: 'Repor pose',
                    onPressed: _resetPose,
                    icon: const Icon(Icons.restart_alt_rounded),
                  ),
                ],
              ),
              Text(
                'Arrasta os seis pontos. Os traços próximos acompanham o movimento.',
                style: TextStyle(color: Colors.white.withOpacity(.58), fontSize: 12),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    final transform = _Transform(_bounds, size);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) => _startDrag(details.localPosition, transform),
                      onPanUpdate: (details) => _updateDrag(details.localPosition, transform),
                      onPanEnd: (_) => _endDrag(),
                      onPanCancel: _endDrag,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CustomPaint(
                          painter: _RiggingPainter(
                            frame: _posedFrame,
                            controls: _rigPoints,
                            labels: _labels,
                            transform: transform,
                            activeIndex: _dragIndex,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: _labels.map((label) => Chip(
                  avatar: const CircleAvatar(
                    radius: 5,
                    backgroundColor: Color(0xFF27D6E9),
                  ),
                  label: Text(label, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: const Color(0xFF202638),
                  side: BorderSide.none,
                )).toList(),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 49,
                child: FilledButton.icon(
                  onPressed: _savePose,
                  icon: const Icon(Icons.add_to_photos_outlined),
                  label: const Text('Guardar pose como novo frame',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF168CA8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Transform {
  _Transform(this.bounds, this.size) {
    final double safeW = math.max(bounds.width, 1.0).toDouble();
    final double safeH = math.max(bounds.height, 1.0).toDouble();
    final double availW = math.max(size.width - 48, 1.0).toDouble();
    final double availH = math.max(size.height - 48, 1.0).toDouble();
    scale = math.min(availW / safeW, availH / safeH).toDouble();
    translation = Offset(
      (size.width - bounds.width * scale) / 2 - bounds.left * scale,
      (size.height - bounds.height * scale) / 2 - bounds.top * scale,
    );
  }

  final Rect bounds;
  final Size size;
  late final double scale;
  late final Offset translation;

  Offset toView(Offset p) => Offset(
        p.dx * scale + translation.dx,
        p.dy * scale + translation.dy,
      );

  Offset toModel(Offset p) => Offset(
        (p.dx - translation.dx) / scale,
        (p.dy - translation.dy) / scale,
      );
}

class _RiggingPainter extends CustomPainter {
  _RiggingPainter({
    required this.frame,
    required this.controls,
    required this.labels,
    required this.transform,
    required this.activeIndex,
  });

  final FrameModel frame;
  final List<Offset> controls;
  final List<String> labels;
  final _Transform transform;
  final int? activeIndex;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF8FAFF));
    final grid = Paint()..color = const Color(0xFFE9ECF4)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (final layer in frame.layers.reversed) {
      if (!layer.visible) continue;
      for (final stroke in layer.strokes) {
        if (stroke.points.isEmpty) continue;
        final paint = Paint()
          ..color = Color(stroke.color)
          ..strokeWidth = (stroke.width * transform.scale).clamp(1.0, 8.0).toDouble()
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;
        if (stroke.points.length == 1) {
          canvas.drawCircle(transform.toView(stroke.points.first),
              paint.strokeWidth / 2, paint..style = PaintingStyle.fill);
        } else {
          final first = transform.toView(stroke.points.first);
          final path = Path()..moveTo(first.dx, first.dy);
          for (final point in stroke.points.skip(1)) {
            final p = transform.toView(point);
            path.lineTo(p.dx, p.dy);
          }
          canvas.drawPath(path, paint);
        }
      }
    }

    final head = transform.toView(controls[0]);
    final leftHand = transform.toView(controls[1]);
    final rightHand = transform.toView(controls[2]);
    final leftFoot = transform.toView(controls[3]);
    final rightFoot = transform.toView(controls[4]);
    final body = transform.toView(controls[5]);
    final skeleton = Paint()
      ..color = const Color(0xFF16BFD4).withOpacity(.85)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(head, body, skeleton);
    canvas.drawLine(body, leftHand, skeleton);
    canvas.drawLine(body, rightHand, skeleton);
    canvas.drawLine(body, leftFoot, skeleton);
    canvas.drawLine(body, rightFoot, skeleton);

    for (var i = 0; i < controls.length; i++) {
      final center = transform.toView(controls[i]);
      canvas.drawCircle(center, i == activeIndex ? 12 : 10,
          Paint()..color = const Color(0xFF15CFE6));
      canvas.drawCircle(center, i == activeIndex ? 7 : 5, Paint()..color = Colors.white);
      final text = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Color(0xFF087D94),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 70);
      text.paint(canvas, center + const Offset(11, -18));
    }
  }

  @override
  bool shouldRepaint(covariant _RiggingPainter oldDelegate) => true;
}
