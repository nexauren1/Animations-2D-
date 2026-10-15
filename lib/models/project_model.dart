import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:isar_community/isar.dart';

part 'project_model.g.dart';

/// Dados que o Isar persiste diretamente.
/// Os frames são guardados como JSON porque Offset/traços são objetos do editor,
/// e não propriedades nativas que o Isar precise conhecer.
@collection
class ProjectModel {
  Id id = Isar.autoIncrement;

  late String uid;
  late String name;
  late DateTime createdAt;
  late DateTime updatedAt;
  String thumbnailPath = '';
  String framesJson = '[]';
  int fps = 12;

  ProjectModel();

  static ProjectModel create(String projectName) {
    final now = DateTime.now();
    return ProjectModel()
      ..uid = now.microsecondsSinceEpoch.toString()
      ..name = projectName
      ..createdAt = now
      ..updatedAt = now
      ..fps = 12
      ..framesJson = jsonEncode(<Map<String, dynamic>>[
        FrameModel.blank().toJson(),
      ]);
  }
}

/// Mantém a sintaxe project.frames fora da classe anotada.
/// Assim, o gerador Isar só vê tipos de dados suportados.
extension ProjectFrames on ProjectModel {
  List<FrameModel> get frames {
    try {
      final decoded = jsonDecode(framesJson) as List<dynamic>;
      if (decoded.isEmpty) return <FrameModel>[FrameModel.blank()];
      return decoded
          .map((item) => FrameModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();
    } catch (_) {
      return <FrameModel>[FrameModel.blank()];
    }
  }

  set frames(List<FrameModel> value) {
    framesJson = jsonEncode(value.map((frame) => frame.toJson()).toList());
  }
}

/// Um frame contém as três camadas editáveis da animação.
class FrameModel {
  FrameModel({String? uid, List<LayerModel>? layers})
      : uid = uid ?? DateTime.now().microsecondsSinceEpoch.toString(),
        layers = layers ??
            <LayerModel>[
              LayerModel(name: 'Linha'),
              LayerModel(name: 'Cor'),
              LayerModel(name: 'Fundo'),
            ];

  final String uid;
  final List<LayerModel> layers;

  factory FrameModel.blank() => FrameModel();

  factory FrameModel.fromJson(Map<String, dynamic> json) {
    final rawLayers = json['layers'] as List<dynamic>? ?? <dynamic>[];
    final layers = rawLayers
        .map((item) => LayerModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    while (layers.length < 3) {
      const names = <String>['Linha', 'Cor', 'Fundo'];
      layers.add(LayerModel(name: names[layers.length]));
    }
    return FrameModel(uid: json['uid'] as String?, layers: layers);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'uid': uid,
        'layers': layers.map((layer) => layer.toJson()).toList(),
      };

  FrameModel copy() => FrameModel.fromJson(toJson());
}

/// Camada editável. A visibilidade e os traços vivem dentro do JSON dos frames.
class LayerModel {
  LayerModel({
    required this.name,
    this.visible = true,
    List<StrokeModel>? strokes,
  }) : strokes = strokes ?? <StrokeModel>[];

  final String name;
  bool visible;
  final List<StrokeModel> strokes;

  factory LayerModel.fromJson(Map<String, dynamic> json) => LayerModel(
        name: json['name'] as String? ?? 'Camada',
        visible: json['visible'] as bool? ?? true,
        strokes: (json['strokes'] as List<dynamic>? ?? <dynamic>[])
            .map((item) => StrokeModel.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'visible': visible,
        'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
      };

  LayerModel copy() => LayerModel.fromJson(toJson());
}

/// Cada traço tem os pontos Offset, cor ARGB, espessura, geometria e pincel.
class StrokeModel {
  StrokeModel({
    required List<Offset> points,
    this.color = 0xFF111111,
    this.width = 3,
    this.kind = 'pen',
    this.brushStyle = 'lápis',
  }) : points = List<Offset>.from(points);

  final List<Offset> points;
  final int color;
  final double width;
  final String kind;
  final String brushStyle;

  factory StrokeModel.fromJson(Map<String, dynamic> json) => StrokeModel(
        points: (json['points'] as List<dynamic>? ?? <dynamic>[])
            .map((item) {
              final point = Map<String, dynamic>.from(item as Map);
              return Offset(
                (point['x'] as num).toDouble(),
                (point['y'] as num).toDouble(),
              );
            }).toList(),
        color: (json['color'] as num?)?.toInt() ?? 0xFF111111,
        width: (json['width'] as num?)?.toDouble() ?? 3,
        kind: json['kind'] as String? ?? 'pen',
        brushStyle: json['brushStyle'] as String? ?? 'lápis',
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'points': points
            .map((point) => <String, double>{'x': point.dx, 'y': point.dy})
            .toList(),
        'color': color,
        'width': width,
        'kind': kind,
        'brushStyle': brushStyle,
      };

  StrokeModel copy() => StrokeModel(
        points: points,
        color: color,
        width: width,
        kind: kind,
        brushStyle: brushStyle,
      );
}
