import 'dart:async';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../core/api.dart';
import '../core/audio_controller.dart';
import '../core/catalog.dart';
import '../core/downloads.dart';
import '../core/format.dart';
import '../core/library_store.dart';
import '../core/models.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/art.dart';
import '../widgets/cards.dart';
import '../widgets/common.dart';
import '../widgets/download_ui.dart';
import 'category_screen.dart';
import 'preacher_screen.dart';

/// Full-screen video player with details and "Up next".
class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key, required this.video});
  final Video video;

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  late Video _video = widget.video;
  VideoPlayerController? _vc;
  ChewieController? _cc;
  String? _error;
  Timer? _saveTimer;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _open(_video);
  }

  Future<void> _open(Video v) async {
    _savePosition();
    _saveTimer?.cancel();
    final oldC = _cc, oldV = _vc;
    setState(() {
      _video = v;
      _cc = null;
      _vc = null;
      _error = null;
    });
    oldC?.dispose();
    await oldV?.dispose();

    AudioController.instance.pause();
    LibraryStore.instance.recordPlay(v);

    // Downloaded copy first, so it plays offline.
    final local = DownloadManager.instance.localVideo(v);
    final uri = safeUri(v.mediaUrl);
    if (local == null && uri == null) {
      setState(() => _error = 'This video has no playable file.');
      return;
    }
    final vc = local != null ? VideoPlayerController.file(File(local)) : VideoPlayerController.networkUrl(uri!);
    try {
      await vc.initialize();
    } catch (_) {
      await vc.dispose();
      if (mounted && _video.id == v.id) {
        setState(() => _error = 'This video could not be loaded. It may have moved on the server.');
      }
      return;
    }
    if (!mounted || _video.id != v.id) {
      await vc.dispose();
      return;
    }
    final resume = LibraryStore.instance.resumePosition(v.id);
    final cc = ChewieController(
      videoPlayerController: vc,
      autoPlay: true,
      startAt: resume,
      aspectRatio: vc.value.aspectRatio == 0 ? 16 / 9 : vc.value.aspectRatio,
      allowedScreenSleep: false,
      deviceOrientationsAfterFullScreen: const [DeviceOrientation.portraitUp],
      materialProgressColors: ChewieProgressColors(
        playedColor: AppColors.gold,
        handleColor: AppColors.gold,
        bufferedColor: Colors.white30,
        backgroundColor: Colors.white12,
      ),
      cupertinoProgressColors: ChewieProgressColors(
        playedColor: AppColors.gold,
        handleColor: Colors.white,
        bufferedColor: Colors.white30,
        backgroundColor: Colors.white12,
      ),
      errorBuilder: (context, msg) => const Center(
        child: Text('Playback error', style: TextStyle(color: Colors.white70)),
      ),
    );
    setState(() {
      _vc = vc;
      _cc = cc;
    });
    if (resume != null && mounted) {
      showToast(context, 'Resuming from ${formatClock(resume)}', icon: Icons.history_rounded);
    }
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _savePosition());
  }

  void _savePosition() {
    final vc = _vc;
    if (vc == null || !vc.value.isInitialized) return;
    LibraryStore.instance.savePosition(_video.id, vc.value.position, vc.value.duration);
  }

  void _listenInstead() {
    final pos = _vc?.value.position;
    _savePosition();
    final v = _video;
    Navigator.of(context).pop();
    AppNav.listen(v, position: pos);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _savePosition();
    LibraryStore.instance.flush();
    _cc?.dispose();
    _vc?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _video;
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Column(children: [
          Container(
            color: Colors.black,
            padding: EdgeInsets.only(top: top),
            child: Stack(children: [
              AspectRatio(aspectRatio: 16 / 9, child: _player()),
              Positioned(
                left: 4,
                top: 4,
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30, shadows: [Shadow(blurRadius: 8)]),
                ),
              ),
            ]),
          ),
          Expanded(child: _details(v)),
        ]),
      ),
    );
  }

  Widget _player() {
    final cc = _cc;
    if (cc != null) return Chewie(controller: cc);
    final art = SmartImage(url: _video.thumbUrl, cacheWidth: 600, fallback: GeneratedArt(seed: _video.title, title: _video.title));
    return Stack(fit: StackFit.expand, children: [
      art,
      Container(color: Colors.black54),
      Center(
        child: _error == null
            ? const CircularProgressIndicator(color: AppColors.gold)
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white70),
                  const SizedBox(height: 8),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => _open(_video), child: const Text('Retry')),
                ]),
              ),
      ),
    ]);
  }

  Widget _details(Video v) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return CustomScrollView(controller: _scroll, slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.3)),
            const SizedBox(height: 8),
            Text(
              joinMeta([
                formatDate(v.date),
                formatRuntime(v.runtimeMinutes),
                if (v.views > 0) plural(v.views, 'view'),
              ]),
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            if (DownloadManager.instance.localVideo(v) != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(children: [
                  Icon(Icons.offline_pin_rounded, size: 16, color: AppColors.gold),
                  SizedBox(width: 6),
                  Text('Playing from your downloads',
                      style: TextStyle(color: AppColors.gold, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ]),
              ),
            const SizedBox(height: 16),
            _PreacherRow(video: v),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                ListenableBuilder(
                  listenable: LibraryStore.instance,
                  builder: (context, _) {
                    final inList = LibraryStore.instance.inMyList(v.id);
                    return _ActionChip(
                      icon: inList ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      label: inList ? 'Saved' : 'Save',
                      highlighted: inList,
                      onTap: () => LibraryStore.instance.toggleMyList(v),
                    );
                  },
                ),
                DownloadChip(video: v),
                _ActionChip(icon: Icons.headphones_rounded, label: 'Listen instead', onTap: _listenInstead),
                _ActionChip(
                  icon: Icons.link_rounded,
                  label: 'Copy link',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: v.webUrl));
                    showToast(context, 'Link copied', icon: Icons.link_rounded);
                  },
                ),
              ]),
            ),
            const SizedBox(height: 8),
            const Divider(height: 32),
            const Text('Up next', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
          ]),
        ),
      ),
      SliverToBoxAdapter(
        child: AsyncBuilder<List<Video>>(
          key: ValueKey(v.id),
          future: () => Api.instance.recommendations(v.id, limit: 15),
          loading: const ListSkeleton(count: 4),
          builder: (context, recs) {
            final list = recs.where((r) => r.id != v.id).toList();
            if (list.isEmpty) {
              return const EmptyState(icon: Icons.playlist_play_rounded, title: 'No recommendations');
            }
            return Column(children: [
              for (final r in list)
                VideoTile(
                  video: r,
                  onTap: () {
                    if (r.isAudioOnly) {
                      AppNav.play(context, r);
                      return;
                    }
                    _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                    _open(r);
                  },
                ),
            ]);
          },
        ),
      ),
      SliverToBoxAdapter(child: SizedBox(height: bottom + 24)),
    ]);
  }
}

