import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import '../services/app_locale.dart';

import '../models/project_model.dart';

/// Oficina de sincronização labial: importa/reproduz áudio, marca poses de boca
/// pelo tempo da reprodução e cria frames com essas poses.
class AudioLipSyncScreen extends StatefulWidget {
  const AudioLipSyncScreen({
    required this.frames,
    required this.canvasSize,
    required this.onApplyFrames,
    super.key,
  });

  final List<FrameModel> frames;
  final Size canvasSize;
  final Future<void> Function(List<FrameModel>) onApplyFrames;

  @override
  State<AudioLipSyncScreen> createState() => _AudioLipSyncScreenState();
}

class _AudioLipSyncScreenState extends State<AudioLipSyncScreen> {
  static const _phonemes = <String>['A / Ah', 'E / Ee', 'O / Oh', 'M / B / P', 'I / S', 'U / W'];
  static const _phonemeColors = <Color>[
    Color(0xFFFFB15C), Color(0xFF4BCFE4), Color(0xFFFFCF70),
    Color(0xFF4CC8BD), Color(0xFF70BDFF), Color(0xFFC3A0FF),
  ];

  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions = <StreamSubscription<dynamic>>[];
  final List<_PhonemeEvent> _events = <_PhonemeEvent>[];

  String? _audioPath;
  String _audioName = 'Nenhum áudio selecionado';
  String _selectedPhoneme = 'A / Ah';
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isImporting = false;
  bool _showAutomaticMappingNote = false;
  int _fps = 24;

