import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';

import '../lib/models/project_model.dart';
import '../lib/services/template_catalog.dart';

void main() {
  group('ProjectModel', () {
    test('new project starts with one blank frame and the default frame rate', () {
      final project = ProjectModel.create('Meu primeiro projeto');

      expect(project.name, 'Meu primeiro projeto');
      expect(project.fps, 12);
      expect(project.frames, hasLength(1));
      expect(project.frames.single.layers, hasLength(3));
      expect(project.frames.single.layers.every((layer) => layer.strokes.isEmpty), isTrue);
    });

    test('frame JSON round-trip keeps strokes, brush style, color and points', () {
      final frame = FrameModel(
        uid: 'frame-a',
        layers: <LayerModel>[
          LayerModel(
            name: 'Linha',
            strokes: <StrokeModel>[
              StrokeModel(
                points: <Offset>[const Offset(2, 3), const Offset(20, 30)],
                color: 0xFF12ABCD,
                width: 4.5,
                kind: 'pen',
                brushStyle: 'tinta',
              ),
            ],
          ),
          LayerModel(name: 'Cor'),
          LayerModel(name: 'Fundo'),
        ],
      );

      final restored = FrameModel.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(frame.toJson())) as Map),
      );
      final stroke = restored.layers.first.strokes.single;

      expect(restored.uid, 'frame-a');
      expect(stroke.points, <Offset>[const Offset(2, 3), const Offset(20, 30)]);
      expect(stroke.color, 0xFF12ABCD);
      expect(stroke.width, 4.5);
      expect(stroke.brushStyle, 'tinta');
    });

    test('copying a frame does not share mutable layer or stroke lists', () {
      final frame = FrameModel(
        layers: <LayerModel>[
          LayerModel(name: 'Linha', strokes: <StrokeModel>[
            StrokeModel(points: <Offset>[const Offset(1, 1)]),
          ]),
          LayerModel(name: 'Cor'),
          LayerModel(name: 'Fundo'),
        ],
      );

      final duplicate = frame.copy();
      duplicate.layers.first.strokes.clear();
      duplicate.layers.first.visible = false;

      expect(frame.layers.first.strokes, hasLength(1));
      expect(frame.layers.first.visible, isTrue);
    });

    test('malformed stored frame data recovers to a usable blank frame', () {
      final project = ProjectModel.create('Recuperação');
      project.framesJson = '{invalid-json';

      final frames = project.frames;
      expect(frames, hasLength(1));
      expect(frames.single.layers, hasLength(3));
    });
  });
  group('TemplateCatalog', () {
    test('stickman sparring starter contains editable fight poses and visual effects', () {
      final template = TemplateCatalog.all.singleWhere(
        (item) => item.id == 'stickman-fight',
      );
      final frames = template.createFrames();
      final strokes = frames
          .expand((frame) => frame.layers)
          .expand((layer) => layer.strokes)
          .toList(growable: false);

      expect(frames, hasLength(16));
      expect(frames.every((frame) => frame.layers.length >= 3), isTrue);
      expect(frames.every((frame) =>
          frame.layers.any((layer) => layer.strokes.isNotEmpty)), isTrue);
      expect(strokes.map((stroke) => stroke.brushStyle), contains('luz energética'));
      expect(strokes.map((stroke) => stroke.brushStyle), contains('rastro de movimento'));
    });
  });

}