class _PreacherRow extends StatelessWidget {
  const _PreacherRow({required this.video});
  final Video video;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Catalog>(
      future: Catalog.load(),
      builder: (context, snap) {
        final cat = snap.data;
        final p = cat?.preachers.where((x) => x.slug == video.categorySlug).firstOrNull;
        final category = p == null ? cat?.find(video.categorySlug) : null;
        final name = p?.name ?? (video.preacher.isNotEmpty ? video.preacher : category?.name ?? video.byline);
        final count = p?.count ?? category?.count ?? 0;
        final Widget? destination = p != null
            ? PreacherScreen(preacher: p)
            : category != null
                ? CategoryScreen(slug: category.slug, title: category.name)
                : null;
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: destination == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    final tabNav = AppNav.keys[AppNav.tab.value].currentState;
                    tabNav?.push(MaterialPageRoute(builder: (_) => destination));
                  },
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                if (p != null)
                  PreacherAvatar(preacher: p, size: 40, ring: false)
                else
                  ClipOval(
                    child: SizedBox.square(
                      dimension: 40,
                      child: GeneratedArt(seed: video.categorySlug, style: ArtStyle.avatar, initials: name.isEmpty ? '?' : name[0]),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (count > 0)
                      Text(plural(count, p != null ? 'sermon' : 'video'),
                          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ]),
                ),
                if (destination != null) const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, required this.onTap, this.highlighted = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: highlighted ? AppColors.gold.withValues(alpha: 0.16) : AppColors.surfaceHigh,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: highlighted ? AppColors.gold : AppColors.text),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: highlighted ? AppColors.gold : AppColors.text)),
            ]),
          ),
        ),
      ),
    );
  }
}
