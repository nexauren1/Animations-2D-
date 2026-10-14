import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/project_model.dart';

/// Exporta PNG, sequência PNG em ZIP, vídeo MP4 com H.264 via MediaCodec
/// (com fallback para MPEG-4) e GIF animado.
class ExportScreen extends StatefulWidget {
  const ExportScreen({required this.project, required this.frameIndex, super.key});
  final ProjectModel project;
  final int frameIndex;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  String _format = 'PNG';
  int _resolution = 1080;
  int _fps = 24;
  bool _isExporting = false;

  List<FrameModel> get _frames => widget.project.frames;
  FrameModel get _frame => _frames.isEmpty
      ? FrameModel.blank()
      : _frames[widget.frameIndex.clamp(0, _frames.length - 1).toInt()];

  /// Gera imagens 16:9 fixas para garantir que os frames podem ser combinados em vídeo.
  Future<Uint8List> _renderPng(FrameModel frame, int targetResolution) async {
    final strokes = frame.layers
        .where((layer) => layer.visible)
        .expand((layer) => layer.strokes)
        .where((stroke) => stroke.points.isNotEmpty)
        .toList();
    final points = strokes.expand((stroke) => stroke.points).toList();
    double minX = 0, minY = 0, maxX = 640, maxY = 640;
    if (points.isNotEmpty) {
      minX = maxX = points.first.dx;
      minY = maxY = points.first.dy;
      for (final point in points) {
        minX = math.min(minX, point.dx).toDouble();
        maxX = math.max(maxX, point.dx).toDouble();
        minY = math.min(minY, point.dy).toDouble();
        maxY = math.max(maxY, point.dy).toDouble();
      }
    }
    final int outputHeight = targetResolution;
    final int outputWidth = (targetResolution * 16 / 9).round();
    const double margin = 28;
    final double sourceWidth = math.max(maxX - minX, 1.0).toDouble();
    final double sourceHeight = math.max(maxY - minY, 1.0).toDouble();
    final double scale = math.min(
      (outputWidth - margin * 2) / sourceWidth,
      (outputHeight - margin * 2) / sourceHeight,
    ).toDouble();
    final double offsetX = (outputWidth - sourceWidth * scale) / 2 - minX * scale;
    final double offsetY = (outputHeight - sourceHeight * scale) / 2 - minY * scale;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, outputWidth.toDouble(), outputHeight.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    for (final layer in frame.layers.reversed) {
      if (!layer.visible) continue;
      for (final stroke in layer.strokes) {
        if (stroke.points.isEmpty) continue;
        ui.Offset map(ui.Offset point) =>
            ui.Offset(point.dx * scale + offsetX, point.dy * scale + offsetY);
        final mapped = stroke.points.map(map).toList();
        final baseColor = ui.Color(stroke.color);
        double width = math.max(1.0, stroke.width * scale).toDouble();
        double opacity = baseColor.opacity;
        final paint = ui.Paint()
          ..color = baseColor
          ..strokeWidth = width
          ..strokeCap = ui.StrokeCap.round
          ..strokeJoin = ui.StrokeJoin.round
          ..style = ui.PaintingStyle.stroke;

        switch (stroke.brushStyle) {
          case 'tinta':
            width *= .85;
            break;
          case 'marcador':
            width *= 2.4;
            opacity *= .55;
            break;
          case 'aerógrafo':
            width *= 2;
            paint.maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, math.max(1.0, width * .2).toDouble());
            break;
          case 'giz de cera':
            width *= 1.25;
            paint.strokeCap = ui.StrokeCap.square;
            break;
          case 'marca-texto':
            width *= 3;
            opacity *= .32;
            paint.strokeCap = ui.StrokeCap.square;
            break;
          case 'pastel':
            width *= 1.8;
            paint.maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, math.max(1.0, width * .1).toDouble());
            break;
          case 'pixel':
            paint.strokeCap = ui.StrokeCap.square;
            paint.strokeJoin = ui.StrokeJoin.miter;
            break;
          default:
            break;
        }
        paint..color = baseColor.withOpacity(opacity)..strokeWidth = width;
        if (stroke.kind == 'rectangle' && mapped.length >= 2) {
          canvas.drawRect(ui.Rect.fromPoints(mapped.first, mapped.last), paint);
        } else if (stroke.kind == 'ellipse' && mapped.length >= 2) {
          canvas.drawOval(ui.Rect.fromPoints(mapped.first, mapped.last), paint);
        } else if ((stroke.kind == 'line' || stroke.kind == 'ruler') && mapped.length >= 2) {
          canvas.drawLine(mapped.first, mapped.last, paint);
          if (stroke.kind == 'ruler') {
            final delta = mapped.last - mapped.first;
            final length = delta.distance;
            if (length > 1) {
              final perpendicular = ui.Offset(-delta.dy / length, delta.dx / length);
              for (var tick = 0; tick <= 20; tick++) {
                final point = mapped.first + delta * (tick / 20);
                final double tickSize = tick % 5 == 0 ? 8 : 4;
                canvas.drawLine(point - perpendicular * tickSize, point + perpendicular * tickSize, paint);
              }
            }
          }
        } else if (mapped.length == 1) {
          canvas.drawCircle(mapped.first, paint.strokeWidth / 2, paint..style = ui.PaintingStyle.fill);
        } else {
          final path = ui.Path()..moveTo(mapped.first.dx, mapped.first.dy);
          for (final point in mapped.skip(1)) {
            path.lineTo(point.dx, point.dy);
          }
          canvas.drawPath(path, paint);
        }
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(outputWidth, outputHeight);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (data == null) throw StateError('Não foi possível codificar o PNG.');
    return data.buffer.asUint8List();
  }
  Future<void> _export() async {
    setState(() => _isExporting = true);
    Directory? framesDirectory;
    try {
      final directory = await getTemporaryDirectory();
      final time = DateTime.now().millisecondsSinceEpoch;
      late File exported;
      final frames = _frames.isEmpty ? <FrameModel>[FrameModel.blank()] : _frames;

      if (_format == 'PNG') {
        final bytes = await _renderPng(_frame, _resolution);
        exported = File('${directory.path}/animpro_${time}.png');
        await exported.writeAsBytes(bytes, flush: true);
      } else if (_format == 'PNG Sequence') {
        final archive = Archive();
        for (var index = 0; index < frames.length; index++) {
          final bytes = await _renderPng(frames[index], _resolution);
          final filename = 'frame_${(index + 1).toString().padLeft(5, '0')}.png';
          archive.addFile(ArchiveFile(filename, bytes.length, bytes));
        }
        final zipBytes = ZipEncoder().encode(archive);
        if (zipBytes == null) throw StateError('Não foi possível criar o ZIP.');
        exported = File('${directory.path}/animpro_frames_${time}.zip');
        await exported.writeAsBytes(zipBytes, flush: true);
      } else {
        framesDirectory = Directory('${directory.path}/animpro_sequence_${time}');
        await framesDirectory.create(recursive: true);
        for (var index = 0; index < frames.length; index++) {
          final bytes = await _renderPng(frames[index], _resolution);
          final filename = 'frame_${index.toString().padLeft(5, '0')}.png';
          await File('${framesDirectory.path}/${filename}').writeAsBytes(bytes, flush: true);
        }

        final inputPattern = "'${framesDirectory.path}/frame_%05d.png'";
        if (_format == 'MP4') {
          exported = File('${directory.path}/animpro_${time}.mp4');
          final h264Command = "-y -framerate $_fps -start_number 0 -i ${inputPattern} "
              "-c:v h264_mediacodec -b:v 4M -pix_fmt yuv420p -movflags +faststart '${exported.path}'";
          var session = await FFmpegKit.execute(h264Command);
          var code = await session.getReturnCode();

          // Se a ROM não oferecer codificador H.264 via MediaCodec, usa MPEG-4 como fallback.
          if (!ReturnCode.isSuccess(code)) {
            if (await exported.exists()) await exported.delete();
            final fallback = "-y -framerate $_fps -start_number 0 -i ${inputPattern} "
                "-c:v mpeg4 -q:v 3 -pix_fmt yuv420p -movflags +faststart '${exported.path}'";
            session = await FFmpegKit.execute(fallback);
            code = await session.getReturnCode();
          }
          if (!ReturnCode.isSuccess(code) || !await exported.exists() || await exported.length() == 0) {
            throw StateError('Não foi possível codificar o MP4. ${await session.getOutput()}');
          }
        } else {
          exported = File('${directory.path}/animpro_${time}.gif');
          final gifCommand = "-y -framerate $_fps -start_number 0 -i ${inputPattern} "
              "-vf 'fps=$_fps,scale=640:-1:flags=lanczos' -loop 0 '${exported.path}'";
          final session = await FFmpegKit.execute(gifCommand);
          final code = await session.getReturnCode();
          if (!ReturnCode.isSuccess(code) || !await exported.exists() || await exported.length() == 0) {
            throw StateError('Não foi possível codificar o GIF. ${await session.getOutput()}');
          }
        }
      }

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(exported.path)],
        subject: 'Exportação AnimPro',
        text: switch (_format) {
          'PNG' => 'Frame exportado do AnimPro.',
          'PNG Sequence' => 'Sequência de frames PNG exportada do AnimPro.',
          'MP4' => 'Vídeo MP4 exportado do AnimPro a $_fps FPS.',
          _ => 'GIF animado exportado do AnimPro.',
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao exportar: $error')),
        );
      }
    } finally {
      if (framesDirectory != null && await framesDirectory.exists()) {
        try {
          await framesDirectory.delete(recursive: true);
        } catch (_) {
          // A limpeza é best effort; o vídeo/imagem exportado fica preservado.
        }
      }
      if (mounted) setState(() => _isExporting = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exportar', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          const Text('Pré-visualização',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white70)),
          const SizedBox(height: 10),
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: const Color(0xFF131D2B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF30384C)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(
                painter: _ExportPreviewPainter(_frame),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const SizedBox(height: 11),
          Text(
            '${widget.project.name} · Frame ${widget.frameIndex + 1} · ${_frames.length} frames',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 12),
          ),
          const SizedBox(height: 26),
          const Text('Resolução', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              _choice('540p', _resolution == 540, () => setState(() => _resolution = 540)),
              const SizedBox(width: 9),
              _choice('720p', _resolution == 720, () => setState(() => _resolution = 720)),
              const SizedBox(width: 9),
              _choice('1080p', _resolution == 1080, () => setState(() => _resolution = 1080)),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Formato', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['MP4', 'GIF', 'PNG', 'PNG Sequence'].map((format) {
              final selected = _format == format;
              return ChoiceChip(
                selected: selected,
                label: Text(format),
                avatar: Icon(
                  format == 'MP4' ? Icons.movie_outlined
                      : format == 'GIF' ? Icons.gif_box_outlined
                      : format == 'PNG' ? Icons.image_outlined
                      : Icons.folder_zip_outlined,
                  size: 18,
                ),
                onSelected: (_) => setState(() => _format = format),
                selectedColor: const Color(0xFF5445C6),
                backgroundColor: const Color(0xFF242737),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(color: selected ? const Color(0xFF897CFF) : const Color(0xFF3B4054)),
              );
            }).toList(),
          ),
          const SizedBox(height: 7),
          Text(
            _format == 'PNG'
                ? 'Exporta o frame atual como imagem PNG e abre as opções de partilha do telefone.'
                : _format == 'PNG Sequence'
                    ? 'Exporta todos os frames para ficheiros PNG dentro de um ZIP.'
                    : 'Será codificado a partir de todos os frames do projeto e partilhado para guardar no telefone.',
            style: TextStyle(color: Colors.white.withOpacity(.58), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 24),
          const Text('Frame rate (FPS)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [12, 24, 30, 60].map((fps) {
              final selected = fps == _fps;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: fps == 60 ? 0 : 8),
                  child: OutlinedButton(
                    onPressed: () => setState(() => _fps = fps),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: selected ? const Color(0xFF5445C6) : const Color(0xFF242737),
                      foregroundColor: Colors.white,
                      side: BorderSide(color: selected ? const Color(0xFF897CFF) : const Color(0xFF3B4054)),
                    ),
                    child: Text('$fps'),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text('FPS fica guardado para futuras exportações de vídeo. O PNG não tem taxa de frames.',
              style: TextStyle(color: Colors.white.withOpacity(.48), fontSize: 11)),
          const SizedBox(height: 25),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: _isExporting ? null : _export,
              icon: _isExporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_download_outlined),
              label: Text(_isExporting ? 'A exportar…' : 'Exportar agora',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6C50F8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF373052) : const Color(0xFF242737),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? const Color(0xFF8C7CFF) : const Color(0xFF3B4054)),
          ),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: selected ? Colors.white : Colors.white60)),
        ),
      ),
    );
  }
}

