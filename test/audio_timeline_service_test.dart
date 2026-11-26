import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/services/audio_timeline_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('audio clip placement persists and reloads for its project', () async {
    const clips = <AudioTimelineClip>[
      AudioTimelineClip(
        id: 'cartoon-pop-01-123',
        name: 'Cartoon Pop 01',
        path: '/app/documents/audio_library/cartoon-pop-01.mp3',
        startFrame: 7,
        isPro: false,
      ),
    ];

    await AudioTimelineService.save('project-alpha', clips);
    final loaded = await AudioTimelineService.load('project-alpha');

    expect(loaded, hasLength(1));
    expect(loaded.single.id, clips.single.id);
    expect(loaded.single.name, clips.single.name);
    expect(loaded.single.path, clips.single.path);
    expect(loaded.single.startFrame, 7);
    expect(loaded.single.isPro, isFalse);
  });

  test('audio clip placements are isolated between projects', () async {
    const clip = AudioTimelineClip(
      id: 'ambience-456',
      name: 'Ambience',
      path: '/app/documents/audio_library/ambience.mp3',
      startFrame: 2,
      isPro: true,
    );

    await AudioTimelineService.save('project-alpha', <AudioTimelineClip>[clip]);

    expect(await AudioTimelineService.load('project-alpha'), hasLength(1));
    expect(await AudioTimelineService.load('project-beta'), isEmpty);
  });

  test('editable audio settings persist with each clip', () async {
    const clip = AudioTimelineClip(
      id: 'music-clip-01',
      name: 'Background music',
      path: '/app/documents/project-audio/music.mp3',
      startFrame: 42,
      isPro: false,
      trackIndex: 4,
      trimStartMs: 1200,
      trimEndMs: 17800,
      volume: .65,
      muted: true,
      loop: true,
    );

    await AudioTimelineService.save('project-audio-settings', <AudioTimelineClip>[clip]);
    final loaded = (await AudioTimelineService.load('project-audio-settings')).single;

    expect(loaded.startFrame, 42);
    expect(loaded.trackIndex, 4);
    expect(loaded.trimStartMs, 1200);
    expect(loaded.trimEndMs, 17800);
    expect(loaded.volume, .65);
    expect(loaded.muted, isTrue);
    expect(loaded.loop, isTrue);
  });

  test('older projects receive safe defaults for new audio settings', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'animpro_audio_timeline_legacy-project':
          '[{"id":"old-clip","name":"Old music","path":"/music.mp3","startFrame":8,"isPro":false}]',
    });

    final clip = (await AudioTimelineService.load('legacy-project')).single;

    expect(clip.startFrame, 8);
    expect(clip.trackIndex, 0);
    expect(clip.trimStartMs, 0);
    expect(clip.trimEndMs, 0);
    expect(clip.volume, 1);
    expect(clip.muted, isFalse);
    expect(clip.loop, isFalse);
  });

  test('malformed stored audio metadata fails safely', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'animpro_audio_timeline_project-alpha': '{not json',
    });

    expect(await AudioTimelineService.load('project-alpha'), isEmpty);
  });
}
