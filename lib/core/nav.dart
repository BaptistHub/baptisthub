import 'package:flutter/material.dart';

import '../screens/category_screen.dart';
import '../screens/doc_detail_screen.dart';
import '../screens/now_playing_screen.dart';
import '../screens/preacher_screen.dart';
import '../screens/watch_screen.dart';
import 'audio_controller.dart';
import 'catalog.dart';
import 'models.dart';

/// Central navigation helpers so any card can open content consistently.
class AppNav {
  static const tabCount = 5;
  static const home = 0, sermons = 1, docs = 2, music = 3, search = 4;

  static final tab = ValueNotifier<int>(home);
  static final keys = List.generate(tabCount, (_) => GlobalKey<NavigatorState>());

  static void goTab(int i) {
    if (tab.value == i) {
      keys[i].currentState?.popUntil((r) => r.isFirst);
    }
    tab.value = i;
  }

  /// Plays audio items in the background player and opens video in the
  /// full-screen watch page.
  static void play(BuildContext context, Video v, {List<Video>? queue, String? queueTitle, String? seed}) {
    if (v.isAudioOnly) {
      final q = queue ?? [v];
      AudioController.instance.playQueue(
        q,
        start: q.indexOf(v).clamp(0, q.length - 1),
        title: queueTitle ?? v.categoryName,
        seed: seed ?? v.categorySlug,
      );
      return;
    }
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => WatchScreen(video: v)),
    );
  }

  /// Audio-only playback of a sermon (uses its .mp3 when available).
  static void listen(Video v, {Duration? position}) =>
      AudioController.instance.playSingle(v, position: position);

  /// Documentaries open a Netflix-style detail page first.
  static void openDoc(BuildContext context, Video v, {List<Video> related = const []}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DocDetailScreen(video: v, related: related),
    ));
  }

  static void openPreacher(BuildContext context, Preacher p) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PreacherScreen(preacher: p)));
  }

  /// Opens the preacher page for a category slug if it is a known preacher,
  /// otherwise a generic category listing.
  static Future<void> openCategory(BuildContext context, String slug, {String? title}) async {
    final nav = Navigator.of(context);
    Preacher? p;
    try {
      final cat = await Catalog.load();
      p = cat.preachers.where((x) => x.slug == slug).firstOrNull;
    } catch (_) {}
    nav.push(MaterialPageRoute(
      builder: (_) => p != null
          ? PreacherScreen(preacher: p)
          : CategoryScreen(slug: slug, title: title ?? slug),
    ));
  }

  static void openNowPlaying(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => const NowPlayingScreen(),
      transitionsBuilder: (_, a, __, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ));
  }
}
