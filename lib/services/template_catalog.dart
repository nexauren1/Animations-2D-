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
    AnimationTemplate(
      id: 'pendulum-swing',
      title: 'Pêndulo em movimento',
      description: 'Estuda arcos, aceleração e desaceleração com uma composição limpa.',
      iconCodePoint: 0xe532,
      tint: 0xFF65D6E8,
      fps: 12,
      tag: 'FÍSICA',
      frames: _pendulumSwing,
    ),
    AnimationTemplate(
      id: 'blinking-face',
      title: 'Personagem a piscar',
      description: 'Uma personagem expressiva com olhos e boca que mudam entre poses.',
      iconCodePoint: 0xe87c,
      tint: 0xFFFF8FB1,
      fps: 8,
      tag: 'PERSONAGEM',
      frames: _blinkingFace,
    ),
    AnimationTemplate(
      id: 'comet-flight',
      title: 'Cometa veloz',
      description: 'Pratica trajetórias, rastos e ritmo numa animação curta.',
      iconCodePoint: 0xe3a4,
      tint: 0xFFFFC46B,
      fps: 12,
      tag: 'EFEITOS',
      frames: _cometFlight,
    ),
    AnimationTemplate(
      id: 'stickman-fight',
      title: 'Stickman: Combate Cinematográfico',
      description: 'Uma sequência de luta estilizada, frame a frame, com socos, esquivas, bloqueios, um pontapé aéreo e um final amigável. Todos os frames são editáveis.',
      iconCodePoint: 0xe91d,
      tint: 0xFFFFB15C,
      fps: 12,
      tag: 'ANIMAÇÃO DE AÇÃO',
      frames: _stickmanFight,
    ),
    AnimationTemplate(
      id: 'two-characters',
      title: 'Duas personagens a acenar',
      description: 'Duas personagens em camadas independentes para praticar poses, separar objetos e experimentar o rigging de cada personagem.',
      iconCodePoint: 0xe7ef,
      tint: 0xFF55CAD4,
      fps: 8,
      tag: 'MULTI-PERSONAGEM',
      frames: _twoCharacters,
    ),
    AnimationTemplate(
      id: 'house-door',
      title: 'Casa com porta a abrir',
      description: 'Uma pequena cena em camadas: paisagem, estrutura da casa e porta móvel para praticar movimento de objetos.',
      iconCodePoint: 0xe88a,
      tint: 0xFF80C783,
      fps: 8,
      tag: 'OBJETOS E CENÁRIOS',
      frames: _houseDoor,
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

  static List<FrameModel> _pendulumSwing() {
    const angles = <double>[-42, -30, -15, 0, 15, 30, 42, 30, 15, 0, -15, -30];
    return List<FrameModel>.generate(angles.length, (index) {
      final angle = angles[index] * math.pi / 180;
      const pivot = Offset(160, 76);
      const length = 178.0;
      final bob = Offset(
        pivot.dx + math.sin(angle) * length,
        pivot.dy + math.cos(angle) * length,
      );
      final layers = _layers();
      final guide = layers[2];
      final colour = layers[1];
      final line = layers[0];
      guide.strokes.add(_s([Offset(42, 76), Offset(278, 76)],
          color: 0xFF414963, width: 1.5));
      final arc = List<Offset>.generate(25, (i) {
        final a = (-45 + i * 90 / 24) * math.pi / 180;
        return Offset(pivot.dx + math.sin(a) * length,
            pivot.dy + math.cos(a) * length);
      });
      guide.strokes.add(_s(arc, color: 0xFF3B5268, width: 1.4));
      guide.strokes.add(_s([Offset(62, 372), Offset(258, 372)],
          color: 0xFF414963, width: 1.5));
      line.strokes.add(_s([pivot, bob], color: 0xFFB8C5DF, width: 3));
      line.strokes.add(_s([
        Offset(pivot.dx - 12, pivot.dy - 10),
        Offset(pivot.dx + 12, pivot.dy + 10),
      ], color: 0xFF65D6E8, width: 3));
      colour.strokes.add(_s([
        Offset(bob.dx - 24, bob.dy - 24),
        Offset(bob.dx + 24, bob.dy + 24),
      ], color: 0xFF65D6E8, width: 4, kind: 'ellipse'));
      line.strokes.add(_s([
        Offset(bob.dx - 9, bob.dy - 11),
        Offset(bob.dx - 3, bob.dy - 16),
      ], color: 0xFFE7FCFF, width: 3));
      return FrameModel(layers: layers);
    });
  }

  static List<FrameModel> _blinkingFace() {
    const closed = <bool>[false, false, true, false, false, false, true, false];
    return List<FrameModel>.generate(closed.length, (index) {
      final layers = _layers();
      final line = layers[0];
      final colour = layers[1];
      final guide = layers[2];
      const centre = Offset(160, 205);
      colour.strokes.add(_s([
        const Offset(94, 132), const Offset(226, 278),
      ], color: 0xFFFF8FB1, width: 4, kind: 'ellipse'));
      final eyeY = closed[index] ? 192.0 : 184.0;
      if (closed[index]) {
        line.strokes.add(_s([
          const Offset(121, 190), const Offset(137, 185), const Offset(151, 190),
        ], color: 0xFF26304A, width: 4));
        line.strokes.add(_s([
          const Offset(169, 190), const Offset(183, 185), const Offset(199, 190),
        ], color: 0xFF26304A, width: 4));
      } else {
        colour.strokes.add(_s([
          Offset(119, eyeY - 10), Offset(143, eyeY + 10),
        ], color: 0xFF65D6E8, width: 3.5, kind: 'ellipse'));
        colour.strokes.add(_s([
          Offset(177, eyeY - 10), Offset(201, eyeY + 10),
        ], color: 0xFF65D6E8, width: 3.5, kind: 'ellipse'));
        line.strokes.add(_s([
          Offset(131, eyeY - 2), Offset(131, eyeY + 2),
        ], color: 0xFF26304A, width: 4));
        line.strokes.add(_s([
          Offset(189, eyeY - 2), Offset(189, eyeY + 2),
        ], color: 0xFF26304A, width: 4));
      }
      line.strokes.add(_s([
        const Offset(148, 222), centre, const Offset(172, 222),
      ], color: 0xFF26304A, width: 3));
      guide.strokes.add(_s([
        const Offset(112, 304), const Offset(208, 304),
      ], color: 0xFF454B68, width: 2));
      return FrameModel(layers: layers);
    });
  }

  static List<FrameModel> _cometFlight() {
    const positions = <Offset>[
      Offset(70, 285), Offset(91, 264), Offset(116, 244), Offset(144, 218),
      Offset(174, 194), Offset(207, 167), Offset(235, 144), Offset(260, 120),
    ];
    return List<FrameModel>.generate(positions.length, (index) {
      final head = positions[index];
      final layers = _layers();
      final guide = layers[2];
      final colour = layers[1];
      final line = layers[0];
      final trail = <Offset>[];
      for (var t = 0; t < 8; t++) {
        final fraction = t / 7;
        trail.add(Offset(head.dx - 92 * fraction, head.dy + 64 * fraction));
      }
      guide.strokes.add(_s(trail, color: 0xFF55527E, width: 2));
      for (var s = 0; s < 12; s++) {
        final sx = 34.0 + ((s * 47) % 250);
        final sy = 45.0 + ((s * 61) % 315);
        guide.strokes.add(_s([
          Offset(sx, sy), Offset(sx + 2, sy + 2),
        ], color: 0xFF77769C, width: 1.5));
      }
      final star = List<Offset>.generate(11, (i) {
        final angle = -math.pi / 2 + i * math.pi / 5;
        final radius = i.isEven ? 21.0 : 9.0;
        return Offset(head.dx + math.cos(angle) * radius,
            head.dy + math.sin(angle) * radius);
      });
      colour.strokes.add(_s([...star, star.first],
          color: 0xFFFFC46B, width: 3.5));
      line.strokes.add(_s([
        Offset(head.dx - 7, head.dy - 7),
        Offset(head.dx - 1, head.dy - 1),
      ], color: 0xFFFFF0C7, width: 3));
      return FrameModel(layers: layers);
    });
  }

  /// A friendly, non-graphic sparring sequence built entirely from editable vector strokes.
  static List<FrameModel> _stickmanFight() {
    const leftTravel = <double>[0, 4, 8, 16, 20, 12, 4, -7, -15, -12, -4, 0, 0, 0, 0, 0];
    const rightTravel = <double>[0, -2, -4, -6, -10, -18, -20, -10, 0, 6, 12, 3, 0, 0, 0, 0];
    const leftHead = <double>[148, 148, 146, 145, 157, 166, 149, 157, 142, 140, 151, 148, 148, 148, 148, 151];
    const rightHead = <double>[148, 148, 150, 154, 174, 171, 155, 151, 148, 155, 151, 148, 148, 148, 148, 151];

    return List<FrameModel>.generate(16, (index) {
      final layers = _layers();
      final line = layers[0];
      final colour = layers[1];
      final guide = layers[2];
      const cyan = 0xFF25B8C7;
      const orange = 0xFFFFA34F;
      const ink = 0xFF24283B;
      const yellow = 0xFFFFD166;

      void addLine(
        List<Offset> points, {
        required int color,
        double width = 3,
        String brushStyle = 'tinta',
        String kind = 'pen',
      }) {
        line.strokes.add(StrokeModel(
          points: points,
          color: color,
          width: width,
          kind: kind,
          brushStyle: brushStyle,
        ));
      }

      void addOval(Offset centre, double rx, double ry, int color) {
        colour.strokes.add(_s(
          <Offset>[
            Offset(centre.dx - rx, centre.dy - ry),
            Offset(centre.dx + rx, centre.dy + ry),
          ],
          color: color,
          width: 3,
          kind: 'ellipse',
        ));
      }

      void fighter({
        required double x,
        required double headY,
        required double direction,
        required int accent,
        double lean = 0,
        bool punch = false,
        bool block = false,
        bool kick = false,
        bool crouch = false,
        bool recoil = false,
      }) {
        final head = Offset(x + lean * .2, headY);
        final shoulder = Offset(x + lean, headY + (crouch ? 19 : 16));
        final hip = Offset(x + lean * .65, headY + (crouch ? 73 : 82));
        addOval(head, 10, 11, accent);
        addLine(
          <Offset>[Offset(head.dx, head.dy + 10), shoulder],
          color: accent,
          width: 3.2,
        );
        addLine(<Offset>[shoulder, hip], color: accent, width: 4);

        final backShoulder = Offset(shoulder.dx - direction * 10, shoulder.dy + 2);
        final frontShoulder = Offset(shoulder.dx + direction * 10, shoulder.dy + 2);
        if (punch) {
          addLine(
            <Offset>[
              backShoulder,
              Offset(x - direction * 23, headY + 37),
              Offset(x - direction * 28, headY + 48),
            ],
            color: accent,
            width: 3.2,
          );
          addLine(
            <Offset>[
              frontShoulder,
              Offset(x + direction * 29, headY + 26),
              Offset(x + direction * 83, headY + 23),
            ],
            color: accent,
            width: 4,
            brushStyle: 'brilho neon',
          );
          addOval(Offset(x + direction * 83, headY + 23), 4, 4, accent);
        } else if (block) {
          addLine(
            <Offset>[
              backShoulder,
              Offset(x - direction * 22, headY + 1),
              Offset(x - direction * 21, headY - 12),
            ],
            color: accent,
            width: 3.5,
          );
          addLine(
            <Offset>[
              frontShoulder,
              Offset(x + direction * 18, headY - 5),
              Offset(x + direction * 22, headY - 17),
            ],
            color: accent,
            width: 3.5,
          );
        } else {
          addLine(
            <Offset>[
              backShoulder,
              Offset(x - direction * 18, headY + 34),
              Offset(x - direction * 11, headY + 42),
            ],
            color: accent,
            width: 3.1,
          );
          addLine(
            <Offset>[
              frontShoulder,
              Offset(x + direction * 21, headY + 32),
              Offset(x + direction * 17, headY + 20),
            ],
            color: accent,
            width: 3.3,
          );
        }

        if (kick) {
          addLine(
            <Offset>[
              hip,
              Offset(x - direction * 19, hip.dy + 24),
              Offset(x - direction * 29, hip.dy + 45),
            ],
            color: accent,
            width: 3.5,
          );
          addLine(
            <Offset>[
              hip,
              Offset(x + direction * 28, hip.dy - 5),
              Offset(x + direction * 92, hip.dy - 17),
            ],
            color: accent,
            width: 4,
            brushStyle: 'rastro de movimento',
          );
        } else if (crouch) {
          addLine(
            <Offset>[hip, Offset(x - 17, hip.dy + 15), Offset(x - 30, hip.dy + 37)],
            color: accent,
            width: 3.5,
          );
          addLine(
            <Offset>[hip, Offset(x + direction * 19, hip.dy + 22), Offset(x + direction * 34, hip.dy + 34)],
            color: accent,
            width: 3.5,
          );
        } else if (recoil) {
          addLine(
            <Offset>[hip, Offset(x - direction * 24, hip.dy + 14), Offset(x - direction * 31, hip.dy + 34)],
            color: accent,
            width: 3.5,
          );
          addLine(
            <Offset>[hip, Offset(x + direction * 19, hip.dy + 19), Offset(x + direction * 29, hip.dy + 39)],
            color: accent,
            width: 3.5,
          );
        } else {
          addLine(
            <Offset>[hip, Offset(x - direction * 16, hip.dy + 28), Offset(x - direction * 22, hip.dy + 48)],
            color: accent,
            width: 3.5,
          );
          addLine(
            <Offset>[hip, Offset(x + direction * 17, hip.dy + 27), Offset(x + direction * 25, hip.dy + 48)],
            color: accent,
            width: 3.5,
          );
        }

        final eyeX = head.dx + direction * 4;
        addLine(
          <Offset>[Offset(eyeX, headY - 1), Offset(eyeX + direction * 2, headY + 1)],
          color: ink,
          width: 2.2,
        );
      }

      guide.strokes.add(_s(
        const <Offset>[Offset(28, 354), Offset(292, 354)],
        color: 0xFF8993AA,
        width: 1.8,
      ));
      guide.strokes.add(_s(
        const <Offset>[Offset(160, 44), Offset(160, 345)],
        color: 0xFF404760,
        width: 1.1,
      ));

      final leftX = 96.0 + leftTravel[index];
      final rightX = 224.0 + rightTravel[index];
      final leftPunch = index == 2 || index == 3;
      final rightDuck = index == 4 || index == 5;
      final rightPunch = index == 6 || index == 7;
      final leftKick = index == 9 || index == 10;
      final rightBlock = index == 9 || index == 10;
      final leftRecoil = index == 7 || index == 8;

      // Short speed lines and impact flashes give each pose a clear action beat.
      if (index == 2 || index == 3) {
        addLine(
          <Offset>[Offset(leftX - 20, 129), Offset(leftX - 44, 123)],
          color: cyan,
          width: 3,
          brushStyle: 'rastro de movimento',
        );
      }
      if (index == 6 || index == 7) {
        addLine(
          <Offset>[Offset(rightX + 18, 130), Offset(rightX + 42, 123)],
          color: orange,
          width: 3,
          brushStyle: 'rastro de movimento',
        );
      }
      if (index == 9 || index == 10) {
        addLine(
          <Offset>[Offset(leftX + 30, 234), Offset(leftX + 66, 218)],
          color: cyan,
          width: 4,
          brushStyle: 'luz energética',
        );
      }

      fighter(
        x: leftX,
        headY: leftHead[index],
        direction: 1,
        accent: cyan,
        lean: leftPunch ? 8 : (leftRecoil ? -7 : 0),
        punch: leftPunch,
        kick: leftKick,
        recoil: leftRecoil,
      );
      fighter(
        x: rightX,
        headY: rightHead[index],
        direction: -1,
        accent: orange,
        lean: rightPunch ? -8 : 0,
        punch: rightPunch,
        block: rightBlock,
        crouch: rightDuck,
      );

      if (index == 3 || index == 6 || index == 10) {
        final impactCentre = index == 3
            ? Offset(190, 168)
            : index == 6
                ? Offset(146, 169)
                : Offset(190, 230);
        final burst = List<Offset>.generate(17, (i) {
          final angle = -math.pi / 2 + i * math.pi / 8;
          final radius = i.isEven ? 22.0 : 10.0;
          return Offset(
            impactCentre.dx + math.cos(angle) * radius,
            impactCentre.dy + math.sin(angle) * radius,
          );
        });
        colour.strokes.add(StrokeModel(
          points: <Offset>[...burst, burst.first],
          color: yellow,
          width: 3.4,
          brushStyle: 'luz energética',
        ));
        addLine(
          <Offset>[Offset(impactCentre.dx - 27, impactCentre.dy), Offset(impactCentre.dx - 37, impactCentre.dy - 7)],
          color: yellow,
          width: 2.3,
          brushStyle: 'brilho neon',
        );
        addLine(
          <Offset>[Offset(impactCentre.dx + 27, impactCentre.dy), Offset(impactCentre.dx + 38, impactCentre.dy + 5)],
          color: yellow,
          width: 2.3,
          brushStyle: 'brilho neon',
        );
      }

      // The ending beat resets both fighters into a calm, friendly pose.
      if (index == 14 || index == 15) {
        addLine(
          <Offset>[Offset(leftX + 17, 180), Offset(leftX + 30, 178)],
          color: cyan,
          width: 3,
        );
        addLine(
          <Offset>[Offset(rightX - 17, 180), Offset(rightX - 30, 178)],
          color: orange,
          width: 3,
        );
      }

      return FrameModel(layers: layers);
    });
  }

  /// Two distinct characters are stored in two independent editable layers.
  static List<FrameModel> _twoCharacters() {
    const waveAngles = <double>[0, -10, -22, -10, 0, -10, -22, -10];
    return List<FrameModel>.generate(waveAngles.length, (index) {
      final wave = waveAngles[index] * math.pi / 180;
      final personA = LayerModel(name: 'Personagem A');
      final personB = LayerModel(name: 'Personagem B');
      final scenery = LayerModel(name: 'Cenário');
      final guides = LayerModel(name: 'Guias');
      const ink = 0xFF29334B;
      const teal = 0xFF25B8C7;
      const coral = 0xFFFF986C;
      const cream = 0xFFFFDFA6;

      void person(LayerModel layer, double x, double headY, int accent,
          {required bool waving, required double lean}) {
        final head = Offset(x + lean * .2, headY);
        final shoulder = Offset(x + lean, headY + 24);
        final hip = Offset(x + lean * .7, headY + 78);
        layer.strokes.add(_s([
          Offset(head.dx - 15, head.dy - 16),
          Offset(head.dx + 15, head.dy + 16),
        ], color: accent, width: 3.5, kind: 'ellipse'));
        layer.strokes.add(_s([
          Offset(head.dx - 5, head.dy - 1),
          Offset(head.dx - 2, head.dy + 2),
        ], color: ink, width: 2.6));
        layer.strokes.add(_s([
          Offset(head.dx + 4, head.dy - 1),
          Offset(head.dx + 7, head.dy + 2),
        ], color: ink, width: 2.6));
        layer.strokes.add(_s([
          Offset(head.dx - 5, head.dy + 8),
          Offset(head.dx, head.dy + 11),
          Offset(head.dx + 6, head.dy + 8),
        ], color: ink, width: 2.1));
        layer.strokes.add(_s([Offset(head.dx, head.dy + 15), shoulder],
            color: accent, width: 4));
        layer.strokes.add(_s([shoulder, hip], color: ink, width: 4));
        layer.strokes.add(_s([
          shoulder,
          Offset(x - 20, headY + 43),
          Offset(x - 24, headY + 59),
        ], color: accent, width: 3.3));
        if (waving) {
          final hand = Offset(
            x + 29 + math.cos(wave) * 7,
            headY + 25 + math.sin(wave) * 7,
          );
          layer.strokes.add(_s([
            shoulder,
            Offset(x + 15, headY + 10),
            hand,
          ], color: accent, width: 3.5));
          layer.strokes.add(_s([
            hand,
            Offset(hand.dx + 1, hand.dy - 8),
          ], color: accent, width: 2.4));
          layer.strokes.add(_s([
            hand,
            Offset(hand.dx + 7, hand.dy - 5),
          ], color: accent, width: 2.4));
        } else {
          layer.strokes.add(_s([
            shoulder,
            Offset(x + 20, headY + 42),
            Offset(x + 23, headY + 55),
          ], color: accent, width: 3.3));
        }
        layer.strokes.add(_s([
          hip,
          Offset(x - 14 + lean * .2, headY + 111),
          Offset(x - 20 + lean * .2, headY + 126),
        ], color: ink, width: 3.6));
        layer.strokes.add(_s([
          hip,
          Offset(x + 13 + lean * .2, headY + 110),
          Offset(x + 20 + lean * .2, headY + 125),
        ], color: ink, width: 3.6));
        layer.strokes.add(_s([
          Offset(x - 3, headY + 38),
          Offset(x + 4, headY + 46),
        ], color: cream, width: 2.5));
      }

      person(personA, 93, 145 + math.sin(index * math.pi / 2) * 2, teal,
          waving: true, lean: math.sin(index * math.pi / 2) * 2);
      person(personB, 226, 151 + math.sin((index + 1) * math.pi / 2) * 2, coral,
          waving: false, lean: math.cos(index * math.pi / 2) * 1.5);

      scenery.strokes.add(_s([
        const Offset(20, 353),
        const Offset(300, 353),
      ], color: 0xFF7C9A8C, width: 2));
      scenery.strokes.add(_s([
        const Offset(42, 353),
        const Offset(72, 329),
        const Offset(96, 353),
      ], color: 0xFF83C78D, width: 3));
      scenery.strokes.add(_s([
        const Offset(240, 353),
        const Offset(263, 331),
        const Offset(285, 353),
      ], color: 0xFF83C78D, width: 3));
      if (index % 2 == 0) {
        guides.strokes.add(_s([
          const Offset(124, 110),
          const Offset(132, 98),
          const Offset(143, 106),
        ], color: 0xFFFFD166, width: 2.6));
      }
      return FrameModel(layers: <LayerModel>[personA, personB, scenery, guides]);
    });
  }

  /// House geometry remains stationary while the door has its own transformable layer.
  static List<FrameModel> _houseDoor() {
    const doorWidths = <double>[29, 27, 23, 18, 13, 18, 23, 29];
    const doorDepths = <double>[0, 7, 14, 20, 25, 20, 14, 7];
    return List<FrameModel>.generate(doorWidths.length, (index) {
      final door = LayerModel(name: 'Porta');
      final house = LayerModel(name: 'Casa');
      final scenery = LayerModel(name: 'Paisagem');
      const ink = 0xFF344052;
      const wall = 0xFFFFE6AC;
      const roof = 0xFFD96F5D;
      const glass = 0xFF67C7D4;

      house.strokes.add(_s([
        const Offset(83, 205),
        const Offset(237, 205),
      ], color: roof, width: 5));
      house.strokes.add(_s([
        const Offset(66, 207),
        const Offset(160, 125),
        const Offset(254, 207),
        const Offset(66, 207),
      ], color: roof, width: 5));
      house.strokes.add(_s([
        const Offset(83, 205),
        const Offset(237, 205),
        const Offset(237, 333),
        const Offset(83, 333),
        const Offset(83, 205),
      ], color: ink, width: 3.5));
      house.strokes.add(_s([
        const Offset(98, 225),
        const Offset(138, 265),
      ], color: wall, width: 3, kind: 'rectangle'));
      house.strokes.add(_s([
        const Offset(184, 225),
        const Offset(224, 265),
      ], color: glass, width: 3, kind: 'rectangle'));
      house.strokes.add(_s([
        const Offset(115, 245),
        const Offset(125, 255),
      ], color: ink, width: 2.4, kind: 'line'));
      house.strokes.add(_s([
        const Offset(204, 245),
        const Offset(214, 255),
      ], color: ink, width: 2.4, kind: 'line'));
      house.strokes.add(_s([
        const Offset(147, 285),
        const Offset(176, 333),
      ], color: ink, width: 3, kind: 'rectangle'));
      house.strokes.add(_s([
        const Offset(160, 302),
        const Offset(160, 308),
      ], color: 0xFFFFD166, width: 3, kind: 'line'));

      final doorWidth = doorWidths[index];
      final depth = doorDepths[index];
      door.strokes.add(_s([
        Offset(147, 286),
        Offset(147 + doorWidth, 286),
        Offset(147 + doorWidth - depth, 333),
        Offset(147, 333),
        const Offset(147, 286),
      ], color: roof, width: 3));
      door.strokes.add(_s([
        Offset(151, 295),
        Offset(151 + math.max(doorWidth - 8, 3), 295),
        Offset(151 + math.max(doorWidth - 8, 3) - depth * .65, 324),
        Offset(151, 324),
        const Offset(151, 295),
      ], color: wall, width: 2));
      door.strokes.add(_s([
        Offset(147 + math.max(doorWidth - depth - 5, 3), 311),
        Offset(147 + math.max(doorWidth - depth - 2, 3), 311),
      ], color: ink, width: 2.2));

      scenery.strokes.add(_s([
        const Offset(18, 354),
        const Offset(302, 354),
      ], color: 0xFF7ABF84, width: 3));
      scenery.strokes.add(_s([
        const Offset(34, 83),
        const Offset(62, 111),
      ], color: 0xFFFFD166, width: 4, kind: 'ellipse'));
      scenery.strokes.add(_s([
        const Offset(35, 84),
        const Offset(61, 110),
      ], color: 0xFFFFD166, width: 3, kind: 'line'));
      scenery.strokes.add(_s([
        const Offset(255, 90),
        const Offset(292, 110),
      ], color: 0xFFB7D9F5, width: 2.5, kind: 'ellipse'));
      scenery.strokes.add(_s([
        const Offset(265, 82),
        const Offset(301, 106),
      ], color: 0xFFB7D9F5, width: 2.5, kind: 'ellipse'));

      return FrameModel(layers: <LayerModel>[door, house, scenery]);
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
