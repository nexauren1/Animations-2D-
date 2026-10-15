import 'dart:math' as math;
import 'dart:ui';

import '../models/project_model.dart';

/// Local, lightweight starter projects. Vector strokes instead of images keep
/// the initial download small while still giving users editable examples.
class AnimationTemplate {
  const AnimationTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.iconCodePoint,
    required this.tint,
    required this.fps,
    required this.frames,
    this.tag = 'INICIANTE',
  });

  final String id;
  final String title;
  final String description;
  final int iconCodePoint;
  final int tint;
  final int fps;
  final String tag;
  final List<FrameModel> Function() frames;

  List<FrameModel> createFrames() => frames().map((frame) => frame.copy()).toList();
}

class TemplateCatalog {
  TemplateCatalog._();

  static final List<AnimationTemplate> all = <AnimationTemplate>[
    AnimationTemplate(
      id: 'bounce-ball',
      title: 'Bola a saltar',
      description: 'Aprende timing, squash & stretch e arcos de movimento.',
      iconCodePoint: 0xe1d5,
      tint: 0xFFFF9D42,
      fps: 12,
      tag: 'FUNDAMENTOS',
      frames: _bouncingBall,
    ),
    AnimationTemplate(
      id: 'blooming-flower',
      title: 'Flor a florescer',
      description: 'Pratica poses-chave, repetição e crescimento gradual.',
      iconCodePoint: 0xe3a5,
      tint: 0xFF70D6A5,
      fps: 12,
      frames: _bloomingFlower,
    ),
    AnimationTemplate(
      id: 'rocket-launch',
      title: 'Foguetão a descolar',
      description: 'Uma pequena sequência com antecipação, movimento e chama.',
      iconCodePoint: 0xe195,
      tint: 0xFF9F8BFF,
      fps: 24,
      tag: 'MOVIMENTO',
      frames: _rocketLaunch,
    ),
  ];

  static List<FrameModel> _bouncingBall() {
    const heights = <double>[300, 245, 178, 128, 178, 245, 300, 322];
    return List<FrameModel>.generate(heights.length, (index) {
      final y = heights[index];
      final impact = index == 0 || index == 6 || index == 7;
      final width = impact ? 42.0 : 34.0;
      final height = impact ? 28.0 : (index == 3 ? 42.0 : 34.0);
      final cx = 160.0 + math.sin(index * math.pi / 4) * 9;
      final layers = _layers();
      final guide = layers[2];
      final colour = layers[1];
      final line = layers[0];
      guide.strokes.add(_s(
        const <Offset>[Offset(38, 350), Offset(282, 350)],
        color: 0xFF454B68, width: 2,
      ));
      final arc = <Offset>[];
      for (var n = 0; n <= 12; n++) {
        final t = n / 12;
        arc.add(Offset(92 + t * 136, 298 - 190 * math.sin(t * math.pi)));
      }
      guide.strokes.add(_s(arc, color: 0xFF514B7D, width: 1.6));
      colour.strokes.add(_s(
        <Offset>[Offset(cx - width / 2, y - height / 2), Offset(cx + width / 2, y + height / 2)],
        color: 0xFFFF9D42, width: 3, kind: 'ellipse',
      ));
      line.strokes.add(_s(
        <Offset>[Offset(cx - width / 2 + 9, y - height / 2 + 8), Offset(cx - width / 2 + 15, y - height / 2 + 14)],
        color: 0xFFFFE3AE, width: 3,
      ));
      final shadowWidth = 38 + (y - 120).clamp(0, 220) * .45;
      guide.strokes.add(_s(
        <Offset>[Offset(160 - shadowWidth / 2, 344), Offset(160 + shadowWidth / 2, 356)],
        color: 0xFF454B68, width: 1.5, kind: 'ellipse',
      ));
      return FrameModel(layers: layers);
    });
  }