class _ExportPreviewPainter extends CustomPainter {
  _ExportPreviewPainter(this.frame);
  final FrameModel frame;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF8FAFF));
    final strokes = frame.layers.where((layer) => layer.visible)
        .expand((layer) => layer.strokes).where((stroke) => stroke.points.isNotEmpty).toList();
    final points = strokes.expand((stroke) => stroke.points).toList();
    if (points.isEmpty) {
      final text = TextPainter(
        text: const TextSpan(text: 'Desenha algo no canvas', style: TextStyle(color: Color(0xFF777A89), fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset((size.width - text.width) / 2, (size.height - text.height) / 2));
      return;
    }
    var minX = points.first.dx, maxX = minX, minY = points.first.dy, maxY = minY;
    for (final p in points) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final double width = math.max(maxX - minX, 1).toDouble();
    final double height = math.max(maxY - minY, 1).toDouble();
    final double scale = math.min((size.width - 50) / width, (size.height - 50) / height).toDouble();
    final dx = (size.width - width * scale) / 2 - minX * scale;
    final dy = (size.height - height * scale) / 2 - minY * scale;
    for (final stroke in strokes) {
      final paint = Paint()..color = Color(stroke.color)..strokeWidth = math.max(1, stroke.width * scale).toDouble()
        ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke;
      final mapped = stroke.points.map((p) => Offset(p.dx * scale + dx, p.dy * scale + dy)).toList();
      if (stroke.kind == 'rectangle' && mapped.length > 1) {
        canvas.drawRect(Rect.fromPoints(mapped.first, mapped.last), paint);
      } else if (stroke.kind == 'ellipse' && mapped.length > 1) {
        canvas.drawOval(Rect.fromPoints(mapped.first, mapped.last), paint);
      } else if ((stroke.kind == 'line' || stroke.kind == 'ruler') && mapped.length > 1) {
        canvas.drawLine(mapped.first, mapped.last, paint);
      } else if (mapped.length == 1) {
        canvas.drawCircle(mapped.first, paint.strokeWidth / 2, paint..style = PaintingStyle.fill);
      } else {
        final path = Path()..moveTo(mapped.first.dx, mapped.first.dy);
        for (final p in mapped.skip(1)) { path.lineTo(p.dx, p.dy); }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ExportPreviewPainter oldDelegate) => true;
}
