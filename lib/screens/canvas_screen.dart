import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/project_model.dart';
import '../services/project_store.dart';
import 'rigging_screen.dart';
import 'timeline_screen.dart';

enum _DrawingTool { pen, eraser }

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({
    required this.store,
    required this.project,
    super.key,
  });

  final ProjectStore store;
  final ProjectModel project;

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  late List<FrameModel> _frames;
  int _currentFrameIndex = 0;
  int _selectedLayerIndex = 0;
  _DrawingTool _tool = _DrawingTool.pen;
  List<Offset>? _draftPoints;
  final List<List<LayerModel>> _undoStack = <List<LayerModel>>[];
  final List<List<LayerModel>> _redoStack = <List<LayerModel>>[];
  bool _isSaving = false;

  FrameModel get _currentFrame => _frames[_currentFrameIndex];
  LayerModel get _activeLayer => _currentFrame.layers[_selectedLayerIndex];
  FrameModel? get _previousFrame =>
      _currentFrameIndex > 0 ? _frames[_currentFrameIndex - 1] : null;

  @override
  void initState() {
    super.initState();
    _frames = widget.project.frames.map((frame) => frame.copy()).toList();
    if (_frames.isEmpty) _frames = <FrameModel>[FrameModel.blank()];
  }

  List<LayerModel> _copyLayers(List<LayerModel> layers) =>
      layers.map((layer) => layer.copy()).toList();

  void _rememberUndo() {
    _undoStack.add(_copyLayers(_currentFrame.layers));
    if (_undoStack.length > 40) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  Future<void> _persist() async {
    if (_isSaving) return;
    _isSaving = true;
    try {
      await widget.store.saveProject(widget.project, frames: _frames);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível guardar o projeto: $error')),
        );
      }
    } finally {
      _isSaving = false;
    }
  }

  void _startStroke(DragStartDetails details) {
    setState(() => _draftPoints = <Offset>[details.localPosition]);
  }

  void _updateStroke(DragUpdateDetails details) {
    final points = _draftPoints;
    if (points == null) return;
    setState(() => points.add(details.localPosition));
  }

  Future<void> _finishStroke(DragEndDetails details) async {
    final points = _draftPoints;
    if (points == null || points.isEmpty) {
      setState(() => _draftPoints = null);
      return;
    }

    _rememberUndo();
    _activeLayer.strokes.add(
      StrokeModel(
        points: points,
        color: _tool == _DrawingTool.eraser ? 0xFFFFFFFF : 0xFF111111,
        width: _tool == _DrawingTool.eraser ? 10 : 3,
      ),
    );
    setState(() => _draftPoints = null);
    await _persist();
  }

  Future<void> _undo() async {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_copyLayers(_currentFrame.layers));
    final previous = _undoStack.removeLast();
    _currentFrame.layers
      ..clear()
      ..addAll(previous.map((layer) => layer.copy()));
    setState(() {});
    await _persist();
  }

  Future<void> _redo() async {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_copyLayers(_currentFrame.layers));
    final next = _redoStack.removeLast();
    _currentFrame.layers
      ..clear()
      ..addAll(next.map((layer) => layer.copy()));
    setState(() {});
    await _persist();
  }

  Future<void> _clearLayer() async {
    if (_activeLayer.strokes.isEmpty) return;
    _rememberUndo();
    setState(() => _activeLayer.strokes.clear());
    await _persist();
  }

  Future<void> _changeLayer(int index) async {
    if (index < 0 || index >= _currentFrame.layers.length) return;
    setState(() {
      _selectedLayerIndex = index;
      _draftPoints = null;
    });
  }

  Future<void> _openTimeline() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TimelineScreen(
        frames: _frames,
        currentFrameIndex: _currentFrameIndex,
        onFrameSelected: (index) {
          if (index < 0 || index >= _frames.length) return;
          setState(() {
            _currentFrameIndex = index;
            _draftPoints = null;
            _undoStack.clear();
            _redoStack.clear();
          });
        },
        onFramesChanged: (frames) async {
          setState(() => _frames = frames);
          await _persist();
        },
      ),
    );
  }

  Future<void> _openRigging() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RiggingScreen(
        frame: _currentFrame,
        onSavePose: (posedFrame) async {
          final updated = _frames.map((frame) => frame.copy()).toList();
          final insertAt = (_currentFrameIndex + 1).clamp(0, updated.length);
          updated.insert(insertAt, posedFrame);
          setState(() {
            _frames = updated;
            _currentFrameIndex = insertAt;
            _undoStack.clear();
            _redoStack.clear();
          });
          await _persist();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pose guardada como novo frame.')),
            );
          }
        },
      ),
    );
  }

  Future<void> _saveAndShowMessage() async {
    await _persist();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Projeto guardado neste dispositivo.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previous = _previousFrame;
    final draft = _draftPoints == null
        ? null
        : StrokeModel(
            points: _draftPoints!,
            color: _tool == _DrawingTool.eraser ? 0xFFFFFFFF : 0xFF111111,
            width: _tool == _DrawingTool.eraser ? 10 : 3,
          );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar aos projetos',
          onPressed: () async {
            await _persist();
            if (context.mounted) Navigator.of(context).pop();
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.project.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              'Frame ${_currentFrameIndex + 1} / ${_frames.length}',
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(.55)),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Guardar projeto',
            onPressed: _saveAndShowMessage,
            icon: const Icon(Icons.save_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildLayerSelector(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 9),
            child: Row(
              children: <Widget>[
                const Icon(Icons.crop_free_rounded, size: 15, color: Color(0xFF8D83FF)),
                const SizedBox(width: 6),
                Text(
                  'Canvas · 100%',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(.65)),
                ),
                const Spacer(),
                const Icon(Icons.layers_outlined, size: 15, color: Color(0xFF8D83FF)),
                const SizedBox(width: 5),
                Text(
                  'Onion skin: ${previous == null ? '—' : '30%'}',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(.65)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withOpacity(.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _startStroke,
                  onPanUpdate: _updateStroke,
                  onPanEnd: _finishStroke,
                  onPanCancel: () => setState(() => _draftPoints = null),
                  child: CustomPaint(
                    painter: _AnimationCanvasPainter(
                      frame: _currentFrame,
                      previousFrame: previous,
                      draft: draft,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
          _buildToolBar(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildLayerSelector() {
    const layerNames = <String>['Linha', 'Cor', 'Fundo'];
    const layerIcons = <IconData>[
      Icons.gesture_rounded,
      Icons.palette_outlined,
      Icons.wallpaper_rounded,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 4),
      child: Row(
        children: List<Widget>.generate(3, (index) {
          final selected = _selectedLayerIndex == index;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : 7),
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () => _changeLayer(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF343052)
                        : const Color(0xFF1A1D2B),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF8C7DFF)
                          : const Color(0xFF2D3143),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(layerIcons[index],
                          size: 15,
                          color: selected ? const Color(0xFFB9AEFF) : Colors.white60),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          layerNames[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildToolBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E2C),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF303447)),
      ),
      child: Row(
        children: <Widget>[
          _toolButton(
            icon: Icons.edit_rounded,
            label: 'Caneta',
            selected: _tool == _DrawingTool.pen,
            onPressed: () => setState(() => _tool = _DrawingTool.pen),
          ),
          _toolButton(
            icon: Icons.auto_fix_normal_rounded,
            label: 'Borracha',
            selected: _tool == _DrawingTool.eraser,
            onPressed: () => setState(() => _tool = _DrawingTool.eraser),
          ),
          const SizedBox(width: 2),
          _toolButton(
            icon: Icons.undo_rounded,
            label: 'Desfazer',
            onPressed: _undo,
          ),
          _toolButton(
            icon: Icons.redo_rounded,
            label: 'Refazer',
            onPressed: _redo,
          ),
          _toolButton(
            icon: Icons.delete_sweep_outlined,
            label: 'Limpar',
            onPressed: _clearLayer,
          ),
        ],
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool selected = false,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 1),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF363052) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 21,
                color: selected ? const Color(0xFFB7ACFF) : Colors.white70,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  color: selected ? const Color(0xFFB7ACFF) : Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        height: 67,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: const BoxDecoration(
          color: Color(0xFF11131F),
          border: Border(top: BorderSide(color: Color(0xFF292D40))),
        ),
        child: Row(
          children: <Widget>[
            _bottomItem(
              icon: Icons.layers_outlined,
              label: 'Camadas',
              onPressed: () => _changeLayer((_selectedLayerIndex + 1) % 3),
            ),
            _bottomItem(
              icon: Icons.view_timeline_rounded,
              label: 'Timeline',
              onPressed: _openTimeline,
              color: const Color(0xFF9D91FF),
            ),
            _bottomItem(
              icon: Icons.hub_rounded,
              label: 'Rigging',
              onPressed: _openRigging,
              color: const Color(0xFF39D8E9),
            ),
            _bottomItem(
              icon: Icons.save_outlined,
              label: 'Guardar',
              onPressed: _saveAndShowMessage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomItem({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color color = Colors.white70,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

/// Desenha frame anterior com 30% de opacidade, traços do frame atual e o
/// traço temporário que ainda está a ser desenhado pelo dedo.
class _AnimationCanvasPainter extends CustomPainter {
  _AnimationCanvasPainter({
    required this.frame,
    required this.previousFrame,
    required this.draft,
  });

  final FrameModel frame;
  final FrameModel? previousFrame;
  final StrokeModel? draft;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);

    final previous = previousFrame;
    if (previous != null) _paintFrame(canvas, previous, .30);
    _paintFrame(canvas, frame, 1);

    final activeStroke = draft;
    if (activeStroke != null) _paintStroke(canvas, activeStroke, 1);
  }

  void _paintFrame(Canvas canvas, FrameModel target, double opacity) {
    // A camada Fundo é pintada primeiro, depois Cor e Linha.
    for (final layer in target.layers.reversed) {
      if (!layer.visible) continue;
      for (final stroke in layer.strokes) {
        _paintStroke(canvas, stroke, opacity);
      }
    }
  }

  void _paintStroke(Canvas canvas, StrokeModel stroke, double opacity) {
    if (stroke.points.isEmpty) return;
    final paint = Paint()
      ..color = Color(stroke.color).withOpacity(opacity)
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.points.length == 1) {
      canvas.drawCircle(
        stroke.points.first,
        stroke.width / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (final point in stroke.points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AnimationCanvasPainter oldDelegate) => true;
}
