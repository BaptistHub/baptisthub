import 'dart:math' as math;

import 'package:flutter/material.dart';

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
import 'category_screen.dart';
import 'library_screen.dart';
import 'series_screen.dart';

class _DocsData {
  _DocsData(this.docs, this.interviews);
  final List<Video> docs;
  final List<Video> interviews;
}

/// Netflix-style documentaries browser: billboard, Top 10, genre shelves.
class DocsScreen extends StatefulWidget {
  const DocsScreen({super.key});

  @override
  State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen> {
  final _scroll = ScrollController();
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final o = _scroll.offset.clamp(0.0, 200.0);
      if ((o - _offset).abs() > 4 || (o == 0 && _offset != 0)) setState(() => _offset = o);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<_DocsData> _load() async {
    final results = await Future.wait([
      Api.instance.categoryAll('docs'),
      Api.instance.categoryAll('interviews', max: 100).catchError((Object _) => <Video>[]),
    ]);
    return _DocsData(dedupe(results[0]), dedupe(results[1]));
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(_DocsTopBar.height),
        child: _DocsTopBar(opacity: _offset / 200, topPadding: top),
      ),
      body: AsyncBuilder<_DocsData>(
        future: _load,
        compactError: false,
        loading: const _DocsSkeleton(),
        builder: (context, data) => _DocsBody(data: data, controller: _scroll),
      ),
    );
  }
}

class _DocsTopBar extends StatelessWidget {
  const _DocsTopBar({required this.opacity, required this.topPadding});

  /// Title row (48) + chip row (40) + paddings (6 + 2 + 10).
  static const height = 106.0;
  final double opacity;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0x66FFFFFF)),
              shape: const StadiumBorder(),
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: AppFonts.inter(const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            child: Text(label),
          ),
        );
    return Container(
      padding: EdgeInsets.only(top: topPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.75 + 0.25 * opacity),
            Colors.black.withValues(alpha: opacity * 0.95),
          ],
        ),
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 12, 0),
            child: Row(children: [
              Text('FILMS', style: AppText.display(32, color: AppColors.gold).copyWith(letterSpacing: 2)),
              const Spacer(),
              const DownloadsButton(),
              IconButton(
                onPressed: () => AppNav.goTab(AppNav.search),
                icon: const Icon(Icons.search_rounded),
              ),
            ]),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
            child: Row(children: [
              chip('Series', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SeriesIndexScreen()))),
              chip('Interviews', () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const CategoryScreen(slug: 'interviews', title: 'Interviews'),
                  ))),
              chip('Landmarks', () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SeriesScreen(collection: Collection('landmarks', 'Landmarks', 'A series in seasons')),
                  ))),
              chip('My List', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LibraryScreen()))),
            ]),
          ),
        ],
      ),
      ),
    );
  }
}

class _DocsBody extends StatelessWidget {
  const _DocsBody({required this.data, required this.controller});
  final _DocsData data;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final docs = data.docs;
    final byViews = [...docs]..sort((a, b) => b.views.compareTo(a.views));
    final dated = docs.where((d) => d.date != null).toList()
      ..sort((a, b) => b.date!.compareTo(a.date!));

    // Billboard: rotate daily through the most-watched titles.
    final day = DateTime.now().difference(DateTime(2024)).inDays;
    final pool = byViews.take(12).toList();
    final featured = dated.isNotEmpty && dated.first.thumbUrl != null && day.isEven
        ? dated.first
        : pool[day % math.max(1, pool.length)];

    final used = <int>{};
    final shelves = <Widget>[];
    void shelf(String title, List<Video> items, {bool ranked = false}) {
      if (items.length < 3) return;
      shelves.add(_DocShelf(title: title, items: items, ranked: ranked));
    }

    shelf('Top 10 Documentaries', byViews.take(10).toList(), ranked: true);
    if (dated.length >= 2) {
      shelves.add(_DocShelf(title: 'New Releases', items: dated, wide: true));
    }
    shelf('Trending Now', byViews.skip(10).take(15).toList());
    for (final g in docGenres) {
      final items = byViews.where(g.matches).toList();
      used.addAll(items.map((e) => e.id));
      shelf(g.title, items);
    }
    shelves.add(const _SeriesShelf());
    if (data.interviews.isNotEmpty) {
      shelves.add(_DocShelf(title: 'Interviews', items: data.interviews.take(20).toList(), wide: true, onSeeAll: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoryScreen(slug: 'interviews', title: 'Interviews')));
      }));
    }
    final rest = byViews.where((v) => !used.contains(v.id)).toList();
    shelf('More to Explore', rest);

    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListView(
      controller: controller,
      padding: EdgeInsets.only(bottom: bottom + 32),
      children: [
        _Billboard(video: featured, related: byViews),
        ...shelves,
      ],
    );
  }
}

