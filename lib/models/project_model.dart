import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:isar/isar.dart';

part 'project_model.g.dart';

/// Projeto persistido localmente no Isar.
/// Os frames são guardados em JSON para manter Offset simples e portátil.
@collection
class ProjectModel {
  Id id = Isar.autoIncrement;

  late String uid;
  late String name;
  late DateTime createdAt;
  late DateTime updatedAt;

  /// Reservado para o caminho de uma miniatura exportada, se for adicionada.
  String thumbnailPath = '';

  /// Armazenamento serializado dos frames; Isar mantém este campo como texto.
  String framesJson = '[]';

  ProjectModel();

  /// Campo de conveniência usado pelo editor; não é persistido diretamente.
  @ignore
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

  /// Cria um projeto com um frame vazio e as três camadas padrão.
  static ProjectModel create(String projectName) {
    final now = DateTime.now();
    return ProjectModel()
      ..uid = now.microsecondsSinceEpoch.toString()
      ..name = projectName
      ..createdAt = now
      ..updatedAt = now
      ..frames = <FrameModel>[FrameModel.blank()];
  }
}

/// Frame da animação. A estrutura é serializada dentro de ProjectModel.
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
    final rawLayers = (json['layers'] as List<dynamic>? ?? <dynamic>[]);
    final layers = rawLayers
        .map((item) =>
            LayerModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    while (layers.length < 3) {
      const names = <String>['Linha', 'Cor', 'Fundo'];
      layers.add(LayerModel(name: names[layers.length]));
    }
    return FrameModel(
      uid: json['uid'] as String?,
      layers: layers,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'uid': uid,
        'layers': layers.map((layer) => layer.toJson()).toList(),
      };

  /// Faz uma cópia profunda para duplicar frames sem partilhar listas de traços.
  FrameModel copy() => FrameModel.fromJson(toJson());
}

/// Uma camada pode ser mostrada/ocultada e contém os seus próprios traços.
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
            .map((item) => StrokeModel.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ))
            .toList(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'visible': visible,
        'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
      };

  LayerModel copy() => LayerModel.fromJson(toJson());
}

/// Um traço é uma lista de Offset, cor ARGB e espessura.
class StrokeModel {
  StrokeModel({
    required List<Offset> points,
    this.color = 0xFF111111,
    this.width = 3,
    this.kind = 'pen',
  }) : points = List<Offset>.from(points);

  final List<Offset> points;
  final int color;
  final double width;
  /// Tipo do traço: pen, eraser, line, rectangle, ellipse ou ruler.
  final String kind;

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
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'points': points
            .map((point) => <String, double>{'x': point.dx, 'y': point.dy})
            .toList(),
        'color': color,
        'width': width,
        'kind': kind,
      };

  StrokeModel copy() => StrokeModel(
        points: points,
        color: color,
        width: width,
        kind: kind,
      );
}
