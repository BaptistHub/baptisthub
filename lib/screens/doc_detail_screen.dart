import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/catalog.dart';
import '../core/format.dart';
import '../core/library_store.dart';
import '../core/models.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/art.dart';
import '../widgets/cards.dart';
import '../widgets/common.dart';
import '../widgets/download_ui.dart';

/// Netflix-style title page: backdrop, big title, Play / My List, and a
/// "More Like This" grid.
class DocDetailScreen extends StatelessWidget {
  const DocDetailScreen({super.key, required this.video, this.related = const []});

  final Video video;
  final List<Video> related;

  List<Video> _moreLikeThis() {
    final genres = docGenres.where((g) => g.matches(video)).toList();
    final pool = related.where((v) => v.id != video.id).toList();
    final similar = genres.isEmpty ? <Video>[] : pool.where((v) => genres.any((g) => g.matches(v))).toList();
    final rest = pool.where((v) => !similar.contains(v));
    return [...similar, ...rest].take(12).toList();
  }

  @override
  Widget build(BuildContext context) {
    final v = video;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final genres = docGenres.where((g) => g.matches(v)).map((g) => g.title).toList();
    final more = _moreLikeThis();

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: Colors.black54,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: Pressable(
            onTap: () => AppNav.play(context, v),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(fit: StackFit.expand, children: [
                SmartImage(
                  url: v.thumbUrl,
                  cacheWidth: 600,
                  fallback: GeneratedArt(seed: v.title, style: ArtStyle.wide),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0, 0.5, 1],
                      colors: [Color(0x66000000), Colors.transparent, Colors.black],
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.45),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, size: 40),
                  ),
                ),
              ]),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 16, height: 3, color: AppColors.crimson),
                const SizedBox(width: 8),
                Text('DOCUMENTARY', style: AppText.eyebrow(color: Colors.white70)),
              ]),
              const SizedBox(height: 8),
              Text(v.title.toUpperCase(), style: AppText.display(42)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (v.date != null) Text('${v.date!.year}', style: const TextStyle(color: AppColors.muted)),
                  if (v.runtimeMinutes != null)
                    Text(formatRuntime(v.runtimeMinutes), style: const TextStyle(color: AppColors.muted)),
                  const Badge2('HD', color: Color(0xFF2A2A30)),
                  if (v.views > 0)
                    Text(plural(v.views, 'view'), style: const TextStyle(color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 18),
              PillButton(icon: Icons.play_arrow_rounded, label: 'Play', expand: true, onPressed: () => AppNav.play(context, v)),
              const SizedBox(height: 10),
              PillButton(
                icon: Icons.headphones_rounded,
                label: 'Listen (audio only)',
                primary: false,
                expand: true,
                onPressed: () {
                  AppNav.listen(v);
                  showToast(context, 'Playing audio in the background', icon: Icons.headphones_rounded);
                },
              ),
              if (genres.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text.rich(TextSpan(children: [
                  const TextSpan(text: 'Genres: ', style: TextStyle(color: AppColors.faint)),
                  TextSpan(text: genres.join(', '), style: const TextStyle(color: AppColors.muted)),
                ]), style: const TextStyle(fontSize: 13)),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ListenableBuilder(
                    listenable: LibraryStore.instance,
                    builder: (context, _) {
                      final inList = LibraryStore.instance.inMyList(v.id);
                      return _ActionIcon(
                        icon: inList ? Icons.check_rounded : Icons.add_rounded,
                        label: 'My List',
                        onTap: () {
                          final added = LibraryStore.instance.toggleMyList(v);
                          showToast(context, added ? 'Added to My List' : 'Removed from My List',
                              icon: added ? Icons.check_circle_rounded : Icons.remove_circle_outline);
                        },
                      );
                    },
                  ),
                  DownloadActionButton(video: v),
                  _ActionIcon(
                    icon: Icons.link_rounded,
                    label: 'Copy link',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: v.webUrl));
                      showToast(context, 'Link copied', icon: Icons.link_rounded);
                    },
                  ),
                ],
              ),
            ]),
          ),
        ),
        if (more.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Text('More Like This', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2 / 3,
              ),
              itemCount: more.length,
              itemBuilder: (context, i) => Pressable(
                onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) => DocDetailScreen(video: more[i], related: related),
                )),
                child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Poster(video: more[i])),
              ),
            ),
          ),
        ] else
          SliverToBoxAdapter(child: _Recommendations(video: v)),
        SliverToBoxAdapter(child: SizedBox(height: bottom + 32)),
      ]),
    );
  }
}

class _Recommendations extends StatelessWidget {
  const _Recommendations({required this.video});
  final Video video;

  @override
  Widget build(BuildContext context) {
    return AsyncBuilder<List<Video>>(
      future: () => Api.instance.recommendations(video.id),
      hideOnError: true,
      loading: const SizedBox(height: 120),
      builder: (context, recs) {
        if (recs.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader('You may also like'),
          for (final r in recs) VideoTile(video: r),
        ]);
      },
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(children: [
          Icon(icon, size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ]),
      ),
    );
  }
}
