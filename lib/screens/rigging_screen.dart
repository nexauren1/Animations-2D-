import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/project_model.dart';

/// Ferramenta de rigging leve. Os seis controlos arrastáveis deslocam também
/// os pontos próximos do traço, com influência decrescente pela distância.
class RiggingScreen extends StatefulWidget {
  const RiggingScreen({
    required this.frame,
    required this.onSavePose,
    super.key,
  });

  final FrameModel frame;
  final ValueChanged<FrameModel> onSavePose;

  @override
  State<RiggingScreen> createState() => _RiggingScreenState();
}

class _RiggingScreenState extends State<RiggingScreen> {
  late final FrameModel _baseFrame;
  late FrameModel _posedFrame;
  late final Rect _bounds;
  late final List<Offset> _baseRigPoints;
  late List<Offset> _rigPoints;
  int? _draggingIndex;
  Offset _dragStartModel = Offset.zero;
  Size _canvasSize = Size.zero;

  static const List<String> _labels = <String>[
    'Cabeça',
    'Mão E',
    'Mão D',
    'Pé E',
    'Pé D',
    'Corpo',
  ];

  @override
  void initState() {
    super.initState();
    _baseFrame = widget.frame.copy();
    _posedFrame = _baseFrame.copy();
    _bounds = _drawingBounds(_baseFrame);
    _baseRigPoints = _createRigPoints(_bounds);
    _rigPoints = List<Offset>.from(_baseRigPoints);
  }

  List<Offset> _allPoints(FrameModel frame) => frame.layers
      .expand((layer) => layer.strokes)
      .expand((stroke) => stroke.points)
      .toList();

