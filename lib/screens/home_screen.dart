import 'dart:async';

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
import 'church_screen.dart';
import 'library_screen.dart';
import 'music_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _refreshToken = 0;

  Future<void> _refresh() async {
    setState(() => _refreshToken++);
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.surfaceHigh,
        onRefresh: _refresh,
        child: CustomScrollView(
          key: ValueKey(_refreshToken),
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            const _HomeAppBar(),
            const SliverToBoxAdapter(child: _HeroCarousel()),
            const SliverToBoxAdapter(child: _ContinueWatching()),
            SliverToBoxAdapter(
              child: _FeedShelf(
                title: 'Latest Sermons',
                subtitle: 'Fresh from the pulpit',
                load: () => Api.instance.videos(),
                onSeeAll: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CategoryScreen.feed(title: 'Latest Sermons', fetch: (p) => Api.instance.videos(page: p)),
                )),
              ),
            ),
            const SliverToBoxAdapter(child: _PreacherShelf()),
            const SliverToBoxAdapter(child: _GospelBanner()),
            SliverToBoxAdapter(
              child: _FeedShelf(
                title: 'Most Watched',
                subtitle: 'All-time favourites',
                load: () => Api.instance.videos(sort: 'views'),
                onSeeAll: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CategoryScreen.feed(
                      title: 'Most Watched', fetch: (p) => Api.instance.videos(page: p, sort: 'views')),
                )),
              ),
            ),
            const SliverToBoxAdapter(child: _ChurchShelf()),
            const SliverToBoxAdapter(child: _DocsShelf()),
            const SliverToBoxAdapter(child: _MusicShelf()),
            SliverToBoxAdapter(
              child: _CollectionShelf(title: 'Podcasts', items: podcasts, icon: Icons.podcasts_rounded),
            ),
            SliverToBoxAdapter(
              child: _CollectionShelf(title: 'Soulwinning', items: soulwinning, icon: Icons.directions_walk_rounded),
            ),
            SliverToBoxAdapter(child: SizedBox(height: bottom + 32)),
          ],
        ),
      ),
    );
  }
}

class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar();

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: AppColors.bg.withValues(alpha: 0.94),
      titleSpacing: 20,
      title: const BrandMark(),
      actions: [
        IconButton(
          tooltip: 'Search',
          onPressed: () => AppNav.goTab(AppNav.search),
          icon: const Icon(Icons.search_rounded),
        ),
        const DownloadsButton(),
        IconButton(
          tooltip: 'My Library',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LibraryScreen())),
          icon: const Icon(Icons.bookmarks_outlined),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.gold, AppColors.goldDeep]),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Icon(Icons.menu_book_rounded, size: 18, color: Colors.black),
      ),
      const SizedBox(width: 10),
      const Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(TextSpan(children: [
            TextSpan(text: 'Baptist', style: TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: 'Hub', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.gold)),
          ]), style: TextStyle(fontSize: 21, letterSpacing: -0.6)),
        ),
      ),
    ]);
  }
}

class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel();

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
  Timer? _timer;
  int _page = 0;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || _count < 2 || !_controller.hasClients) return;
      _controller.animateToPage((_page + 1) % _count,
          duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final t = MediaQuery.textScalerOf(context);
    // Tall enough for the image, and for the text + buttons at any text size.
    final contentMin = 32 + 26 + 12 + t.scale(21) * 1.2 * 2 + 6 + t.scale(13) * 1.4 + 14 + 48;
    final height = ((width * 0.9) * 9 / 16 + 96).clamp(contentMin, double.infinity).toDouble();
    return AsyncBuilder<VideoPage>(
      future: () => Api.instance.videos(),
      loading: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Shimmering(child: SkeletonBox(height: height - 20, radius: 22)),
      ),
      builder: (context, page) {
        // Prefer one feature per preacher so the carousel feels varied.
        final seen = <String>{};
        final featured = <Video>[
          for (final v in page.videos)
            if (v.thumbUrl != null && seen.add(v.categorySlug)) v,
        ].take(6).toList();
        _count = featured.length;
        if (featured.isEmpty) return const SizedBox.shrink();
        return Column(children: [
          const SizedBox(height: 8),
          SizedBox(
            height: height,
            child: PageView.builder(
              controller: _controller,
              itemCount: featured.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _HeroCard(video: featured[i], queue: featured),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < featured.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.gold : AppColors.stroke,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ]);
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.video, required this.queue});
  final Video video;
  final List<Video> queue;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => AppNav.play(context, video),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(fit: StackFit.expand, children: [
          SmartImage(
            url: video.thumbUrl,
            cacheWidth: 600,
            fallback: GeneratedArt(seed: video.title),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.25, 0.62, 1],
                colors: [Color(0x00000000), Color(0x99000000), Color(0xF2000000)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Badge2('NEW SERMON', color: AppColors.gold, textColor: Colors.black),
                const Spacer(),
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.4),
                ),
                const SizedBox(height: 6),
                Text(
                  joinMeta([video.byline, formatDate(video.date), formatRuntime(video.runtimeMinutes)]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Flexible(
                    child: PillButton(icon: Icons.play_arrow_rounded, label: 'Watch', onPressed: () => AppNav.play(context, video)),
                  ),
                  const SizedBox(width: 10),
                  if (video.audioUrl != null)
                    Flexible(child: PillButton(
                      icon: Icons.headphones_rounded,
                      label: 'Listen',
                      primary: false,
                      onPressed: () {
                        AppNav.listen(video);
                        showToast(context, 'Playing audio', icon: Icons.headphones_rounded);
                      },
                    )),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _ContinueWatching extends StatelessWidget {
  const _ContinueWatching();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LibraryStore.instance,
      builder: (context, _) {
        final items = LibraryStore.instance.continueWatching;
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader('Continue Watching'),
          Shelf(
            height: VideoCard.shelfHeight(context, 240),
            itemCount: items.length,
            itemBuilder: (_, i) => VideoCard(video: items[i], width: 240),
          ),
        ]);
      },
    );
  }
}

class _FeedShelf extends StatelessWidget {
  const _FeedShelf({required this.title, required this.load, this.subtitle, this.onSeeAll});

  final String title;
  final String? subtitle;
  final Future<VideoPage> Function() load;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(title, subtitle: subtitle, onSeeAll: onSeeAll),
      AsyncBuilder<VideoPage>(
        future: load,
        loading: const ShelfSkeleton(width: 264, height: 148),
        builder: (context, page) => Shelf(
          height: VideoCard.shelfHeight(context, 264),
          itemCount: page.videos.length,
          itemBuilder: (_, i) => VideoCard(video: page.videos[i]),
        ),
      ),
    ]);
  }
}

