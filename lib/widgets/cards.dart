import 'package:flutter/material.dart';

import '../core/audio_controller.dart';
import '../core/catalog.dart';
import '../core/format.dart';
import '../core/library_store.dart';
import '../core/models.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import 'art.dart';
import 'common.dart';
import 'download_ui.dart';

/// 16:9 thumbnail with duration badge and resume progress.
class VideoThumb extends StatelessWidget {
  const VideoThumb({super.key, required this.video, this.radius = 14, this.showTitleArt = true, this.cacheWidth = 320});

  final Video video;
  final double radius;
  final bool showTitleArt;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final runtime = formatRuntime(video.runtimeMinutes);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(fit: StackFit.expand, children: [
          SmartImage(
            url: video.thumbUrl,
            cacheWidth: cacheWidth,
            fallback: GeneratedArt(
              seed: video.categorySlug + video.title,
              style: ArtStyle.wide,
              title: showTitleArt ? video.title : null,
              label: showTitleArt ? video.byline : null,
            ),
          ),
          if (runtime.isNotEmpty)
            Positioned(right: 6, bottom: 8, child: Badge2(runtime)),
          Positioned(right: 6, top: 6, child: DownloadedBadge(videoId: video.id)),
          if (video.language != 'en' && video.language != 'auto' && video.language != 'en-us')
            Positioned(left: 6, top: 6, child: Badge2(video.language.toUpperCase(), color: AppColors.gold, textColor: Colors.black)),
          ListenableBuilder(
            listenable: LibraryStore.instance,
            builder: (_, __) {
              final p = LibraryStore.instance.progress(video.id);
              if (p == null || p < 0.01) return const SizedBox.shrink();
              return Align(
                alignment: Alignment.bottomCenter,
                child: LinearProgressIndicator(
                  value: p,
                  minHeight: 3,
                  backgroundColor: Colors.white24,
                  color: AppColors.gold,
                ),
              );
            },
          ),
        ]),
      ),
    );
  }
}

/// Wide sermon card for shelves.
class VideoCard extends StatelessWidget {
  const VideoCard({super.key, required this.video, this.width = 264, this.queue});

  /// Height a shelf needs for cards of [width], at the current text size.
  static double shelfHeight(BuildContext context, double width) {
    final t = MediaQuery.textScalerOf(context);
    return width * 9 / 16 + 10 + t.scale(14.5) * 1.25 * 2 + 4 + t.scale(12.5) * 1.35 + 6;
  }

  final Video video;
  final double width;
  final List<Video>? queue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Pressable(
        onTap: () => AppNav.play(context, video, queue: queue),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VideoThumb(video: video, cacheWidth: width.round()),
            const SizedBox(height: 10),
            Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, height: 1.25),
            ),
            const SizedBox(height: 4),
            Text(
              joinMeta([video.byline, formatDate(video.date)]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// List row with thumbnail; used in feeds, search and "Up next".
class VideoTile extends StatelessWidget {
  const VideoTile({super.key, required this.video, this.onTap, this.queue, this.showByline = true});

  final Video video;
  final VoidCallback? onTap;
  final List<Video>? queue;
  final bool showByline;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => AppNav.play(context, video, queue: queue),
      onLongPress: () => showDownloadSheet(context, video),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 136, child: VideoThumb(video: video, radius: 10, showTitleArt: false, cacheWidth: 140)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.25)),
                  const SizedBox(height: 5),
                  Text(
                    joinMeta([
                      if (showByline) video.byline,
                      formatDate(video.date),
                      if (video.views > 0) plural(video.views, 'view'),
                    ]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
            if (video.isAudioOnly)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 4),
                child: Icon(Icons.headphones_rounded, size: 18, color: AppColors.faint),
              ),
          ],
        ),
      ),
    );
  }
}

/// 2:3 Netflix-style poster with title typography.
class PosterCard extends StatelessWidget {
  const PosterCard({super.key, required this.video, this.width = 124, this.onTap, this.label = 'Documentary'});

  final Video video;
  final double width;
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Pressable(
        onTap: onTap ?? () => AppNav.openDoc(context, video),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(aspectRatio: 2 / 3, child: Poster(video: video, label: label)),
        ),
      ),
    );
  }
}

/// Poster artwork: the sermon still (if any) under cinematic title type.
class Poster extends StatelessWidget {
  const Poster({super.key, required this.video, this.label = 'Documentary'});

  final Video video;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final art = GeneratedArt(seed: video.title, style: ArtStyle.poster, title: video.title, label: label);
    if (video.thumbUrl == null) return art;
    return Stack(fit: StackFit.expand, children: [
      SmartImage(url: video.thumbUrl, fallback: art, cacheWidth: 260),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.3, 1],
            colors: [Colors.transparent, Color(0xE6000000)],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(10),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(video.title.toUpperCase(),
              maxLines: 3, overflow: TextOverflow.ellipsis, style: AppText.display(22)),
        ),
      ),
    ]);
  }
}

