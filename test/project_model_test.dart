import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';

import '../lib/models/project_model.dart';
import '../lib/services/template_catalog.dart';
import '../lib/services/audio_library_service.dart';

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

  group('Expanded starter projects', () {
    test('walking and flying-bird projects provide editable looping frames', () {
      final walking = TemplateCatalog.all.singleWhere((item) => item.id == 'walk-cycle');
      final bird = TemplateCatalog.all.singleWhere((item) => item.id == 'bird-flight');

      expect(walking.createFrames(), hasLength(8));
      expect(bird.createFrames(), hasLength(8));
      expect(
        walking.createFrames().every((frame) => frame.layers.every((layer) => layer.strokes.isNotEmpty || layer.name == 'Cores')),
        isTrue,
      );
    });
  });

  group('Audio library data', () {
    test('catalogue accepts a safe, licensed manifest entry', () {
      final item = AudioCatalogItem.fromJson(<String, dynamic>{
        'id': 'footstep-soft',
        'title': 'Soft footsteps',
        'category': 'Foley',
        'file': 'sfx/footstep-soft.mp3',
        'pro': false,
        'credit': 'Artist Name',
        'license': 'Pixabay Content License',
      });

      expect(item.id, 'footstep-soft');
      expect(item.downloadUrl, endsWith('/content/audio/sfx/footstep-soft.mp3'));
      expect(item.isPro, isFalse);
    });

    test('catalogue rejects path traversal and unsupported file types', () {
      expect(
        () => AudioCatalogItem.fromJson(<String, dynamic>{
          'id': 'unsafe',
          'title': 'Unsafe',
          'category': 'Foley',
          'file': '../private.mp3',
        }),
        throwsFormatException,
      );
      expect(
        () => AudioCatalogItem.fromJson(<String, dynamic>{
          'id': 'not-audio',
          'title': 'Not audio',
          'category': 'Foley',
          'file': 'sfx/image.png',
        }),
        throwsFormatException,
      );
    });

    test('audio clip JSON round-trip preserves frame, volume and Pro flag', () {
      final clip = AudioTimelineClip(
        instanceId: 'clip-1',
        catalogId: 'soft-whoosh',
        title: 'Soft whoosh',
        localPath: '/private/audio/soft-whoosh.mp3',
        startFrame: 18,
        volume: .65,
        isPro: true,
      );
      final restored = AudioTimelineClip.fromJson(clip.toJson());

      expect(restored.startFrame, 18);
      expect(restored.volume, closeTo(.65, .0001));
      expect(restored.isPro, isTrue);
      expect(restored.catalogId, 'soft-whoosh');
    });
  });

}
