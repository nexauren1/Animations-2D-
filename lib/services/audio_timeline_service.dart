import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A clip on one of the six editable audio lanes of the animation timeline.
///
/// trimEndMs == 0 means that the clip plays until its source file ends.
class AudioTimelineClip {
  const AudioTimelineClip({
    required this.id,
    required this.name,
    required this.path,
    required this.startFrame,
    required this.isPro,
    this.trackIndex = 0,
    this.trimStartMs = 0,
    this.trimEndMs = 0,
    this.volume = 1,
    this.muted = false,
    this.loop = false,
  });

  final String id;
  final String name;
  final String path;
  final int startFrame;
  final bool isPro;
  final int trackIndex;
  final int trimStartMs;
  final int trimEndMs;
  final double volume;
  final bool muted;
  final bool loop;

  AudioTimelineClip copyWith({
    String? id,
    String? name,
    String? path,
    int? startFrame,
    bool? isPro,
    int? trackIndex,
    int? trimStartMs,
    int? trimEndMs,
    double? volume,
    bool? muted,
    bool? loop,
  }) =>
      AudioTimelineClip(
        id: id ?? this.id,
        name: name ?? this.name,
        path: path ?? this.path,
        startFrame: startFrame ?? this.startFrame,
        isPro: isPro ?? this.isPro,
        trackIndex: trackIndex ?? this.trackIndex,
        trimStartMs: trimStartMs ?? this.trimStartMs,
        trimEndMs: trimEndMs ?? this.trimEndMs,
        volume: volume ?? this.volume,
        muted: muted ?? this.muted,
        loop: loop ?? this.loop,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'path': path,
        'startFrame': startFrame,
        'isPro': isPro,
        'trackIndex': trackIndex,
        'trimStartMs': trimStartMs,
        'trimEndMs': trimEndMs,
        'volume': volume,
        'muted': muted,
        'loop': loop,
      };

  factory AudioTimelineClip.fromJson(Map<String, dynamic> json) {
    final rawVolume = (json['volume'] as num?)?.toDouble() ?? 1;
    return AudioTimelineClip(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Áudio').toString(),
      path: (json['path'] ?? '').toString(),
      startFrame: (json['startFrame'] as num? ?? 0).toInt().clamp(0, 100000).toInt(),
      isPro: json['isPro'] == true,
      trackIndex: (json['trackIndex'] as num? ?? 0).toInt().clamp(0, 5).toInt(),
      trimStartMs: (json['trimStartMs'] as num? ?? 0).toInt().clamp(0, 86400000).toInt(),
      trimEndMs: (json['trimEndMs'] as num? ?? 0).toInt().clamp(0, 86400000).toInt(),
      volume: rawVolume.clamp(0.0, 1.0).toDouble(),
      muted: json['muted'] == true,
      loop: json['loop'] == true,
    );
  }
}

/// Stores audio placement independently from Isar's generated schema so that
/// projects can gain audio tracks without invalidating existing project files.
class AudioTimelineService {
  AudioTimelineService._();

  static String _key(String projectUid) => 'animpro_audio_timeline_$projectUid';

  static Future<List<AudioTimelineClip>> load(String projectUid) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(projectUid));
    if (raw == null || raw.isEmpty) return <AudioTimelineClip>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <AudioTimelineClip>[];
      return decoded
          .whereType<Map>()
          .map((entry) => AudioTimelineClip.fromJson(Map<String, dynamic>.from(entry)))
          .where((clip) => clip.id.isNotEmpty && clip.path.isNotEmpty)
          .toList();
    } catch (_) {
      return <AudioTimelineClip>[];
    }
  }

  static Future<void> save(String projectUid, List<AudioTimelineClip> clips) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key(projectUid),
      jsonEncode(clips.map((clip) => clip.toJson()).toList()),
    );
  }
}
