// Renders every screen with recorded API data at real phone sizes and fails
// on any RenderFlex / layout overflow, naming the widget responsible.
import 'dart:convert';
import 'dart:io';

import 'package:baptisthubapp/core/api.dart';
import 'package:baptisthubapp/core/catalog.dart';
import 'package:baptisthubapp/core/downloads.dart';
import 'package:baptisthubapp/core/library_store.dart';
import 'package:baptisthubapp/core/models.dart';
import 'package:baptisthubapp/core/nav.dart';
import 'package:baptisthubapp/core/theme.dart';
import 'package:baptisthubapp/screens/category_screen.dart';
import 'package:baptisthubapp/screens/church_screen.dart';
import 'package:baptisthubapp/screens/doc_detail_screen.dart';
import 'package:baptisthubapp/screens/downloads_screen.dart';
import 'package:baptisthubapp/screens/library_screen.dart';
import 'package:baptisthubapp/screens/music_screen.dart';
import 'package:baptisthubapp/screens/preacher_screen.dart';
import 'package:baptisthubapp/screens/series_screen.dart';
import 'package:baptisthubapp/screens/sermons_screen.dart';
import 'package:baptisthubapp/screens/shell.dart';
import 'package:baptisthubapp/screens/watch_screen.dart';
import 'package:baptisthubapp/widgets/art.dart';
import 'package:baptisthubapp/widgets/download_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _fixture(String name) => File('test/fixtures/$name.json').readAsStringSync();

String _fixtureFor(Uri uri) {
  final path = uri.path;
  if (path == '/api/categories') return _fixture('categories');
  if (path == '/api/videos') return _fixture('videos');
  if (path == '/api/search') return _fixture('search');
  if (path.endsWith('/recommendations')) return _fixture('recs');
  if (path.startsWith('/api/categories/')) {
    final slug = Uri.decodeComponent(path.split('/').last);
    if (slug == 'docs') return _fixture('cat_docs');
    if (slug == 'interviews') return _fixture('cat_interviews');
    if (slug == 'landmarks' || slug.startsWith('m') && !slug.startsWith('mu')) return _fixture('cat_landmarks');
    if (slug.startsWith('mu')) return _fixture('cat_muhymns');
    return _fixture('cat_fsanderson');
  }
  return '{}';
}

/// Serves fixtures; later pages come back empty so feeds terminate.
final _mock = MockClient((req) async {
  var body = _fixtureFor(req.url);
  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  if (page > 1) {
    final d = jsonDecode(body) as Map<String, dynamic>;
    d['videos'] = <Object>[];
    (d['pagination'] as Map)['page'] = page;
    body = jsonEncode(d);
  }
  return http.Response.bytes(utf8.encode(body), 200, headers: {'content-type': 'application/json'});
});

Video _video(String fixture, {int index = 0}) {
  final d = jsonDecode(_fixture(fixture));
  final list = d is List ? d : (d['videos'] as List);
  return Video.fromJson((list[index] as Map).cast<String, dynamic>());
}

/// One of each state: downloading, paused, queued, failed and saved.
void _seedDownloads() {
  final sermon = _video('videos');
  final doc = _video('cat_docs');
  final song = _video('cat_muhymns');
  final song2 = _video('cat_muhymns', index: 1);
  final other = _video('cat_fsanderson');
  DownloadManager.instance.debugSetItems([
    DownloadItem(video: doc, kind: DownloadKind.video, filename: 'a.mp4', state: DownloadState.done, bytes: 1342177280),
    DownloadItem(video: song, kind: DownloadKind.audio, filename: 'b.mp3', state: DownloadState.done, bytes: 4404019),
    DownloadItem(video: song2, kind: DownloadKind.audio, filename: 'c.mp3', state: DownloadState.queued),
    DownloadItem(video: other, kind: DownloadKind.audio, filename: 'd.mp3', state: DownloadState.failed,
        error: 'No audio file on the server. Try the video instead.'),
    DownloadItem(video: sermon, kind: DownloadKind.video, filename: 'e.mp4', state: DownloadState.downloading,
        progress: 0.42, bytes: 734003200),
    DownloadItem(video: other, kind: DownloadKind.video, filename: 'f.mp4', state: DownloadState.paused,
        progress: 0.7, bytes: 512000000),
  ]);
}

/// Opens the download sheet over a blank page once laid out.
class _SheetHost extends StatefulWidget {
  const _SheetHost({required this.video});
  final Video video;

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showDownloadSheet(context, widget.video);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

class _Device {
  const _Device(this.name, this.size, {this.textScale = 1.0});
  final String name;
  final Size size;
  final double textScale;
}

const _devices = [
  _Device('small 320x640', Size(320, 640)),
  _Device('common 360x780', Size(360, 780)),
  _Device('large 412x915', Size(412, 915)),
  _Device('360 @ 1.3x text', Size(360, 780), textScale: 1.3),
];

Future<List<String>> _render(WidgetTester tester, _Device d, Widget screen, {int scrolls = 6}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = d.size * 3;
  tester.view.padding = const FakeViewPadding(top: 24 * 3, bottom: 16 * 3);
  tester.platformDispatcher.textScaleFactorTestValue = d.textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final problems = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString();
    if (text.contains('overflowed') || text.contains('OVERFLOW')) {
      final lines = text.split('\n');
      final culprit = lines.firstWhere((l) => l.contains('file:///'), orElse: () => '');
      problems.add('${lines.first.trim()}  ${culprit.trim()}');
    } else {
      previous?.call(details);
    }
  };

