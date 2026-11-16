import 'package:baptisthubapp/core/catalog.dart';
import 'package:baptisthubapp/core/downloads.dart';
import 'package:baptisthubapp/core/format.dart';
import 'package:baptisthubapp/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _apiVideo({
  int id = 1,
  String name = 'A Sermon',
  String cat = 'fsanderson',
  String? thumb,
  String? date = '2026-11-09 00:00:00',
  Object? runtime = '55.97',
  Object? clicks = 10,
}) =>
    {
      'id': id,
      'vid_category': cat,
      'search_category': 'Sermons Pastor Anderson',
      'vid_preacher': 'Pastor Steven Anderson',
      'name': name,
      'date': date,
      'vid_url': 'https://kjv1611only.com/video/x/$name.mp4',
      'thumb_url': thumb,
      'runtime_minutes': runtime,
      'clicks': clicks,
      'language': 'en',
    };

void main() {
  group('cleanTitle', () {
    test('strips music codes and keeps track numbers', () {
      final t = cleanTitle('MUHYMNS098 98 The Name Of Jesus');
      expect(t.title, 'The Name Of Jesus');
      expect(t.track, 98);
    });

    test('uses the code digits when no explicit number', () {
      final t = cleanTitle('MUPSALMS147 Psalm 147');
      expect(t.title, 'Psalm 147');
      expect(t.track, 147);
    });

    test('parses Landmarks season / episode codes', () {
      final t = cleanTitle('LS03E07 Season 3 Episode 7 With Pastor Mejia The New Heaven');
      expect(t.season, 3);
      expect(t.episode, 7);
      expect(t.title, 'With Pastor Mejia The New Heaven');
    });

    test('leaves normal sermon titles alone', () {
      final t = cleanTitle('2 Kings 22: Josiah\'s Revival');
      expect(t.title, '2 Kings 22: Josiah\'s Revival');
      expect(t.track, isNull);
    });
  });

  group('Video', () {
    test('parses API json, including string numbers and null dates', () {
      final v = Video.fromJson(_apiVideo(date: '0000-00-00', runtime: null, clicks: '42'));
      expect(v.date, isNull);
      expect(v.runtimeMinutes, isNull);
      expect(v.views, 42);
      expect(v.isAudioOnly, isFalse);
    });

    test('skips legacy thumbnail folders that no longer exist', () {
      final dead = Video.fromJson(_apiVideo(thumb: 'https://www.kjv1611only.com/images/thumbs/docs/X.jpg'));
      final live = Video.fromJson(_apiVideo(thumb: 'https://kjv1611only.com/video/06docs/docs/X.jpg'));
      expect(dead.thumbUrl, isNull);
      expect(live.thumbUrl, isNotNull);
    });

    test('round-trips through local storage', () {
      final v = Video.fromJson(_apiVideo(name: 'MUHYMNS098 98 The Name Of Jesus'));
      final back = Video.fromStore(v.toStore());
      expect(back.title, v.title);
      expect(back.track, 98);
      expect(back.date, v.date);
    });

    test('infers .mp3 for new-style uploads only', () {
      final modern = Video.fromJson(_apiVideo(thumb: 'https://kjv1611only.com/video/02preaching/X/A.jpg'));
      final legacy = Video.fromJson(_apiVideo(thumb: 'https://www.kjv1611only.com/images/thumbs/x/A.jpg'));
      expect(modern.audioUrl, endsWith('.mp3'));
      expect(legacy.audioUrl, isNull);
    });

    test('encodes non-ASCII media URLs', () {
      final u = safeUri('https://kjv1611only.com/video/Kršćani trebaju.mp4');
      expect(u.toString(), contains('%C5%A1'));
      expect(u.toString(), isNot(contains(' ')));
    });
  });

  test('dedupe keeps the richest copy and highest views', () {
    final old = Video.fromJson(_apiVideo(id: 1, name: 'LGBT Terrorists', clicks: 18000, runtime: null));
    final hd = Video.fromJson(_apiVideo(
      id: 2,
      name: 'LGBT Terrorists',
      clicks: 500,
      thumb: 'https://kjv1611only.com/video/06docs/docs/LGBT.jpg',
    ));
    final out = dedupe([old, hd]);
    expect(out, hasLength(1));
    expect(out.first.id, 2);
    expect(out.first.views, 18000);
  });

  group('format', () {
    final now = DateTime(2026, 11, 10, 12);
    test('relative dates', () {
      expect(formatDate(DateTime(2026, 11, 10), now: now), 'Today');
      expect(formatDate(DateTime(2026, 11, 9), now: now), 'Yesterday');
      expect(formatDate(DateTime(2026, 11, 6), now: now), '4 days ago');
      expect(formatDate(DateTime(2026, 2, 28), now: now), 'Feb 28');
      expect(formatDate(DateTime(2023, 8, 1), now: now), 'Aug 1, 2023');
    });

    test('runtime and counts', () {
      expect(formatRuntime(55.97), '56 min');
      expect(formatRuntime(84.09), '1h 24m');
      expect(formatCount(18164), '18K');
      expect(formatCount(1500), '1.5K');
      expect(formatCount(2000), '2K');
    });
  });

  group('downloads', () {
    test('items survive a save/load round trip', () {
      final v = Video.fromJson(_apiVideo(name: 'MUHYMNS098 98 The Name Of Jesus'));
      final done = DownloadItem(video: v, kind: DownloadKind.audio, filename: 'x.mp3', state: DownloadState.done, bytes: 1234);
      final back = DownloadItem.fromJson(done.toJson());
      expect(back.key, done.key);
      expect(back.state, DownloadState.done);
      expect(back.bytes, 1234);
      expect(back.video.title, 'The Name Of Jesus');

      // Unfinished downloads come back as queued and re-sync from the downloader.
      final active = DownloadItem(video: v, kind: DownloadKind.video, filename: 'x.mp4', state: DownloadState.downloading);
      expect(DownloadItem.fromJson(active.toJson()).state, DownloadState.queued);
    });

    test('offers video + audio for sermons, audio only for songs', () {
      final dl = DownloadManager.instance;
      final sermon = Video.fromJson(_apiVideo(thumb: 'https://kjv1611only.com/video/02preaching/X/A.jpg'));
      final song = Video.fromJson({..._apiVideo(), 'vid_url': 'https://www.kjv1611only.com/video/13music/Hymns/1_A.mp3'});
      expect(dl.kindsFor(sermon), [DownloadKind.video, DownloadKind.audio]);
      expect(dl.kindsFor(song), [DownloadKind.audio]);
      expect(dl.defaultKind(song), DownloadKind.audio);
      expect(dl.defaultKind(sermon), DownloadKind.video);
    });

    test('formats sizes', () {
      expect(formatBytes(0), '');
      expect(formatBytes(4404019), '4.2 MB');
      expect(formatBytes(734003200), '700 MB');
      expect(formatBytes(1342177280), '1.3 GB');
    });
  });
}
