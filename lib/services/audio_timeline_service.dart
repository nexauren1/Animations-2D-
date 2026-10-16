import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AudioTimelineClip {
  const AudioTimelineClip({
    required this.id,
    required this.name,
    required this.path,
    required this.startFrame,
    required this.isPro,
  });

  final String id;
  final String name;
  final String path;
  final int startFrame;
  final bool isPro;

  AudioTimelineClip copyWith({int? startFrame}) => AudioTimelineClip(
        id: id,
        name: name,
        path: path,
        startFrame: startFrame ?? this.startFrame,
        isPro: isPro,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'path': path,
        'startFrame': startFrame,
        'isPro': isPro,
      };

  factory AudioTimelineClip.fromJson(Map<String, dynamic> json) =>
      AudioTimelineClip(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? 'Áudio').toString(),
        path: (json['path'] ?? '').toString(),
        startFrame: (json['startFrame'] as num? ?? 0).toInt().clamp(0, 100000),
        isPro: json['isPro'] == true,
      );
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