class _Billboard extends StatelessWidget {
  const _Billboard({required this.video, required this.related});
  final Video video;
  final List<Video> related;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top;
    final cardW = math.min(size.width - 48, 420.0);
    final tint = accentFor(video.title);
    final tags = docGenres.where((g) => g.matches(video)).map((g) => g.title.split(' ').first).take(2).toList();

    return Container(
      padding: EdgeInsets.only(top: top + 12, bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tint.withValues(alpha: 0.55), tint.withValues(alpha: 0.12), Colors.black],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: Center(
        child: Pressable(
          onTap: () => AppNav.openDoc(context, video, related: related),
          child: Container(
            width: cardW,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: tint.withValues(alpha: 0.35), blurRadius: 40, offset: const Offset(0, 16))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 0.78,
                child: Stack(fit: StackFit.expand, children: [
                  if (video.thumbUrl != null)
                    SmartImage(url: video.thumbUrl, cacheWidth: 500, fallback: GeneratedArt(seed: video.title, style: ArtStyle.poster))
                  else
                    GeneratedArt(seed: video.title, style: ArtStyle.poster),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.35, 1],
                        colors: [Colors.transparent, Color(0xF0000000)],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Container(width: 16, height: 3, color: AppColors.crimson),
                          const SizedBox(width: 8),
                          Text('DOCUMENTARY', style: AppText.eyebrow(color: Colors.white)),
                        ]),
                        const SizedBox(height: 10),
                        Text(
                          video.title.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          style: AppText.display(44).copyWith(shadows: const [Shadow(blurRadius: 18, color: Colors.black)]),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          [if (tags.isNotEmpty) ...tags, plural(video.views, 'view')].join('  •  '),
                          style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                            child: PillButton(
                              icon: Icons.play_arrow_rounded,
                              label: 'Play',
                              expand: true,
                              onPressed: () => AppNav.play(context, video),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: _MyListButton(video: video)),
                        ]),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MyListButton extends StatelessWidget {
  const _MyListButton({required this.video});
  final Video video;

  @override
  Widget build(BuildContext context) {
    final lib = LibraryStore.instance;
    return ListenableBuilder(
      listenable: lib,
      builder: (context, _) {
        final inList = lib.inMyList(video.id);
        return PillButton(
          icon: inList ? Icons.check_rounded : Icons.add_rounded,
          label: 'My List',
          primary: false,
          expand: true,
          onPressed: () => lib.toggleMyList(video),
        );
      },
    );
  }
}

class _DocShelf extends StatelessWidget {
  const _DocShelf({required this.title, required this.items, this.ranked = false, this.wide = false, this.onSeeAll});

  final String title;
  final List<Video> items;
  final bool ranked;
  final bool wide;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(title, onSeeAll: onSeeAll, padding: const EdgeInsets.fromLTRB(20, 26, 12, 10)),
      if (ranked)
        Shelf(
          height: 168,
          spacing: 4,
          itemCount: items.length,
          itemBuilder: (_, i) => RankedPosterCard(
            rank: i + 1,
            video: items[i],
            onTap: () => AppNav.openDoc(context, items[i], related: items),
          ),
        )
      else if (wide)
        Shelf(
          height: 206,
          itemCount: items.length,
          itemBuilder: (_, i) => SizedBox(
            width: 240,
            child: Pressable(
              onTap: () => AppNav.openDoc(context, items[i], related: items),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                VideoThumb(video: items[i], radius: 8, cacheWidth: 240),
                const SizedBox(height: 8),
                Text(items[i].title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.25)),
              ]),
            ),
          ),
        )
      else
        Shelf(
          height: 180,
          spacing: 8,
          itemCount: items.length,
          itemBuilder: (_, i) => PosterCard(
            video: items[i],
            width: 120,
            onTap: () => AppNav.openDoc(context, items[i], related: items),
          ),
        ),
    ]);
  }
}

class _SeriesShelf extends StatelessWidget {
  const _SeriesShelf();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(
        'Bible Series',
        padding: const EdgeInsets.fromLTRB(20, 26, 12, 10),
        onSeeAll: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SeriesIndexScreen())),
      ),
      Shelf(
        height: 132,
        spacing: 10,
        itemCount: docSeries.length,
        itemBuilder: (_, i) {
          final s = docSeries[i];
          return SizedBox(
            width: 210,
            child: Pressable(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SeriesScreen(collection: s))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GeneratedArt(seed: s.slug, style: ArtStyle.wide, title: s.title, label: 'Series'),
              ),
            ),
          );
        },
      ),
    ]);
  }
}

class _DocsSkeleton extends StatelessWidget {
  const _DocsSkeleton();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final w = math.min(MediaQuery.sizeOf(context).width - 48, 420.0);
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: top + 12),
      children: [
        Center(child: Shimmering(child: SkeletonBox(width: w, height: w / 0.78, radius: 16))),
        const SizedBox(height: 32),
        const ShelfSkeleton(width: 120, height: 180, textLines: 0),
      ],
    );
  }
}