  Rect _drawingBounds(FrameModel frame) {
    final points = _allPoints(frame);
    if (points.isEmpty) return const Rect.fromLTWH(0, 0, 320, 240);
    var left = points.first.dx;
    var right = left;
    var top = points.first.dy;
    var bottom = top;
    for (final point in points) {
      left = math.min(left, point.dx);
      right = math.max(right, point.dx);
      top = math.min(top, point.dy);
      bottom = math.max(bottom, point.dy);
    }
    final width = math.max(right - left, 80.0);
    final height = math.max(bottom - top, 80.0);
    final centerX = (left + right) / 2;
    final centerY = (top + bottom) / 2;
    return Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: width,
      height: height,
    );
  }

  List<Offset> _createRigPoints(Rect rect) {
    final w = rect.width;
    final h = rect.height;
    final centerX = rect.center.dx;
    return <Offset>[
      Offset(centerX, rect.top + h * .14), // Cabeça
      Offset(rect.left + w * .12, rect.top + h * .40), // Mão esquerda
      Offset(rect.right - w * .12, rect.top + h * .40), // Mão direita
      Offset(rect.left + w * .27, rect.bottom - h * .05), // Pé esquerdo
      Offset(rect.right - w * .27, rect.bottom - h * .05), // Pé direito
      Offset(centerX, rect.top + h * .56), // Corpo
    ];
  }

  void _startDrag(Offset viewPosition, _CanvasTransform transform) {
    var closestIndex = -1;
    var closestDistance = 30.0;
    for (var index = 0; index < _rigPoints.length; index++) {
      final viewPoint = transform.toView(_rigPoints[index]);
      final distance = (viewPosition - viewPoint).distance;
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = index;
      }
    }
    if (closestIndex == -1) return;
    setState(() {
      _draggingIndex = closestIndex;
      _dragStartModel = _rigPoints[closestIndex];
    });
  }

  void _updateDrag(Offset viewPosition, _CanvasTransform transform) {
    final index = _draggingIndex;
    if (index == null) return;
    final newModelPosition = transform.toModel(viewPosition);
    final delta = newModelPosition - _dragStartModel;
    final changedPoints = List<Offset>.from(_baseRigPoints);
    changedPoints[index] = newModelPosition;
    final radius = math.max(_bounds.width, _bounds.height) * .42;

    final changedFrame = _baseFrame.copy();
    for (final layer in changedFrame.layers) {
      for (var strokeIndex = 0; strokeIndex < layer.strokes.length; strokeIndex++) {
        final stroke = layer.strokes[strokeIndex];
        final moved = stroke.points.map((point) {
          final distance = (point - _baseRigPoints[index]).distance;
          if (distance >= radius) return point;
          final influence = math.pow(1 - distance / radius, 2).toDouble();
          return point + delta * influence;
        }).toList();
        layer.strokes[strokeIndex] = StrokeModel(
          points: moved,
          color: stroke.color,
          width: stroke.width,
        );
      }
    }

    setState(() {
      _rigPoints = changedPoints;
      _posedFrame = changedFrame;
    });
  }

  void _finishDrag() {
    if (_draggingIndex == null) return;
    setState(() => _draggingIndex = null);
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
            children: <Widget>[
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
              const SizedBox(height: 15),
              Row(
                children: <Widget>[
                  const Icon(Icons.hub_rounded, color: Color(0xFF30DDF2), size: 26),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Rigging',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Repor pose',
                    onPressed: () => setState(() {
                      _posedFrame = _baseFrame.copy();
                      _rigPoints = List<Offset>.from(_baseRigPoints);
                    }),
                    icon: const Icon(Icons.restart_alt_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Arrasta os seis pontos. Os traços próximos acompanham o movimento.',
                style: TextStyle(color: Colors.white.withOpacity(.58), fontSize: 12),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                    final transform = _CanvasTransform(_bounds, _canvasSize);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) => _startDrag(details.localPosition, transform),
                      onPanUpdate: (details) => _updateDrag(details.localPosition, transform),
                      onPanEnd: (_) => _finishDrag(),
                      onPanCancel: _finishDrag,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CustomPaint(
                          painter: _RiggingPainter(
                            frame: _posedFrame,
                            rigPoints: _rigPoints,
                            labels: _labels,
                            transform: transform,
                            activeIndex: _draggingIndex,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: List<Widget>.generate(
                  _labels.length,
                  (index) => Chip(
                    avatar: const CircleAvatar(
                      backgroundColor: Color(0xFF27D6E9),
                      radius: 5,
                    ),
                    label: Text(_labels[index], style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFF202638),
                    side: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 49,
                child: FilledButton.icon(
                  onPressed: _savePose,
                  icon: const Icon(Icons.add_to_photos_outlined),
                  label: const Text(
                    'Guardar pose como novo frame',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF168CA8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CanvasTransform {
  _CanvasTransform(this.bounds, this.size) {
    final safeWidth = math.max(bounds.width, 1.0);
    final safeHeight = math.max(bounds.height, 1.0);
    final availableWidth = math.max(size.width - 48, 1.0);
    final availableHeight = math.max(size.height - 48, 1.0);
    scale = math.min(availableWidth / safeWidth, availableHeight / safeHeight);
    translation = Offset(
      (size.width - bounds.width * scale) / 2 - bounds.left * scale,
      (size.height - bounds.height * scale) / 2 - bounds.top * scale,
    );
  }

  final Rect bounds;
  final Size size;
  late final double scale;
  late final Offset translation;

  Offset toView(Offset point) => Offset(
        point.dx * scale + translation.dx,
        point.dy * scale + translation.dy,
      );

  Offset toModel(Offset point) => Offset(
        (point.dx - translation.dx) / scale,
        (point.dy - translation.dy) / scale,
      );
}

class _RiggingPainter extends CustomPainter {
  _RiggingPainter({
    required this.frame,
    required this.rigPoints,
    required this.labels,
    required this.transform,
    required this.activeIndex,
  });

  final FrameModel frame;
  final List<Offset> rigPoints;
  final List<String> labels;
  final _CanvasTransform transform;
  final int? activeIndex;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF8FAFF),
    );

    final gridPaint = Paint()
      ..color = const Color(0xFFE9ECF4)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
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
          canvas.drawCircle(
            transform.toView(stroke.points.first),
            paint.strokeWidth / 2,
            paint..style = PaintingStyle.fill,
          );
        } else {
          final path = Path()..moveTo(
              transform.toView(stroke.points.first).dx,
              transform.toView(stroke.points.first).dy,
            );
          for (final point in stroke.points.skip(1)) {
            final viewPoint = transform.toView(point);
            path.lineTo(viewPoint.dx, viewPoint.dy);
          }
          canvas.drawPath(path, paint);
        }
      }
    }

    final skeletonPaint = Paint()
      ..color = const Color(0xFF16BFD4).withOpacity(.8)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final head = transform.toView(rigPoints[0]);
    final leftHand = transform.toView(rigPoints[1]);
    final rightHand = transform.toView(rigPoints[2]);
    final leftFoot = transform.toView(rigPoints[3]);
    final rightFoot = transform.toView(rigPoints[4]);
    final body = transform.toView(rigPoints[5]);
    canvas.drawLine(head, body, skeletonPaint);
    canvas.drawLine(body, leftHand, skeletonPaint);
    canvas.drawLine(body, rightHand, skeletonPaint);
    canvas.drawLine(body, leftFoot, skeletonPaint);
    canvas.drawLine(body, rightFoot, skeletonPaint);

    for (var index = 0; index < rigPoints.length; index++) {
      final center = transform.toView(rigPoints[index]);
      final isActive = index == activeIndex;
      canvas.drawCircle(
        center,
        isActive ? 12 : 10,
        Paint()..color = const Color(0xFF15CFE6),
      );
      canvas.drawCircle(
        center,
        isActive ? 7 : 5,
        Paint()..color = Colors.white,
      );
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[index],
          style: const TextStyle(
            color: Color(0xFF087D94),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 70);
      textPainter.paint(canvas, center + const Offset(11, -18));
    }
  }

  @override
  bool shouldRepaint(covariant _RiggingPainter oldDelegate) => true;
}