/// "Top 10" card: oversized outlined rank numeral behind a poster.
class RankedPosterCard extends StatelessWidget {
  const RankedPosterCard({super.key, required this.rank, required this.video, this.onTap});

  final int rank;
  final Video video;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const posterW = 112.0;
    return Pressable(
      onTap: onTap ?? () => AppNav.openDoc(context, video),
      child: SizedBox(
        width: rank >= 10 ? 196 : 164,
        child: Stack(children: [
          Positioned(
            left: 0,
            bottom: -18,
            child: Text(
              '$rank',
              style: AppFonts.bebas(TextStyle(
                fontSize: 150,
                height: 1,
                letterSpacing: -8,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3
                  ..color = const Color(0xFF8A8A93),
              )),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: posterW,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Poster(video: video),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Square album / collection card.
class AlbumCard extends StatelessWidget {
  const AlbumCard({
    super.key,
    required this.title,
    required this.seed,
    this.subtitle,
    this.icon = Icons.music_note_rounded,
    this.width = 150,
    required this.onTap,
  });

  final String title;
  final String seed;
  final String? subtitle;
  final IconData icon;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Pressable(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: GeneratedArt(seed: seed, style: ArtStyle.album, title: title, icon: icon),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ],
          ],
        ),
      ),
    );
  }
}

class PreacherChip extends StatelessWidget {
  const PreacherChip({super.key, required this.preacher, this.size = 76});

  final Preacher preacher;
  final double size;

  /// Exact height of a chip: ringed avatar + gap + two lines of name at the
  /// current text size. Use it for grid cells and shelves.
  static double heightFor(BuildContext context, double size) {
    final line = MediaQuery.textScalerOf(context).scale(12.5) * 1.2;
    return size + 9 + 8 + line * 2 + 4;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 18,
      child: Pressable(
        onTap: () => AppNav.openPreacher(context, preacher),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          PreacherAvatar(preacher: preacher, size: size),
          const SizedBox(height: 8),
          Text(
            preacher.name.replaceFirst(RegExp(r'^(Pastor|Bro\.|Deacon)\s+'), ''),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.2),
          ),
        ]),
      ),
    );
  }
}

class ChurchCard extends StatelessWidget {
  const ChurchCard({super.key, required this.church, required this.onTap, this.width = 220});

  final Church church;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Pressable(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(fit: StackFit.expand, children: [
              ChurchImage(church: church, cacheWidth: 480),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.35, 1],
                    colors: [Color(0x00000000), Color(0xE0000000)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Text(church.shortName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3)),
                    Text(church.location ?? 'Baptist Church',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A church's bundled photo, falling back to generated art if missing.
class ChurchImage extends StatelessWidget {
  const ChurchImage({super.key, required this.church, this.cacheWidth});
  final Church church;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Image.asset(
      church.image,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth == null ? null : (cacheWidth! * dpr).round(),
      errorBuilder: (_, __, ___) => GeneratedArt(seed: church.name, style: ArtStyle.wide),
    );
  }
}

/// Animated equalizer bars shown next to the playing track.
class PlayingBars extends StatefulWidget {
  const PlayingBars({super.key, this.color = AppColors.gold, this.animate = true});
  final Color color;
  final bool animate;

  @override
  State<PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<PlayingBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PlayingBars old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.animate) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final phase in const [0.0, 0.45, 0.8])
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 3,
              height: 4 + 12 * ((_c.value + phase) % 1.0),
              decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
            ),
        ],
      ),
    );
  }
}

/// Track row used by album and playlist screens.
class TrackTile extends StatelessWidget {
  const TrackTile({super.key, required this.video, required this.number, required this.onTap});

  final Video video;
  final int number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final audio = AudioController.instance;
    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        final current = audio.isCurrent(video);
        return InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
            child: Row(children: [
              SizedBox(
                width: 32,
                child: current
                    ? PlayingBars(animate: audio.isPlaying)
                    : Text('$number',
                        style: const TextStyle(color: AppColors.faint, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: Text(
                  video.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: current ? AppColors.gold : AppColors.text,
                  ),
                ),
              ),
              DownloadedBadge(videoId: video.id),
              IconButton(
                tooltip: 'Download options',
                visualDensity: VisualDensity.compact,
                onPressed: () => showDownloadSheet(context, video),
                icon: const Icon(Icons.more_horiz_rounded, color: AppColors.faint),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// Subtle press-scale feedback for cards.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.965 : 1,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}