  try {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: screen));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    for (var i = 0; i < scrolls; i++) {
      await tester.dragFrom(Offset(d.size.width / 2, d.size.height * 0.6), const Offset(0, -450));
      for (var j = 0; j < 4; j++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    }
    // Unmount so periodic timers (carousel) are cancelled inside the test.
    await tester.pumpWidget(const SizedBox());
  } finally {
    FlutterError.onError = previous;
  }
  return problems.toSet().toList();
}

void main() {
  setUpAll(() async {
    AppFonts.useGoogleFonts = false;
    // Real fonts, so text heights/widths match a phone.
    final inter = FontLoader('Inter');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black']) {
      inter.addFont(Future.value(ByteData.sublistView(File('assets/fonts/Inter-$w.ttf').readAsBytesSync())));
    }
    await inter.load();
    await (FontLoader('BebasNeue')
          ..addFont(Future.value(ByteData.sublistView(File('assets/fonts/BebasNeue-Regular.ttf').readAsBytesSync()))))
        .load();
    SmartImage.enabled = false;
    Api.instance.client = _mock;
    SharedPreferences.setMockInitialValues({});
    await LibraryStore.instance.init();
  });

  final screens = <String, Widget Function()>{
    'Home tab': () {
      AppNav.tab.value = AppNav.home;
      return const Shell();
    },
    'Sermons tab': () {
      AppNav.tab.value = AppNav.sermons;
      return const Shell();
    },
    'Films tab': () {
      AppNav.tab.value = AppNav.docs;
      return const Shell();
    },
    'Music tab': () {
      AppNav.tab.value = AppNav.music;
      return const Shell();
    },
    'Search tab': () {
      AppNav.tab.value = AppNav.search;
      return const Shell();
    },
    'Sermons › Preachers': () => const SermonsScreen(),
    'Sermons › Churches': () => const SermonsScreen(initialTab: 1),
    'Sermons › Conferences': () => const SermonsScreen(initialTab: 2),
    'Church: Faithful Word': () => ChurchScreen(church: churches[0]),
    'Church: Sure Foundation': () => ChurchScreen(church: churches[3]),
    'Church: SWBC Melbourne': () => ChurchScreen(church: churches[5]),
    'Preacher (with clips)': () => const PreacherScreen(
          preacher: Preacher(slug: 'fsanderson', name: 'Pastor Steven L. Anderson', count: 4654, clipsSlug: 'scanderson'),
        ),
    'Preacher (no clips)': () => const PreacherScreen(
          preacher: Preacher(slug: 'fsreyes', name: 'Pastor Enrique Reyes', count: 197),
        ),
    'Church': () => ChurchScreen(church: churches.first),
    'Category': () => const CategoryScreen(slug: 'pcbias', title: 'The Baptist Bias', subtitle: 'Podcast'),
    'Doc detail': () => DocDetailScreen(video: _video('cat_docs'), related: [for (var i = 0; i < 8; i++) _video('cat_docs', index: i)]),
    'Series (Landmarks)': () => const SeriesScreen(collection: Collection('landmarks', 'Landmarks', 'A series in seasons')),
    'Album': () => AlbumScreen(collection: musicCollections.first),
    'Library': () => const LibraryScreen(),
    'Watch': () => WatchScreen(video: _video('videos')),
    'Home tab (downloading)': () {
      _seedDownloads();
      AppNav.tab.value = AppNav.home;
      return const Shell();
    },
    'Sermons tab (downloading)': () {
      _seedDownloads();
      AppNav.tab.value = AppNav.sermons;
      return const Shell();
    },
    'Films tab (downloading)': () {
      _seedDownloads();
      AppNav.tab.value = AppNav.docs;
      return const Shell();
    },
    'Music tab (downloading)': () {
      _seedDownloads();
      AppNav.tab.value = AppNav.music;
      return const Shell();
    },
    'Search tab (downloading)': () {
      _seedDownloads();
      AppNav.tab.value = AppNav.search;
      return const Shell();
    },
    'Downloads (empty)': () {
      DownloadManager.instance.debugSetItems([]);
      return const DownloadsScreen();
    },
    'Downloads (busy)': () {
      _seedDownloads();
      return const DownloadsScreen();
    },
    'Library › Downloads': () {
      _seedDownloads();
      return const LibraryScreen(initialTab: 1);
    },
    'Download sheet (sermon)': () {
      DownloadManager.instance.debugSetItems([]);
      return _SheetHost(video: _video('videos'));
    },
    'Download sheet (song)': () => _SheetHost(video: _video('cat_muhymns')),
    'Download sheet (saved film)': () {
      _seedDownloads();
      return _SheetHost(video: _video('cat_docs'));
    },
  };

  for (final d in _devices) {
    group(d.name, () {
      for (final entry in screens.entries) {
        testWidgets(entry.key, (tester) async {
          Catalog.reset();
          DownloadManager.instance.debugSetItems([]);
          final problems = await _render(tester, d, entry.value());
          expect(problems, isEmpty, reason: '${entry.key} on ${d.name}:\n${problems.join('\n')}');
        });
      }
    });
  }

}
