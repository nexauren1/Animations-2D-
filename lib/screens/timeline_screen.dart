import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import '../services/app_locale.dart';
import '../models/project_model.dart';

/// Bottom sheet da timeline, com duplicação e playback em loop.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({
    required this.frames,
    required this.currentFrameIndex,
    required this.onFrameSelected,
    required this.onFramesChanged,
    required this.fps,
    required this.onFpsChanged,
    super.key,
  });

  final List<FrameModel> frames;
  final int currentFrameIndex;
  final ValueChanged<int> onFrameSelected;
  final ValueChanged<List<FrameModel>> onFramesChanged;
  final int fps;
  final ValueChanged<int> onFpsChanged;

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  Timer? _timer;
  bool _isPlaying = false;
  late List<FrameModel> _frames;
  late int _selectedIndex;
  late int _fps;

  @override
  void initState() {
    super.initState();
    _frames = widget.frames.map((frame) => frame.copy()).toList();
    _selectedIndex = widget.currentFrameIndex.clamp(0, _frames.length - 1).toInt();
    _fps = widget.fps.clamp(1, 60).toInt();
  }

  @override
  void didUpdateWidget(covariant TimelineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.frames.length != _frames.length) {
      _frames = widget.frames.map((frame) => frame.copy()).toList();
    }
    if (widget.fps != oldWidget.fps) _fps = widget.fps.clamp(1, 60).toInt();
    if (widget.currentFrameIndex != oldWidget.currentFrameIndex &&
        widget.currentFrameIndex >= 0 &&
        widget.currentFrameIndex < _frames.length) {
      _selectedIndex = widget.currentFrameIndex;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _selectFrame(int index) {
    if (index < 0 || index >= _frames.length) return;
    setState(() => _selectedIndex = index);
    widget.onFrameSelected(index);
  }

  void _startPlaybackTimer() {
    _timer?.cancel();
    final milliseconds = (1000 / _fps).round().clamp(1, 1000).toInt();
    _timer = Timer.periodic(Duration(milliseconds: milliseconds), (_) {
      if (!mounted || _frames.isEmpty) return;
      _selectedIndex = (_selectedIndex + 1) % _frames.length;
      widget.onFrameSelected(_selectedIndex);
      setState(() {});
    });
  }

  void _setFps(int? value) {
    if (value == null || value == _fps) return;
    setState(() => _fps = value.clamp(1, 60).toInt());
    widget.onFpsChanged(_fps);
    if (_isPlaying) _startPlaybackTimer();
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _timer?.cancel();
      setState(() => _isPlaying = false);
      return;
    }
    if (_frames.isEmpty) return;
    setState(() => _isPlaying = true);
    _startPlaybackTimer();
  }

  void _addFrame() {
    if (_frames.isEmpty) _frames = <FrameModel>[FrameModel.blank()];
    final selected = _selectedIndex.clamp(0, _frames.length - 1).toInt();
    final newFrames = _frames.map((frame) => frame.copy()).toList();
    newFrames.insert(selected + 1, newFrames[selected].copy());
    setState(() {
      _frames = newFrames;
      _selectedIndex = selected + 1;
    });
    widget.onFramesChanged(newFrames.map((frame) => frame.copy()).toList());
    widget.onFrameSelected(_selectedIndex);
  }

  void _addBlankFrame() {
    final newFrames = _frames.map((frame) => frame.copy()).toList();
    final insertion = _selectedIndex.clamp(0, newFrames.length - 1).toInt() + 1;
    newFrames.insert(insertion, FrameModel.blank());
    setState(() {
      _frames = newFrames;
      _selectedIndex = insertion;
    });
    widget.onFramesChanged(newFrames.map((frame) => frame.copy()).toList());
    widget.onFrameSelected(_selectedIndex);
  }

  void _deleteSelectedFrame() {
    if (_frames.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O projeto precisa de pelo menos um frame.')),
      );
      return;
    }
    final newFrames = _frames.map((frame) => frame.copy()).toList()
      ..removeAt(_selectedIndex);
    final nextIndex = _selectedIndex.clamp(0, newFrames.length - 1).toInt();
    setState(() {
      _frames = newFrames;
      _selectedIndex = nextIndex;
    });
    widget.onFramesChanged(newFrames.map((frame) => frame.copy()).toList());
    widget.onFrameSelected(_selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    final frames = _frames;
    return Container(
      height: 390,
      decoration: const BoxDecoration(
        color: Color(0xFF151725),
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 15),
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
                  const Icon(Icons.view_timeline_rounded, color: Color(0xFF8B80FF)),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Timeline',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text('${frames.length} frames',
                      style: TextStyle(color: Colors.white.withOpacity(.55))),
                  const SizedBox(width: 10),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _fps,
                      dropdownColor: const Color(0xFF25283A),
                      icon: const Icon(Icons.speed_rounded, size: 17),
                      style: const TextStyle(fontSize: 12, color: Color(0xFFC2BAFF)),
                      items: <int>[6, 12, 24, 30, 60]
                          .map((value) => DropdownMenuItem<int>(
                                value: value,
                                child: Text('${value} FPS'),
                              ))
                          .toList(),
                      onChanged: _setFps,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: frames.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 9),
                  itemBuilder: (context, index) {
                    final selected = index == _selectedIndex;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _selectFrame(index),
                      child: Container(
                        width: 76,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF2C2850) : const Color(0xFF202333),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF8C7CFF)
                                : const Color(0xFF383B4E),
                            width: selected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: <Widget>[
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: CustomPaint(
                                  painter: _FramePreviewPainter(frames[index]),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'F${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                                color: selected ? const Color(0xFFB8AEFF) : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  IconButton.filledTonal(
                    tooltip: 'Reproduzir em loop',
                    onPressed: _togglePlayback,
                    icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addFrame,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Duplicar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC2BAFF),
                        side: const BorderSide(color: Color(0xFF6358B2)),
                        minimumSize: const Size(0, 46),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  IconButton.filledTonal(
                    tooltip: 'Novo frame em branco',
                    onPressed: _addBlankFrame,
                    icon: const Icon(Icons.note_add_rounded),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Apagar frame selecionado',
                    onPressed: _deleteSelectedFrame,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                _isPlaying
                    ? 'Reprodução ativa · $_fps FPS'
                    : 'Escolhe a velocidade, duplica um frame ou cria um frame vazio.',
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FramePreviewPainter extends CustomPainter {
  _FramePreviewPainter(this.frame);
  final FrameModel frame;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF5F6FC));
    final strokes = frame.layers
        .where((layer) => layer.visible)
        .expand((layer) => layer.strokes)
        .where((stroke) => stroke.points.isNotEmpty)
        .toList();
    final points = strokes.expand((stroke) => stroke.points).toList();
    if (points.isEmpty) return;

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

    final width = (right - left).abs().clamp(1.0, double.infinity).toDouble();
    final height = (bottom - top).abs().clamp(1.0, double.infinity).toDouble();
    final scale = (size.width * .72 / width < size.height * .72 / height)
        ? size.width * .72 / width
        : size.height * .72 / height;
    final offsetX = (size.width - width * scale) / 2 - left * scale;
    final offsetY = (size.height - height * scale) / 2 - top * scale;

    for (final stroke in strokes) {
      final paint = Paint()
        ..color = Color(stroke.color)
        ..strokeWidth = (stroke.width * scale).clamp(1.0, 3.0).toDouble()
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (stroke.points.length == 1) {
        canvas.drawCircle(
          Offset(stroke.points.first.dx * scale + offsetX,
              stroke.points.first.dy * scale + offsetY),
          paint.strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
      } else {
        final path = Path()
          ..moveTo(stroke.points.first.dx * scale + offsetX,
              stroke.points.first.dy * scale + offsetY);
        for (final point in stroke.points.skip(1)) {
          path.lineTo(point.dx * scale + offsetX, point.dy * scale + offsetY);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FramePreviewPainter oldDelegate) => true;
}
