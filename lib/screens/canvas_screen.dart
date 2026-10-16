import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';

import 'package:flutter/material.dart' hide Text;
import '../services/app_locale.dart';

import '../models/project_model.dart';
import '../services/project_store.dart';
import '../services/pro_access_service.dart';
import 'assets_library_screen.dart';
import 'audio_lip_sync_screen.dart';
import 'export_screen.dart';
import 'rigging_screen.dart';
import 'timeline_screen.dart';

enum _DrawingTool { pen, eraser, line, rectangle, ellipse, ruler }

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({required this.store, required this.project, super.key});
  final ProjectStore store;
  final ProjectModel project;

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  static const _palette = <Color>[
    Color(0xFF000000), Color(0xFF333333), Color(0xFF707070),
    Color(0xFFAAAAAA), Colors.white, Color(0xFF7A202A),
    Color(0xFFE53935), Color(0xFFFF7A45), Color(0xFFFF9800),
    Color(0xFFFFC107), Color(0xFFFFFF00), Color(0xFFCDDC39),
    Color(0xFF4CAF50), Color(0xFF00C853), Color(0xFF009688),
    Color(0xFF00BCD4), Color(0xFF03A9F4), Color(0xFF2196F3),
    Color(0xFF3F51B5), Color(0xFF673AB7), Color(0xFF9C27B0),
    Color(0xFFE91E63), Color(0xFFF48FB1), Color(0xFFFF80AB),
    Color(0xFF795548), Color(0xFF8D6E63), Color(0xFF00FFFF),
    Color(0xFF7FFFD4), Color(0xFFB39DDB), Color(0xFFF8BBD0),
    Color(0xFFFFCCBC), Color(0xFFB2DFDB), Color(0xFFBBDEFB),
    Color(0xFFC5CAE9), Color(0xFFDCEDC8), Color(0xFFB9F6CA),
  ];

  late List<FrameModel> _frames;
  int _currentFrameIndex = 0;
  int _selectedLayerIndex = 0;
  _DrawingTool _tool = _DrawingTool.pen;
  int _selectedColor = 0xFF111111;
  double _brushSize = 3;
  String _brushStyle = 'lápis';
  double _opacity = 1;
  bool _showGrid = false;
  bool _onionSkin = true;
  double _onionOpacity = .30;
  Future<void> _saveQueue = Future<void>.value();
  Size _canvasSize = const Size(320, 420);
  List<Offset>? _draftPoints;
  final List<List<LayerModel>> _undoStack = <List<LayerModel>>[];
  final List<List<LayerModel>> _redoStack = <List<LayerModel>>[];
  Timer? _previewTimer;
  bool _isPreviewPlaying = false;
  final AudioPlayer _projectAudioPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _projectAudioStateSubscription;
  bool _isProjectAudioPlaying = false;

  FrameModel get _currentFrame => _frames[_currentFrameIndex];
  LayerModel get _activeLayer => _currentFrame.layers[_selectedLayerIndex];
  FrameModel? get _previousFrame =>
      _onionSkin && _currentFrameIndex > 0 ? _frames[_currentFrameIndex - 1] : null;
  FrameModel? get _nextFrame =>
      _onionSkin && _currentFrameIndex + 1 < _frames.length
          ? _frames[_currentFrameIndex + 1]
          : null;

  Future<void> _openOnionSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF202231),
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sobreposição de frames', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                const Text('Mostra os frames anterior e seguinte para facilitar o movimento.',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 16),
                Row(children: [
                  const Expanded(child: Text('Opacidade dos frames-guia')),
                  Text('${(_onionOpacity * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                Slider(
                  value: _onionOpacity,
                  min: .05,
                  max: .75,
                  divisions: 14,
                  label: '${(_onionOpacity * 100).round()}%',
                  onChanged: (value) {
                    setState(() => _onionOpacity = value);
                    setSheetState(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _strokeKind => switch (_tool) {
        _DrawingTool.pen => 'pen',
        _DrawingTool.eraser => 'eraser',
        _DrawingTool.line => 'line',
        _DrawingTool.rectangle => 'rectangle',
        _DrawingTool.ellipse => 'ellipse',
        _DrawingTool.ruler => 'ruler',
      };

  int get _activeColor => _tool == _DrawingTool.eraser
      ? Colors.white.value
      : Color(_selectedColor).withOpacity(_opacity).value;

  @override
  void initState() {
    super.initState();
    _frames = widget.project.frames.map((frame) => frame.copy()).toList();
    if (_frames.isEmpty) _frames = <FrameModel>[FrameModel.blank()];
    _projectAudioStateSubscription = _projectAudioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isProjectAudioPlaying = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _projectAudioStateSubscription?.cancel();
    _projectAudioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePreviewPlayback() async {
    if (_isPreviewPlaying) {
      _previewTimer?.cancel();
      try {
        await _projectAudioPlayer.pause();
      } catch (_) {
        // The animation preview can be paused even if no soundtrack is loaded.
      }
      if (mounted) setState(() => _isPreviewPlaying = false);
      return;
    }
    if (_frames.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adiciona pelo menos dois frames para reproduzir a animação.')),
      );
      return;
    }
    final fps = widget.project.fps.clamp(1, 60).toInt();
    _previewTimer?.cancel();
    setState(() => _isPreviewPlaying = true);
    final audioPath = widget.project.audioPath;
    if (audioPath.isNotEmpty && await File(audioPath).exists()) {
      try {
        await _projectAudioPlayer.play(DeviceFileSource(audioPath));
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A animação será reproduzida sem áudio. Não foi possível abrir a faixa do projeto.')),
          );
        }
      }
    }
    _previewTimer = Timer.periodic(
      Duration(microseconds: (1000000 / fps).round()),
      (_) {
        if (!mounted || _frames.isEmpty) return;
        setState(() {
          _currentFrameIndex = (_currentFrameIndex + 1) % _frames.length;
          _selectedLayerIndex = _selectedLayerIndex.clamp(0, _currentFrame.layers.length - 1).toInt();
        });
      },
    );
  }

  Future<void> _toggleProjectAudio() async {
    final path = widget.project.audioPath;
    if (path.isEmpty) return;
    try {
      if (_isProjectAudioPlaying) {
        await _projectAudioPlayer.pause();
      } else {
        await _projectAudioPlayer.play(DeviceFileSource(path));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível reproduzir o áudio deste projeto. Abre Áudio e importa o ficheiro novamente.')),
      );
    }
  }

  List<LayerModel> _copyLayers(List<LayerModel> layers) =>
      layers.map((layer) => layer.copy()).toList();

  void _rememberUndo() {
    _undoStack.add(_copyLayers(_currentFrame.layers));
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  Future<void> _persist() {
    // Serializa as gravações para que um desenho rápido não perca o último frame.
    final snapshot = _frames.map((frame) => frame.copy()).toList();
    _saveQueue = _saveQueue.then((_) async {
      await widget.store.saveProject(widget.project, frames: snapshot);
    }).catchError((Object error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível guardar o projeto. Tenta novamente.')),
        );
      }
    });
    return _saveQueue;
  }

  Future<void> _toggleLayerVisibility(int index) async {
    setState(() => _currentFrame.layers[index].visible = !_currentFrame.layers[index].visible);
    await _persist();
  }

  void _startStroke(DragStartDetails details) {
    setState(() => _draftPoints = <Offset>[details.localPosition]);
  }

  void _updateStroke(DragUpdateDetails details) {
    final points = _draftPoints;
    if (points == null) return;
    setState(() {
      if (_tool == _DrawingTool.line ||
          _tool == _DrawingTool.rectangle ||
          _tool == _DrawingTool.ellipse ||
          _tool == _DrawingTool.ruler) {
        _draftPoints = <Offset>[points.first, details.localPosition];
      } else {
        points.add(details.localPosition);
      }
    });
  }

  Future<void> _finishStroke(DragEndDetails details) async {
    final points = _draftPoints;
    if (points == null || points.isEmpty) {
      setState(() => _draftPoints = null);
      return;
    }
    _rememberUndo();
    _activeLayer.strokes.add(StrokeModel(
      points: List<Offset>.from(points),
      color: _activeColor,
      width: (_tool == _DrawingTool.eraser ? math.max(_brushSize, 8) : _brushSize).toDouble(),
      kind: _strokeKind,
      brushStyle: _tool == _DrawingTool.eraser ? 'borracha' : _brushStyle,
    ));
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

  void _changeLayer(int index) {
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
        fps: widget.project.fps,
        onFpsChanged: (fps) {
          widget.project.fps = fps;
          _persist();
        },
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
    if (!await ProAccessService.requirePro(context, feature: 'Rigging e poses')) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RiggingScreen(
        frame: _currentFrame,
        onSavePose: (posedFrame) async {
          final updated = _frames.map((frame) => frame.copy()).toList();
          final insertAt = (_currentFrameIndex + 1).clamp(0, updated.length).toInt();
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

  Future<void> _openAssets() async {
    final assetId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const AssetsLibraryScreen()),
    );
    if (assetId == null || !mounted) return;
    await _insertAsset(assetId);
  }

  Future<void> _openAudioLipSync() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AudioLipSyncScreen(
          frames: _frames,
          canvasSize: _canvasSize,
          initialAudioPath: widget.project.audioPath.isEmpty ? null : widget.project.audioPath,
          onAudioPathChanged: (path) async {
            if (mounted) {
              setState(() => widget.project.audioPath = path ?? '');
            } else {
              widget.project.audioPath = path ?? '';
            }
            if (widget.project.audioPath.isEmpty && _isProjectAudioPlaying) {
              await _projectAudioPlayer.stop();
            }
            await _persist();
          },
          onApplyFrames: (updatedFrames) async {
            setState(() {
              _frames = updatedFrames;
              _currentFrameIndex = _currentFrameIndex.clamp(0, _frames.length - 1).toInt();
              _undoStack.clear();
              _redoStack.clear();
            });
            await _persist();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Mapa labial aplicado à timeline.')),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _openExport() async {
    await _persist();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExportScreen(project: widget.project, frameIndex: _currentFrameIndex),
      ),
    );
    await _persist();
  }

  Future<void> _saveAndShowMessage() async {
    await _persist();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Projeto guardado neste dispositivo.')),
    );
  }

  void _chooseTool(_DrawingTool tool) {
    setState(() {
      _tool = tool;
      _draftPoints = null;
      if (tool == _DrawingTool.eraser && _brushSize < 8) _brushSize = 10;
      if (tool == _DrawingTool.pen && _brushSize > 6) _brushSize = 3;
    });
  }

  Future<void> _openBrushSettings() async {
    final colorController = TextEditingController(
      text: '#' +
          (Color(_selectedColor).value & 0xFFFFFF)
              .toRadixString(16)
              .padLeft(6, '0')
              .toUpperCase(),
    );
    final initialHsv = HSVColor.fromColor(Color(_selectedColor));
    var hue = initialHsv.hue;
    var saturation = initialHsv.saturation;
    var brightness = initialHsv.value;

    String colorHex(Color color) =>
        '#' +
        (color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

    void applyColor(Color color, StateSetter setSheetState) {
      final nextHsv = HSVColor.fromColor(color);
      setState(() => _selectedColor = color.value);
      setSheetState(() {
        hue = nextHsv.hue;
        saturation = nextHsv.saturation;
        brightness = nextHsv.value;
        colorController.text = colorHex(color);
      });
    }

    void applyHsv(StateSetter setSheetState) {
      applyColor(
        HSVColor.fromAHSV(1, hue, saturation, brightness).toColor(),
        setSheetState,
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          decoration: const BoxDecoration(
            color: Color(0xFF202231),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(width: 42, height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 18),
                  const Text('Cor e pincel', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('Escolhe a cor, espessura e opacidade do próximo traço.',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(.6))),
                  const SizedBox(height: 17),
                  const Text('Estilo do pincel', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: [
                      'Lápis',
                      'Caneta técnica',
                      'Tinta',
                      'Tinta chinesa',
                      'Marcador',
                      'Aerógrafo',
                      'Pincel suave',
                      'Giz de cera',
                      'Marca-texto',
                      'Pastel',
                      'Pincel seco',
                      'Pixel',
                      'Brilho neon',
                      'Rastro de movimento',
                      'Linha tracejada',
                      'Luz energética',
                    ].map((style) {
                      final value = style.toLowerCase();
                      final selected = value == _brushStyle;
                      return ChoiceChip(
                        avatar: SizedBox(
                          width: 38,
                          height: 13,
                          child: CustomPaint(
                            painter: _BrushPreviewPainter(
                              style: value,
                              color: Color(_selectedColor).withOpacity(_opacity),
                            ),
                          ),
                        ),
                        label: Text(style),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _brushStyle = value);
                          setSheetState(() {});
                        },
                        selectedColor: const Color(0xFF5445C6),
                        backgroundColor: const Color(0xFF292C3D),
                        labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 11),
                        side: BorderSide(color: selected ? const Color(0xFF897CFF) : const Color(0xFF42465A)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 17),
                  const Text('Paleta de cores', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _palette.map((color) {
                      final selected = _selectedColor == color.value;
                      return InkWell(
                        onTap: () => applyColor(color, setSheetState),
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          height: 35,
                          width: 35,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? const Color(0xFF9A8EFF) : Colors.white24,
                              width: selected ? 3 : 1,
                            ),
                          ),
                          child: selected
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 17,
                                  color: color.computeLuminance() > .5 ? Colors.black : Colors.white,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text('Cor personalizada', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(
                    'Introduz um código HEX ou ajusta matiz, saturação e luminosidade.',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(.6)),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: colorController,
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          enableSuggestions: false,
                          maxLength: 7,
                          decoration: InputDecoration(
                            labelText: 'Código HEX',
                            hintText: '#A1B2C3',
                            counterText: '',
                            isDense: true,
                            prefixIcon: const Icon(Icons.tag_rounded),
                            filled: true,
                            fillColor: const Color(0xFF171A28),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onSubmitted: (text) {
                            final cleaned = text.trim().replaceFirst('#', '');
                            if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleaned)) {
                              applyColor(
                                Color(0xFF000000 | int.parse(cleaned, radix: 16)),
                                setSheetState,
                              );
                            } else {
                              colorController.text = colorHex(Color(_selectedColor));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: Color(_selectedColor),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white38),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Expanded(child: Text('Matiz')),
                      Text(hue.round().toString() + '°',
                          style: const TextStyle(color: Color(0xFFB7A9FF))),
                    ],
                  ),
                  Slider(
                    value: hue.clamp(0, 360).toDouble(),
                    min: 0,
                    max: 360,
                    divisions: 360,
                    activeColor: const Color(0xFF8B70FF),
                    onChanged: (value) {
                      hue = value;
                      applyHsv(setSheetState);
                    },
                  ),
                  Row(
                    children: [
                      const Expanded(child: Text('Saturação')),
                      Text((saturation * 100).round().toString() + '%',
                          style: const TextStyle(color: Color(0xFFB7A9FF))),
                    ],
                  ),
                  Slider(
                    value: saturation.clamp(0, 1).toDouble(),
                    min: 0,
                    max: 1,
                    divisions: 100,
                    activeColor: const Color(0xFF8B70FF),
                    onChanged: (value) {
                      saturation = value;
                      applyHsv(setSheetState);
                    },
                  ),
                  Row(
                    children: [
                      const Expanded(child: Text('Luminosidade')),
                      Text((brightness * 100).round().toString() + '%',
                          style: const TextStyle(color: Color(0xFFB7A9FF))),
                    ],
                  ),
                  Slider(
                    value: brightness.clamp(0, 1).toDouble(),
                    min: 0,
                    max: 1,
                    divisions: 100,
                    activeColor: const Color(0xFF8B70FF),
                    onChanged: (value) {
                      brightness = value;
                      applyHsv(setSheetState);
                    },
                  ),
                  const SizedBox(height: 21),
                  Row(children: [
                    const Expanded(child: Text('Espessura', style: TextStyle(fontWeight: FontWeight.w800))),
                    Text('${_brushSize.round()} px',
                      style: const TextStyle(color: Color(0xFFB7A9FF), fontWeight: FontWeight.w800)),
                  ]),
                  Slider(
                    value: _brushSize.clamp(1, 40).toDouble(),
                    min: 1, max: 40, divisions: 39,
                    activeColor: const Color(0xFF8B70FF),
                    onChanged: (value) {
                      setState(() => _brushSize = value);
                      setSheetState(() {});
                    },
                  ),
                  Row(children: [
                    const Expanded(child: Text('Opacidade', style: TextStyle(fontWeight: FontWeight.w800))),
                    Text('${(_opacity * 100).round()}%',
                      style: const TextStyle(color: Color(0xFFB7A9FF), fontWeight: FontWeight.w800)),
                  ]),
                  Slider(
                    value: _opacity, min: .1, max: 1, divisions: 9,
                    activeColor: const Color(0xFF8B70FF),
                    onChanged: (value) {
                      setState(() => _opacity = value);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF171A28), borderRadius: BorderRadius.circular(15)),
                    child: Row(children: [
                      Container(
                        width: 60, height: 45,
                        decoration: BoxDecoration(color: const Color(0xFFFAFAFF), borderRadius: BorderRadius.circular(10)),
                        child: Center(
                          child: Container(
                            height: _brushSize.clamp(1, 40).toDouble(),
                            width: _brushSize.clamp(1, 40).toDouble(),
                            decoration: BoxDecoration(color: Color(_selectedColor).withOpacity(_opacity), shape: BoxShape.circle),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pré-visualização', style: TextStyle(fontWeight: FontWeight.w800)),
                          SizedBox(height: 3),
                          Text('As definições aplicam-se aos novos traços.',
                            style: TextStyle(fontSize: 11, color: Colors.white60)),
                        ],
                      )),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6650DE)),
                      child: const Text('Aplicar pincel'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    colorController.dispose();
  }

  Future<void> _openEffects() async {
    const effects = <(String, String, String, IconData)>[
      ('Brilho neon', 'brilho neon', 'Brilho suave e colorido para contornos luminosos.', Icons.flare_rounded),
      ('Rastro de movimento', 'rastro de movimento', 'Cria um rasto subtil atrás dos traços.', Icons.blur_on_rounded),
      ('Linha tracejada', 'linha tracejada', 'Desenha uma linha interrompida.', Icons.more_horiz_rounded),
      ('Luz energética', 'luz energética', 'Um brilho mais intenso para impactos e energia.', Icons.bolt_rounded),
    ];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF202231),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Efeitos de traço', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Escolhe um efeito para os próximos traços. As opções ficam disponíveis gratuitamente.',
                  style: TextStyle(color: Colors.white70, height: 1.35)),
              const SizedBox(height: 10),
              for (final effect in effects)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Icon(effect.$4, color: const Color(0xFFB5A8FF)),
                  title: Text(effect.$1),
                  subtitle: Text(effect.$3),
                  trailing: _brushStyle == effect.$2
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF7CE0CC))
                      : const Icon(Icons.circle_outlined, color: Colors.white38),
                  onTap: () {
                    setState(() => _brushStyle = effect.$2);
                    Navigator.of(sheetContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Efeito aplicado aos próximos traços: ${effect.$1}')),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _insertAsset(String id) async {
    final center = Offset(_canvasSize.width / 2, _canvasSize.height / 2);
    final double unit = math.min(_canvasSize.width, _canvasSize.height).toDouble() * .14;
    final newStrokes = <StrokeModel>[];

    const ink = Color(0xFF1C2940).value;
    const orange = Color(0xFFF39A4A).value;
    const coral = Color(0xFFEC7193).value;
    const blue = Color(0xFF4CADD2).value;
    const green = Color(0xFF4FB878).value;
    const brown = Color(0xFF9A623C).value;
    const yellow = Color(0xFFF3BC42).value;
    const sky = Color(0xFF83C8F1).value;

    void add(
      List<Offset> points, {
      String kind = 'pen',
      double width = 3,
      int? colorOverride,
    }) {
      newStrokes.add(StrokeModel(
        points: points,
        color: colorOverride ?? ink,
        width: width,
        kind: kind,
      ));
    }
    List<Offset> oval(Offset c, double rx, double ry, {int count = 36}) =>
        List<Offset>.generate(count + 1, (i) {
          final angle = i / count * math.pi * 2;
          return Offset(c.dx + math.cos(angle) * rx, c.dy + math.sin(angle) * ry);
        });
    void circle(Offset c, double radius, {int? colorOverride}) {
      add(
        [Offset(c.dx - radius, c.dy - radius), Offset(c.dx + radius, c.dy + radius)],
        kind: 'ellipse',
        colorOverride: colorOverride,
      );
    }

    switch (id) {
      case 'star':
        final points = List<Offset>.generate(11, (i) {
          final angle = -math.pi / 2 + i * math.pi / 5;
          final radius = i.isEven ? unit : unit * .43;
          return Offset(center.dx + math.cos(angle) * radius, center.dy + math.sin(angle) * radius);
        });
        add([...points, points.first], width: 3.5);
        circle(Offset(center.dx - unit * .14, center.dy - unit * .24), unit * .06, colorOverride: yellow);
        add([
          Offset(center.dx + unit * .22, center.dy - unit * .18),
          Offset(center.dx + unit * .42, center.dy - unit * .18),
        ], width: 2.2, colorOverride: yellow);
        add([
          Offset(center.dx + unit * .32, center.dy - unit * .28),
          Offset(center.dx + unit * .32, center.dy - unit * .08),
        ], width: 2.2, colorOverride: yellow);
        break;
      case 'heart':
        final heart = List<Offset>.generate(81, (i) {
          final t = i / 80 * math.pi * 2;
          final x = 16 * math.pow(math.sin(t), 3).toDouble();
          final y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t);
          return Offset(center.dx + x * unit / 18, center.dy - y * unit / 18);
        });
        add(heart, width: 3.4, colorOverride: coral);
        add([
          Offset(center.dx - unit * .45, center.dy - unit * .45),
          Offset(center.dx - unit * .27, center.dy - unit * .61),
        ], width: 2.2, colorOverride: 0xFFFFBCD0);
        circle(Offset(center.dx + unit * .4, center.dy - unit * .5), unit * .06, colorOverride: coral);
        break;
      case 'face':
      case 'fox':
        add([Offset(center.dx - unit * .82, center.dy - unit * .75), Offset(center.dx + unit * .82, center.dy + unit * .75)], kind: 'ellipse', width: 3.2);
        circle(Offset(center.dx - unit * .28, center.dy - unit * .12), unit * .09);
        circle(Offset(center.dx + unit * .28, center.dy - unit * .12), unit * .09);
        circle(Offset(center.dx - unit * .47, center.dy + unit * .12), unit * .08, colorOverride: coral);
        circle(Offset(center.dx + unit * .47, center.dy + unit * .12), unit * .08, colorOverride: coral);
        add([
          Offset(center.dx - unit * .28, center.dy + unit * .22),
          Offset(center.dx - unit * .18, center.dy + unit * .34), center,
          Offset(center.dx + unit * .18, center.dy + unit * .34),
          Offset(center.dx + unit * .28, center.dy + unit * .22),
        ], width: 2.7, colorOverride: coral);
        if (id == 'fox') {
          add([
            Offset(center.dx - unit * .68, center.dy - unit * .55),
            Offset(center.dx - unit * .52, center.dy - unit * 1.25),
            Offset(center.dx - unit * .08, center.dy - unit * .72),
            Offset(center.dx + unit * .08, center.dy - unit * .72),
            Offset(center.dx + unit * .52, center.dy - unit * 1.25),
            Offset(center.dx + unit * .68, center.dy - unit * .55),
          ], width: 3.2);
          add([
            Offset(center.dx - unit * .49, center.dy - unit * .72),
            Offset(center.dx - unit * .43, center.dy - unit * 1.02),
            Offset(center.dx - unit * .24, center.dy - unit * .77),
          ], width: 2.1, colorOverride: orange);
          add([
            Offset(center.dx + unit * .24, center.dy - unit * .77),
            Offset(center.dx + unit * .43, center.dy - unit * 1.02),
            Offset(center.dx + unit * .49, center.dy - unit * .72),
          ], width: 2.1, colorOverride: orange);
          add([
            Offset(center.dx - unit * .32, center.dy + unit * .12),
            Offset(center.dx - unit * .63, center.dy + unit * .08),
          ], width: 1.5, colorOverride: ink);
          add([
            Offset(center.dx + unit * .32, center.dy + unit * .12),
            Offset(center.dx + unit * .63, center.dy + unit * .08),
          ], width: 1.5, colorOverride: ink);
        } else {
          add([
            Offset(center.dx - unit * .55, center.dy - unit * .37),
            Offset(center.dx - unit * .24, center.dy - unit * .32),
          ], width: 2.5, colorOverride: brown);
          add([
            Offset(center.dx + unit * .24, center.dy - unit * .32),
            Offset(center.dx + unit * .55, center.dy - unit * .37),
          ], width: 2.5, colorOverride: brown);
        }
        break;
      case 'robot':
        add([Offset(center.dx - unit * .72, center.dy - unit * .85), Offset(center.dx + unit * .72, center.dy + unit * .05)], kind: 'rectangle', width: 3.2);
        add([Offset(center.dx - unit * .5, center.dy + unit * .15), Offset(center.dx + unit * .5, center.dy + unit * .95)], kind: 'rectangle', width: 3.2);
        circle(Offset(center.dx - unit * .28, center.dy - unit * .48), unit * .08, colorOverride: blue);
        circle(Offset(center.dx + unit * .28, center.dy - unit * .48), unit * .08, colorOverride: blue);
        add([
          Offset(center.dx - unit * .21, center.dy - unit * .24),
          Offset(center.dx, center.dy - unit * .17),
          Offset(center.dx + unit * .21, center.dy - unit * .24),
        ], width: 2.5, colorOverride: blue);
        add([Offset(center.dx, center.dy - unit * .86), Offset(center.dx, center.dy - unit * 1.15)]);
        circle(Offset(center.dx, center.dy - unit * 1.22), unit * .08, colorOverride: coral);
        add([
          Offset(center.dx - unit * .28, center.dy + unit * .43),
          Offset(center.dx + unit * .28, center.dy + unit * .43),
        ], width: 3, colorOverride: blue);
        circle(Offset(center.dx - unit * .16, center.dy + unit * .64), unit * .05, colorOverride: coral);
        circle(Offset(center.dx, center.dy + unit * .64), unit * .05, colorOverride: yellow);
        circle(Offset(center.dx + unit * .16, center.dy + unit * .64), unit * .05, colorOverride: green);
        add([
          Offset(center.dx - unit * .72, center.dy - unit * .1),
          Offset(center.dx - unit * 1.02, center.dy + unit * .12),
          Offset(center.dx - unit * .85, center.dy + unit * .42),
        ], width: 2.8, colorOverride: blue);
        add([
          Offset(center.dx + unit * .72, center.dy - unit * .1),
          Offset(center.dx + unit * 1.02, center.dy + unit * .12),
          Offset(center.dx + unit * .85, center.dy + unit * .42),
        ], width: 2.8, colorOverride: blue);
        break;
      case 'tree':
        add([Offset(center.dx - unit * .18, center.dy + unit * .2), Offset(center.dx + unit * .18, center.dy + unit)], kind: 'rectangle', width: 3.3, colorOverride: brown);
        add([Offset(center.dx - unit * .78, center.dy - unit * .1), Offset(center.dx + unit * .78, center.dy + unit * .66)], kind: 'ellipse', width: 3.3, colorOverride: green);
        add([Offset(center.dx - unit * .58, center.dy - unit * .35), Offset(center.dx + unit * .58, center.dy + unit * .4)], kind: 'ellipse', width: 3.3, colorOverride: green);
        add([
          Offset(center.dx - unit * .12, center.dy + unit * .45),
          Offset(center.dx - unit * .42, center.dy + unit * .12),
        ], width: 2.4, colorOverride: brown);
        add([
          Offset(center.dx + unit * .12, center.dy + unit * .58),
          Offset(center.dx + unit * .43, center.dy + unit * .18),
        ], width: 2.4, colorOverride: brown);
        circle(Offset(center.dx - unit * .32, center.dy - unit * .22), unit * .08, colorOverride: 0xFF93D5A8);
        circle(Offset(center.dx + unit * .28, center.dy - unit * .09), unit * .08, colorOverride: 0xFF93D5A8);
        break;
      case 'cloud':
        add(oval(center, unit, unit * .45), width: 3.2, colorOverride: sky);
        add(oval(Offset(center.dx - unit * .4, center.dy - unit * .22), unit * .48, unit * .42), width: 3.2, colorOverride: sky);
        add(oval(Offset(center.dx + unit * .28, center.dy - unit * .28), unit * .55, unit * .48), width: 3.2, colorOverride: sky);
        for (var drop = -1; drop <= 1; drop++) {
          final x = center.dx + drop * unit * .48;
          add([
            Offset(x, center.dy + unit * .56),
            Offset(x - unit * .08, center.dy + unit * .79),
          ], width: 2.7, colorOverride: blue);
        }
        break;
      case 'house':
        add([Offset(center.dx - unit * .75, center.dy - unit * .1), Offset(center.dx + unit * .75, center.dy + unit * .8)], kind: 'rectangle', width: 3.2);
        add([
          Offset(center.dx - unit * .95, center.dy - unit * .1),
          Offset(center.dx, center.dy - unit * .95),
          Offset(center.dx + unit * .95, center.dy - unit * .1),
        ], width: 3.2, colorOverride: coral);
        add([Offset(center.dx - unit * .17, center.dy + unit * .25), Offset(center.dx + unit * .17, center.dy + unit * .8)], kind: 'rectangle', width: 2.5, colorOverride: brown);
        add([
          Offset(center.dx - unit * .6, center.dy + unit * .12),
          Offset(center.dx - unit * .34, center.dy + unit * .12),
          Offset(center.dx - unit * .34, center.dy + unit * .37),
          Offset(center.dx - unit * .6, center.dy + unit * .37),
          Offset(center.dx - unit * .6, center.dy + unit * .12),
        ], width: 2.4, colorOverride: blue);
        add([
          Offset(center.dx + unit * .34, center.dy + unit * .12),
          Offset(center.dx + unit * .6, center.dy + unit * .12),
          Offset(center.dx + unit * .6, center.dy + unit * .37),
          Offset(center.dx + unit * .34, center.dy + unit * .37),
          Offset(center.dx + unit * .34, center.dy + unit * .12),
        ], width: 2.4, colorOverride: blue);
        circle(Offset(center.dx + unit * .09, center.dy + unit * .56), unit * .025, colorOverride: yellow);
        break;
      default:
        circle(center, unit * .6);
        break;
    }

    _rememberUndo();
    setState(() => _activeLayer.strokes.addAll(newStrokes));
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draftPoints == null
        ? null
        : StrokeModel(
            points: _draftPoints!,
            color: _activeColor,
            width: (_tool == _DrawingTool.eraser ? math.max(_brushSize, 8) : _brushSize).toDouble(),
            kind: _strokeKind,
            brushStyle: _tool == _DrawingTool.eraser ? 'borracha' : _brushStyle,
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
          children: [
            Text(widget.project.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text('Frame ${_currentFrameIndex + 1} / ${_frames.length}',
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(.55))),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _isPreviewPlaying ? 'Pausar animação' : 'Reproduzir animação',
            onPressed: _togglePreviewPlayback,
            icon: Icon(_isPreviewPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded),
          ),
          if (widget.project.audioPath.isNotEmpty)
            IconButton(
              tooltip: _isProjectAudioPlaying ? 'Pausar áudio do projeto' : 'Reproduzir áudio do projeto',
              onPressed: _toggleProjectAudio,
              icon: Icon(_isProjectAudioPlaying ? Icons.volume_up_rounded : Icons.music_note_rounded),
            ),
          IconButton(tooltip: 'Exportar', onPressed: _openExport, icon: const Icon(Icons.ios_share_rounded)),
          IconButton(tooltip: 'Guardar projeto', onPressed: _saveAndShowMessage, icon: const Icon(Icons.save_outlined)),
          const SizedBox(width: 3),
        ],
      ),
      body: Column(
        children: [
          _buildLayerSelector(),
          if (widget.project.audioPath.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 7),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF172B35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF31515E)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.audiotrack_rounded, color: Color(0xFF65D6E8), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Áudio: ${widget.project.audioPath.split(Platform.pathSeparator).last}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: _isProjectAudioPlaying ? 'Pausar áudio' : 'Ouvir áudio',
                      visualDensity: VisualDensity.compact,
                      onPressed: _toggleProjectAudio,
                      icon: Icon(_isProjectAudioPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    ),
                    IconButton(
                      tooltip: 'Remover áudio do projeto',
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await _projectAudioPlayer.stop();
                        widget.project.audioPath = '';
                        await _persist();
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Row(
              children: [
                InkWell(
                  onTap: _openBrushSettings,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                    decoration: BoxDecoration(color: const Color(0xFF202332), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Container(height: 20, width: 20,
                        decoration: BoxDecoration(color: Color(_selectedColor), shape: BoxShape.circle, border: Border.all(color: Colors.white24))),
                      const SizedBox(width: 7),
                      Text('${_brushSize.round()} px', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 5),
                      const Icon(Icons.tune_rounded, size: 15),
                    ]),
                  ),
                ),
                const Spacer(),
                _tinyToggle(icon: Icons.grid_4x4_rounded, label: 'Grelha', selected: _showGrid,
                  onTap: () => setState(() => _showGrid = !_showGrid)),
                const SizedBox(width: 7),
                _tinyToggle(
                  icon: Icons.layers_outlined,
                  label: 'Onion',
                  selected: _onionSkin,
                  onTap: () => setState(() => _onionSkin = !_onionSkin),
                  onLongPress: _openOnionSettings,
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 9),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(.2), blurRadius: 12, offset: const Offset(0, 6))],
                ),
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: _isPreviewPlaying ? null : _startStroke,
                      onPanUpdate: _isPreviewPlaying ? null : _updateStroke,
                      onPanEnd: _isPreviewPlaying ? null : _finishStroke,
                      onPanCancel: _isPreviewPlaying ? null : () => setState(() => _draftPoints = null),
                      child: CustomPaint(
                        painter: _AnimationCanvasPainter(
                          frame: _currentFrame,
                          previousFrame: _previousFrame,
                          nextFrame: _nextFrame,
                          onionOpacity: _onionOpacity,
                          draft: draft,
                          showGrid: _showGrid,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    );
                  },
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

  Widget _tinyToggle({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF373052) : const Color(0xFF202332),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected ? const Color(0xFF897CFF) : const Color(0xFF303447)),
        ),
        child: Row(children: [
          Icon(icon, size: 14, color: selected ? const Color(0xFFC4BAFF) : Colors.white60),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: selected ? const Color(0xFFC4BAFF) : Colors.white60)),
        ]),
      ),
    );
  }

  Widget _buildLayerSelector() {
    const names = <String>['Linha', 'Cor', 'Fundo'];
    const icons = <IconData>[Icons.gesture_rounded, Icons.palette_outlined, Icons.wallpaper_rounded];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: List<Widget>.generate(3, (index) {
          final layer = _currentFrame.layers[index];
          final selected = _selectedLayerIndex == index;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == 2 ? 0 : 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _changeLayer(index),
                onLongPress: () => _toggleLayerVisibility(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF343052) : const Color(0xFF1A1D2B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selected ? const Color(0xFF8C7DFF) : const Color(0xFF2D3143)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(icons[index], size: 14, color: selected ? const Color(0xFFB9AEFF) : Colors.white60),
                    const SizedBox(width: 4),
                    Flexible(child: Text(names[index], maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w800 : FontWeight.w500))),
                    const SizedBox(width: 3),
                    Icon(layer.visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      size: 12, color: layer.visible ? Colors.white38 : const Color(0xFFE67A8B)),
                  ]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildToolBar() {
    final tools = <({IconData icon, String label, _DrawingTool tool})>[
      (icon: Icons.edit_rounded, label: 'Caneta', tool: _DrawingTool.pen),
      (icon: Icons.auto_fix_normal_rounded, label: 'Borracha', tool: _DrawingTool.eraser),
      (icon: Icons.show_chart_rounded, label: 'Linha', tool: _DrawingTool.line),
      (icon: Icons.crop_square_rounded, label: 'Retângulo', tool: _DrawingTool.rectangle),
      (icon: Icons.circle_outlined, label: 'Elipse', tool: _DrawingTool.ellipse),
      (icon: Icons.straighten_rounded, label: 'Régua', tool: _DrawingTool.ruler),
    ];
    return Container(
      height: 74,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 7),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFF1B1E2C), borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF303447))),
      child: Row(children: [
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              for (final item in tools)
                _toolButton(icon: item.icon, label: item.label, selected: item.tool == _tool, onPressed: () => _chooseTool(item.tool)),
              _toolButton(icon: Icons.undo_rounded, label: 'Desfazer', onPressed: _undo),
              _toolButton(icon: Icons.redo_rounded, label: 'Refazer', onPressed: _redo),
              _toolButton(icon: Icons.delete_sweep_outlined, label: 'Limpar', onPressed: _clearLayer),
            ],
          ),
        ),
        Container(width: 1, height: 43, color: const Color(0xFF36394B)),
        InkWell(
          onTap: _openBrushSettings,
          child: const SizedBox(width: 52, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.tune_rounded, color: Color(0xFFB7ACFF), size: 21),
            SizedBox(height: 4),
            Text('Pincel', style: TextStyle(fontSize: 9, color: Color(0xFFB7ACFF))),
          ])),
        ),
      ]),
    );
  }

  Widget _toolButton({required IconData icon, required String label, required VoidCallback onPressed, bool selected = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onPressed,
      child: Container(
        width: 61,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 1),
        decoration: BoxDecoration(color: selected ? const Color(0xFF363052) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 21, color: selected ? const Color(0xFFB7ACFF) : Colors.white70),
          const SizedBox(height: 3),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: selected ? const Color(0xFFB7ACFF) : Colors.white60)),
        ]),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        height: 63,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: const BoxDecoration(color: Color(0xFF11131F), border: Border(top: BorderSide(color: Color(0xFF292D40)))),
        child: Row(children: [
          _bottomItem(icon: Icons.palette_outlined, label: 'Pincéis', color: const Color(0xFF9D91FF), onPressed: _openBrushSettings),
          _bottomItem(icon: Icons.auto_awesome_rounded, label: 'Efeitos', color: const Color(0xFF65D6E8), onPressed: _openEffects),
          _bottomItem(icon: Icons.view_timeline_rounded, label: 'Timeline', color: const Color(0xFF9D91FF), onPressed: _openTimeline),
          _bottomItem(icon: Icons.hub_rounded, label: 'Rigging', color: const Color(0xFF39D8E9), onPressed: _openRigging),
          _bottomItem(icon: Icons.graphic_eq_rounded, label: 'Áudio', color: const Color(0xFF50D3E4), onPressed: _openAudioLipSync),
          _bottomItem(icon: Icons.folder_open_rounded, label: 'Assets', onPressed: _openAssets),
          _bottomItem(icon: Icons.ios_share_rounded, label: 'Exportar', onPressed: _openExport),
        ]),
      ),
    );
  }

  Widget _bottomItem({required IconData icon, required String label, required VoidCallback onPressed, Color color = Colors.white70}) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: color, fontSize: 9.5)),
        ]),
      ),
    );
  }
}