  static List<FrameModel> _bloomingFlower() {
    const petalScales = <double>[.28, .45, .68, .88, 1, .88];
    return List<FrameModel>.generate(petalScales.length, (index) {
      final scale = petalScales[index];
      final layers = _layers();
      final line = layers[0];
      final colour = layers[1];
      final guide = layers[2];
      guide.strokes.add(_s(
        const <Offset>[Offset(160, 355), Offset(160, 223)],
        color: 0xFF52B788, width: 7,
      ));
      guide.strokes.add(_s(
        const <Offset>[Offset(159, 305), Offset(129, 277), Offset(112, 283)],
        color: 0xFF70D6A5, width: 5,
      ));
      guide.strokes.add(_s(
        const <Offset>[Offset(161, 326), Offset(191, 299), Offset(207, 303)],
        color: 0xFF70D6A5, width: 5,
      ));
      const centre = Offset(160, 202);
      const petalDirections = <double>[0, math.pi / 3, 2 * math.pi / 3, math.pi, 4 * math.pi / 3, 5 * math.pi / 3];
      for (var p = 0; p < petalDirections.length; p++) {
        final angle = petalDirections[p];
        final radius = 27 * scale;
        final px = centre.dx + math.cos(angle) * radius;
        final py = centre.dy + math.sin(angle) * radius;
        final petalW = 28 * scale;
        final petalH = 35 * scale;
        colour.strokes.add(_s(
          <Offset>[Offset(px - petalW / 2, py - petalH / 2), Offset(px + petalW / 2, py + petalH / 2)],
          color: p.isEven ? 0xFFFF7BA2 : 0xFFFFA8C2,
          width: 3.2, kind: 'ellipse',
        ));
      }
      line.strokes.add(_s(
        const <Offset>[Offset(147, 189), Offset(153, 183)],
        color: 0xFFFFE5A1, width: 4,
      ));
      colour.strokes.add(_s(
        const <Offset>[Offset(148, 190), Offset(172, 214)],
        color: 0xFFFFD166, width: 4, kind: 'ellipse',
      ));
      guide.strokes.add(_s(
        const <Offset>[Offset(105, 365), Offset(215, 365)],
        color: 0xFF454B68, width: 2,
      ));
      return FrameModel(layers: layers);
    });
  }

  static List<FrameModel> _rocketLaunch() {
    const offsets = <double>[30, 22, 8, -12, -36, -66, -96, -124];
    return List<FrameModel>.generate(offsets.length, (index) {
      final lift = offsets[index];
      final x = 160.0 + math.sin(index * .6) * 5;
      final y = 205.0 + lift;
      final layers = _layers();
      final line = layers[0];
      final colour = layers[1];
      final guide = layers[2];
      guide.strokes.add(_s(
        const <Offset>[Offset(35, 354), Offset(285, 354)],
        color: 0xFF454B68, width: 2,
      ));
      for (var s = 0; s < 12; s++) {
        final sx = 47.0 + s * 20;
        final sy = 65.0 + (s % 4) * 29.0;
        guide.strokes.add(_s(
          <Offset>[Offset(sx, sy), Offset(sx + 2, sy + 2)],
          color: 0xFF77769C, width: 2,
        ));
      }
      // Rocket body and nose are vector strokes, so every pose remains editable.
      colour.strokes.add(_s(
        <Offset>[
          Offset(x, y - 57), Offset(x + 22, y - 27),
          Offset(x + 19, y + 29), Offset(x - 19, y + 29),
          Offset(x - 22, y - 27), Offset(x, y - 57),
        ],
        color: 0xFF9F8BFF, width: 3, kind: 'pen',
      ));
      line.strokes.add(_s(
        <Offset>[Offset(x - 10, y - 5), Offset(x + 10, y + 15)],
        color: 0xFF7FD8F7, width: 3, kind: 'ellipse',
      ));
      colour.strokes.add(_s(
        <Offset>[Offset(x - 19, y + 13), Offset(x - 32, y + 34), Offset(x - 17, y + 30)],
        color: 0xFFFF9D42, width: 3,
      ));
      colour.strokes.add(_s(
        <Offset>[Offset(x + 19, y + 13), Offset(x + 32, y + 34), Offset(x + 17, y + 30)],
        color: 0xFFFF9D42, width: 3,
      ));
      final flame = 13.0 + (index % 3) * 7;
      colour.strokes.add(_s(
        <Offset>[Offset(x - 9, y + 29), Offset(x, y + 29 + flame), Offset(x + 9, y + 29)],
        color: index.isEven ? 0xFFFFD166 : 0xFFFF7B54, width: 3,
      ));
      return FrameModel(layers: layers);
    });
  }

  static List<LayerModel> _layers() => <LayerModel>[
        LayerModel(name: 'Contornos'),
        LayerModel(name: 'Cores'),
        LayerModel(name: 'Guias'),
      ];

  static StrokeModel _s(
    List<Offset> points, {
    required int color,
    double width = 3,
    String kind = 'pen',
  }) =>
      StrokeModel(
        points: points,
        color: color,
        width: width,
        kind: kind,
        brushStyle: 'tinta',
      );
}