  @override
  void initState() {
    super.initState();
    _subscriptions.add(_player.onDurationChanged.listen((value) {
      if (mounted) setState(() => _duration = value);
    }));
    _subscriptions.add(_player.onPositionChanged.listen((value) {
      if (mounted) setState(() => _position = value);
    }));
    _subscriptions.add(_player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    }));
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  String _timeLabel(Duration value) {
    final seconds = value.inSeconds;
    final minutes = seconds ~/ 60;
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _importAudio() async {
    setState(() => _isImporting = true);
    try {
      // file_picker v12+ devolve PlatformFile diretamente ao escolher um só ficheiro.
      final file = await FilePicker.pickFile(type: FileType.audio);
      if (file == null) return;
      final path = file.path;
      if (path == null || path.isEmpty) {
        throw StateError('Não foi possível obter o caminho do áudio selecionado.');
      }
      await _player.stop();
      await _player.setSourceDeviceFile(path);
      final duration = await _player.getDuration();
      if (!mounted) return;
      setState(() {
        _audioPath = path;
        _audioName = file.name;
        _duration = duration ?? Duration.zero;
        _position = Duration.zero;
        _events.clear();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível importar este áudio. Confirma o formato do ficheiro e tenta novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _togglePlayback() async {
    final path = _audioPath;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Importa primeiro um ficheiro de áudio.')),
      );
      return;
    }
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_position >= _duration && _duration > Duration.zero) {
        await _player.seek(Duration.zero);
      }
      await _player.play(DeviceFileSource(path));
    }
  }

  void _addPhonemeAtCurrentTime() {
    if (_audioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Importa um áudio para marcar o tempo dos fonemas.')),
      );
      return;
    }
    setState(() {
      _events.add(_PhonemeEvent(
        position: _position,
        label: _selectedPhoneme,
      ));
      _events.sort((a, b) => a.position.compareTo(b.position));
    });
  }

  void _generateApproximateMap() {
    if (_audioPath == null || _duration <= Duration.zero) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Importa um áudio com duração válida primeiro.')),
      );
      return;
    }

    // Distribuição de poses para prototipagem; não é reconhecimento de fala por IA.
    final stepMs = math.max(260, _duration.inMilliseconds ~/ 18).toInt();
    final estimated = <_PhonemeEvent>[];
    for (var ms = 0, index = 0; ms < _duration.inMilliseconds; ms += stepMs, index++) {
      estimated.add(_PhonemeEvent(
        position: Duration(milliseconds: ms),
        label: _phonemes[index % _phonemes.length],
      ));
    }
    setState(() {
      _events
        ..clear()
        ..addAll(estimated);
      _showAutomaticMappingNote = true;
    });
  }

  List<StrokeModel> _mouthFor(String phoneme, Offset center) {
    const outline = 0xFF33233A;
    const inner = 0xFFDB718A;
    final x = center.dx;
    final y = center.dy;
    final strokes = <StrokeModel>[];

    void ellipse(double width, double height, int color, {double lineWidth = 3}) {
      strokes.add(StrokeModel(
        points: <Offset>[
          Offset(x - width, y - height),
          Offset(x + width, y + height),
        ],
        color: color,
        width: lineWidth,
        kind: 'ellipse',
        brushStyle: 'tinta',
      ));
    }

    void line(List<Offset> points, {int color = outline, double width = 3}) {
      strokes.add(StrokeModel(
        points: points,
        color: color,
        width: width,
        kind: 'pen',
        brushStyle: 'tinta',
      ));
    }

    switch (phoneme) {
      case 'A / Ah':
        ellipse(17, 14, outline);
        ellipse(8, 6, inner, lineWidth: 2);
        break;
      case 'E / Ee':
        ellipse(18, 6, outline);
        line(<Offset>[Offset(x - 12, y + 1), Offset(x + 12, y + 1)], color: inner, width: 2);
        break;
      case 'O / Oh':
        ellipse(9, 13, outline);
        ellipse(3, 6, inner, lineWidth: 2);
        break;
      case 'M / B / P':
        line(<Offset>[
          Offset(x - 18, y),
          Offset(x - 9, y - 3),
          Offset(x, y),
          Offset(x + 9, y - 3),
          Offset(x + 18, y),
        ], width: 3.5);
        break;
      case 'I / S':
        ellipse(15, 3, outline, lineWidth: 2.5);
        break;
      case 'U / W':
        ellipse(9, 7, outline);
        line(<Offset>[Offset(x - 4, y + 3), Offset(x + 4, y + 3)], color: inner, width: 2);
        break;
    }
    return strokes;
  }

  Future<void> _applyToTimeline() async {
    if (_events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adiciona fonemas ou cria um mapa aproximado antes de aplicar.')),
      );
      return;
    }

    final updated = widget.frames.map((frame) => frame.copy()).toList();
    if (updated.isEmpty) updated.add(FrameModel.blank());

    // Converte o instante de cada fonema para um número de frame usando o FPS.
    for (final event in _events) {
      final int targetFrame = (event.position.inMilliseconds * _fps / 1000).floor();
      while (updated.length <= targetFrame) {
        updated.add(updated.last.copy());
      }
      final layer = updated[targetFrame].layers.first;
      final center = Offset(
        widget.canvasSize.width * .5,
        widget.canvasSize.height * .57,
      );
      layer.strokes.addAll(_mouthFor(event.label, center));
    }

    await widget.onApplyFrames(updated);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds <= 0
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Lip Sync', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Limpar marcações',
            onPressed: () => setState(() {
              _events.clear();
              _showAutomaticMappingNote = false;
            }),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1F30),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF30354A)),
            ),
            child: Row(children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF3C345E),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.face_retouching_natural_rounded, color: Color(0xFFB9AEFF), size: 27),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Personagem atual', style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(height: 3),
                  Text('Preparado para poses de boca', style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              )),
              const Icon(Icons.graphic_eq_rounded, color: Color(0xFF50D3E4), size: 25),
            ]),
          ),
          const SizedBox(height: 22),
          const Text('Áudio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFF171A28),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF30354A)),
            ),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.audiotrack_rounded, color: Color(0xFF50D3E4)),
                const SizedBox(width: 9),
                Expanded(child: Text(_audioName, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                if (_audioPath != null)
                  IconButton(
                    tooltip: 'Remover áudio',
                    onPressed: () async {
                      await _player.stop();
                      setState(() {
                        _audioPath = null;
                        _audioName = 'Nenhum áudio selecionado';
                        _duration = Duration.zero;
                        _position = Duration.zero;
                        _events.clear();
                      });
                    },
                    icon: const Icon(Icons.close_rounded, size: 19),
                  ),
              ]),
              const SizedBox(height: 7),
              SizedBox(
                height: 77,
                width: double.infinity,
                child: CustomPaint(painter: _WaveformPainter(progress)),
              ),
              Row(children: [
                Text(_timeLabel(_position), style: const TextStyle(fontSize: 11, color: Colors.white60)),
                Expanded(
                  child: Slider(
                    value: progress,
                    onChanged: _duration > Duration.zero
                        ? (value) => _player.seek(Duration(milliseconds: (_duration.inMilliseconds * value).round()))
                        : null,
                    activeColor: const Color(0xFF55D2E5),
                    inactiveColor: const Color(0xFF3A4053),
                  ),
                ),
                Text(_timeLabel(_duration), style: const TextStyle(fontSize: 11, color: Colors.white60)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isImporting ? null : _importAudio,
                    icon: _isImporting
                        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.file_open_rounded),
                    label: Text(_isImporting ? 'A importar…' : 'Importar áudio'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _audioPath == null ? null : _togglePlayback,
                    icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    label: Text(_isPlaying ? 'Pausar' : 'Reproduzir'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFCB596F)),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 23),
          Row(children: [
            const Expanded(child: Text('Mapeamento labial', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFF263A46), borderRadius: BorderRadius.circular(9)),
              child: Text('${_events.length} marcas', style: const TextStyle(color: Color(0xFF79DCE8), fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'Seleciona a forma da boca e marca o instante da fala. O mapa automático gera poses distribuídas; não é reconhecimento fonético por IA.',
            style: TextStyle(fontSize: 12, height: 1.35, color: Colors.white.withOpacity(.62)),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _phonemes.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 9,
              mainAxisSpacing: 9,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              final label = _phonemes[index];
              final selected = label == _selectedPhoneme;
              return InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () => setState(() => _selectedPhoneme = label),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF243B48) : const Color(0xFF1D2130),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: selected ? const Color(0xFF62D8E7) : const Color(0xFF353A4D), width: selected ? 2 : 1),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    CustomPaint(
                      size: const Size(46, 27),
                      painter: _MouthIconPainter(index, _phonemeColors[index]),
                    ),
                    const SizedBox(height: 7),
                    Text(label, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                          color: selected ? const Color(0xFFB5F4F8) : Colors.white70)),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 13),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _audioPath == null ? null : _addPhonemeAtCurrentTime,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Marcar tempo atual'),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: FilledButton.icon(
                onPressed: _audioPath == null ? null : _generateApproximateMap,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Gerar mapa aproximado'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF5146B7)),
              ),
            ),
          ]),
          if (_showAutomaticMappingNote) ...[
            const SizedBox(height: 8),
            const Text('Mapa aproximado criado. Revisa as marcas e ajusta os fonemas manualmente.',
                style: TextStyle(color: Color(0xFF8DE1E9), fontSize: 11)),
          ],
          const SizedBox(height: 20),
          const Text('Marcas na timeline', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 9),
          if (_events.isEmpty)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: const Color(0xFF1B1F2D), borderRadius: BorderRadius.circular(13)),
              child: Text('Ainda não há fonemas marcados.', style: TextStyle(color: Colors.white.withOpacity(.55))),
            )
          else
            ..._events.asMap().entries.map((entry) {
              final index = entry.key;
              final event = entry.value;
              final phonemeIndex = _phonemes.indexOf(event.label).clamp(0, _phonemes.length - 1).toInt();
              return Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFF1B1F2D), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Container(width: 8, height: 28,
                    decoration: BoxDecoration(color: _phonemeColors[phonemeIndex], borderRadius: BorderRadius.circular(5))),
                  const SizedBox(width: 10),
                  SizedBox(width: 38, child: Text(_timeLabel(event.position),
                      style: const TextStyle(color: Colors.white60, fontSize: 11))),
                  Expanded(child: Text(event.label, style: const TextStyle(fontWeight: FontWeight.w700))),
                  IconButton(
                    tooltip: 'Ir para este instante',
                    onPressed: () => _player.seek(event.position),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Apagar marca',
                    onPressed: () => setState(() => _events.removeAt(index)),
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ]),
              );
            }),
          const SizedBox(height: 15),
          const Text('Frame rate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [12, 24, 30, 60].map((fps) => ChoiceChip(
            label: Text('$fps FPS'),
            selected: _fps == fps,
            onSelected: (_) => setState(() => _fps = fps),
            selectedColor: const Color(0xFF5146B7),
          )).toList()),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _events.isEmpty ? null : _applyToTimeline,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Aplicar à timeline', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF138BA1)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhonemeEvent {
  const _PhonemeEvent({required this.position, required this.label});
  final Duration position;
  final String label;
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = const Color(0xFF283044);
    final played = Paint()..color = const Color(0xFF43C6DB);
    final bars = (size.width / 5).floor();
    for (var i = 0; i < bars; i++) {
      // Forma de onda estilizada; a posição real vem do leitor de áudio.
      final value = (.15 + .75 * (math.sin(i * .43).abs() * .5 + math.cos(i * .17).abs() * .5))
          .clamp(.12, .95).toDouble();
      final height = size.height * value;
      final x = i * 5.0;
      final rect = Rect.fromLTWH(x, (size.height - height) / 2, 2.4, height);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          (i / math.max(1, bars) < progress) ? played : base);
    }
  }
  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) => oldDelegate.progress != progress;
}

class _MouthIconPainter extends CustomPainter {
  _MouthIconPainter(this.index, this.tint);
  final int index;
  final Color tint;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2),
        width: index == 1 || index == 4 ? 34 : index == 2 || index == 5 ? 17 : 28,
        height: index == 3 || index == 4 ? 5 : index == 1 ? 8 : index == 5 ? 13 : 19);
    canvas.drawOval(rect, Paint()..color = tint.withOpacity(.92));
    canvas.drawOval(rect.deflate(3), Paint()..color = const Color(0xFF352039));
  }
  @override
  bool shouldRepaint(covariant _MouthIconPainter oldDelegate) => false;
}