class _AnimationCanvasPainter extends CustomPainter {
  _AnimationCanvasPainter({
    required this.frame,
    required this.previousFrame,
    required this.nextFrame,
    required this.onionOpacity,
    required this.draft,
    required this.showGrid,
  });
  final FrameModel frame;
  final FrameModel? previousFrame;
  final FrameModel? nextFrame;
  final double onionOpacity;
  final StrokeModel? draft;
  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    if (showGrid) {
      final gridPaint = Paint()..color = const Color(0xFFEDEFF4)..strokeWidth = .7;
      for (double x = 0; x < size.width; x += 24) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y < size.height; y += 24) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }
    if (previousFrame != null) _paintFrame(canvas, previousFrame!, onionOpacity);
    if (nextFrame != null) _paintFrame(canvas, nextFrame!, onionOpacity * .55);
    _paintFrame(canvas, frame, 1);
    if (draft != null) _paintStroke(canvas, draft!, 1);
  }

  void _paintFrame(Canvas canvas, FrameModel target, double opacity) {
    for (final layer in target.layers.reversed) {
      if (!layer.visible) continue;
      for (final stroke in layer.strokes) {
        _paintStroke(canvas, stroke, opacity);
      }
    }
  }

  void _paintStroke(Canvas canvas, StrokeModel stroke, double opacity) {
    if (stroke.points.isEmpty) return;
    final baseColor = Color(stroke.color);
    var width = stroke.width;
    var alpha = baseColor.opacity * opacity;
    final paint = Paint()
      ..color = baseColor.withOpacity(alpha)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    switch (stroke.brushStyle) {
      case 'caneta técnica':
        width *= .55;
        break;
      case 'tinta':
        width *= .85;
        break;
      case 'tinta chinesa':
        width *= .75;
        break;
      case 'pincel suave':
        width *= 1.7;
        paint.maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(1.0, width * .18).toDouble(),
        );
        break;
      case 'pincel seco':
        width *= 1.5;
        alpha *= .42;
        paint.strokeCap = StrokeCap.square;
        paint.strokeJoin = StrokeJoin.bevel;
        break;
      case 'marcador':
        width *= 2.5;
        alpha *= .55;
        break;
      case 'aerógrafo':
        width *= 2.3;
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.0, width * .24).toDouble());
        break;
      case 'giz de cera':
        width *= 1.25;
        paint.strokeCap = StrokeCap.square;
        break;
      case 'marca-texto':
        width *= 3.2;
        alpha *= .32;
        paint.strokeCap = StrokeCap.square;
        break;
      case 'pastel':
        width *= 1.8;
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.0, width * .12).toDouble());
        break;
      case 'brilho neon':
        width *= 1.25;
        break;
      case 'luz energética':
        width *= 1.6;
        break;
      case 'rastro de movimento':
        width *= 1.2;
        alpha *= .75;
        break;
      case 'linha tracejada':
        break;
      case 'pixel':
        paint.strokeCap = StrokeCap.square;
        paint.strokeJoin = StrokeJoin.miter;
        break;
      default:
        break;
    }
    paint
      ..color = baseColor.withOpacity(alpha)
      ..strokeWidth = width;

    if (stroke.points.length == 1) {
      final point = stroke.points.first;
      if (stroke.brushStyle == 'brilho neon' || stroke.brushStyle == 'luz energética') {
        final glowPaint = Paint()
          ..color = baseColor.withOpacity((alpha * .8).clamp(0.0, 1.0).toDouble())
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            math.max(2.0, width * .65).toDouble(),
          );
        canvas.drawCircle(point, width * 1.15, glowPaint);
        canvas.drawCircle(
          point,
          math.max(1.0, width * .3).toDouble(),
          Paint()..color = baseColor.withOpacity(alpha),
        );
      } else {
        canvas.drawCircle(point, width / 2, paint..style = PaintingStyle.fill);
      }
      return;
    }

    final first = stroke.points.first;
    final last = stroke.points.last;
    final path = Path();
    if (stroke.kind == 'line' || stroke.kind == 'ruler') {
      path.moveTo(first.dx, first.dy);
      path.lineTo(last.dx, last.dy);
    } else if (stroke.kind == 'rectangle') {
      path.addRect(Rect.fromPoints(first, last));
    } else if (stroke.kind == 'ellipse') {
      path.addOval(Rect.fromPoints(first, last));
    } else {
      path.moveTo(first.dx, first.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
    }

    if (stroke.brushStyle == 'linha tracejada') {
      for (final metric in path.computeMetrics()) {
        for (var distance = 0.0; distance < metric.length; distance += 16.0) {
          final end = math.min(distance + 9.0, metric.length).toDouble();
          canvas.drawPath(metric.extractPath(distance, end), paint);
        }
      }
    } else if (stroke.brushStyle == 'brilho neon' || stroke.brushStyle == 'luz energética') {
      final intensity = stroke.brushStyle == 'luz energética' ? 2.8 : 2.0;
      final blur = stroke.brushStyle == 'luz energética' ? width * .9 : width * .6;
      final glowPaint = Paint()
        ..color = baseColor.withOpacity((alpha * .78).clamp(0.0, 1.0).toDouble())
        ..strokeWidth = width * intensity
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(2.0, blur).toDouble(),
        );
      canvas.drawPath(path, glowPaint);
      final corePaint = Paint()
        ..color = baseColor.withOpacity(alpha)
        ..strokeWidth = math.max(1.0, width * .48).toDouble()
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, corePaint);
    } else if (stroke.brushStyle == 'rastro de movimento') {
      final trailPaint = Paint()
        ..color = baseColor.withOpacity((alpha * .24).clamp(0.0, 1.0).toDouble())
        ..strokeWidth = math.max(1.0, width * .85).toDouble()
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(1.0, width * .22).toDouble(),
        );
      canvas.drawPath(path.shift(Offset(-width * 1.2, width * .35)), trailPaint);
      canvas.drawPath(path, paint);
    } else {
      canvas.drawPath(path, paint);
    }

    if (stroke.kind == 'ruler') {
      final delta = last - first;
      final length = delta.distance;
      if (length > 1) {
        final perpendicular = Offset(-delta.dy / length, delta.dx / length);
        for (var tick = 0; tick <= 20; tick++) {
          final t = tick / 20;
          final point = first + delta * t;
          final tickSize = tick % 5 == 0 ? 8.0 : 4.0;
          canvas.drawLine(point - perpendicular * tickSize, point + perpendicular * tickSize, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AnimationCanvasPainter oldDelegate) => true;
}


/// Tiny live brush samples shown beside every brush name.
class _BrushPreviewPainter extends CustomPainter {
  const _BrushPreviewPainter({required this.style, required this.color});

  final String style;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(1, size.height * .72)
      ..cubicTo(size.width * .24, size.height * .05, size.width * .56,
          size.height * .98, size.width - 1, size.height * .28);
    final width = style == 'caneta técnica'
        ? 1.1
        : style == 'marcador' || style == 'marca-texto'
            ? 4.8
            : style == 'tinta chinesa'
                ? 3.8
                : 2.4;
    if (style == 'brilho neon' || style == 'luz energética') {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(.34)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * 3
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
      );
    }
    if (style == 'rastro de movimento') {
      canvas.drawPath(
        path.shift(const Offset(-1.5, 2)),
        Paint()
          ..color = color.withOpacity(.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * 1.6
          ..strokeCap = StrokeCap.round,
      );
    }
    if (style == 'linha tracejada' || style == 'pixel') {
      for (var x = 1.0; x < size.width; x += style == 'pixel' ? 4 : 6) {
        if (style == 'pixel') {
          canvas.drawRect(
            Rect.fromLTWH(x, size.height * .42, 2.4, 2.4),
            Paint()..color = color,
          );
        } else {
          canvas.drawLine(
            Offset(x, size.height * .52),
            Offset(math.min(x + 3.4, size.width), size.height * .52),
            Paint()
              ..color = color
              ..strokeWidth = width
              ..strokeCap = StrokeCap.round,
          );
        }
      }
      return;
    }
    if (style == 'aerógrafo' || style == 'pincel suave') {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * 2
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    if (style == 'giz de cera' || style == 'pastel' || style == 'pincel seco') {
      for (var i = -2; i <= 2; i++) {
        canvas.drawPath(
          path.shift(Offset(0, i * 1.15)),
          Paint()
            ..color = color.withOpacity(i == 0 ? .8 : .2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .7
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = style == 'marca-texto' ? color.withOpacity(.55) : color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _BrushPreviewPainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.color != color;
}