class _PreacherShelf extends StatelessWidget {
  const _PreacherShelf();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader('Preachers', subtitle: 'Hard preaching, King James only', onSeeAll: () => AppNav.goTab(AppNav.sermons)),
      AsyncBuilder<Catalog>(
        future: Catalog.load,
        loading: const ShelfSkeleton(width: 76, height: 76, circle: true, textLines: 1),
        builder: (context, cat) {
          final list = cat.preachers.take(14).toList();
          return Shelf(
            height: PreacherChip.heightFor(context, 76),
            spacing: 6,
            itemCount: list.length,
            itemBuilder: (_, i) => PreacherChip(preacher: list[i]),
          );
        },
      ),
    ]);
  }
}

class _GospelBanner extends StatelessWidget {
  const _GospelBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Pressable(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const CategoryScreen(slug: 'salvation', title: 'Salvation'),
        )),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3A2A0E), Color(0xFF1A1306)],
            ),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('THE GOSPEL', style: AppText.eyebrow()),
                const SizedBox(height: 8),
                const Text('How to be saved',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                const SizedBox(height: 6),
                const Text(
                  '"For by grace are ye saved through faith; and that not of yourselves: it is the gift of God." — Ephesians 2:8',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
              ]),
            ),
            const SizedBox(width: 12),
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 32),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ChurchShelf extends StatelessWidget {
  const _ChurchShelf();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('Churches'),
      Shelf(
        height: 138,
        itemCount: churches.length,
        itemBuilder: (_, i) => ChurchCard(
          church: churches[i],
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChurchScreen(church: churches[i]),
          )),
        ),
      ),
    ]);
  }
}

class _DocsShelf extends StatelessWidget {
  const _DocsShelf();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader('Documentaries', subtitle: 'Truth & facts', onSeeAll: () => AppNav.goTab(AppNav.docs)),
      AsyncBuilder<List<Video>>(
        future: () async {
          final all = dedupe(await Api.instance.categoryAll('docs'));
          all.sort((a, b) => b.views.compareTo(a.views));
          return all.take(15).toList();
        },
        loading: const ShelfSkeleton(width: 124, height: 186, textLines: 0),
        builder: (context, docs) => Shelf(
          height: 186,
          spacing: 10,
          itemCount: docs.length,
          itemBuilder: (_, i) => PosterCard(video: docs[i], onTap: () => AppNav.openDoc(context, docs[i], related: docs)),
        ),
      ),
    ]);
  }
}

class _MusicShelf extends StatelessWidget {
  const _MusicShelf();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader('Hymns & Music', onSeeAll: () => AppNav.goTab(AppNav.music)),
      Shelf(
        height: 150,
        itemCount: musicCollections.length,
        itemBuilder: (_, i) {
          final c = musicCollections[i];
          return AlbumCard(
            title: c.title,
            seed: c.slug,
            width: 150,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlbumScreen(collection: c))),
          );
        },
      ),
    ]);
  }
}

class _CollectionShelf extends StatelessWidget {
  const _CollectionShelf({required this.title, required this.items, required this.icon});

  final String title;
  final List<Collection> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(title),
      Shelf(
        height: 150,
        itemCount: items.length,
        itemBuilder: (_, i) {
          final c = items[i];
          return AlbumCard(
            title: c.title,
            seed: c.slug,
            icon: icon,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CategoryScreen(slug: c.slug, title: c.title, subtitle: c.subtitle),
            )),
          );
        },
      ),
    ]);
  }
}
