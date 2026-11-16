import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/audio_controller.dart';
import '../core/catalog.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/art.dart';
import '../widgets/cards.dart';
import '../widgets/common.dart';
import '../widgets/download_ui.dart';

Future<List<Video>> loadAlbum(String slug) async {
  final tracks = dedupe(await Api.instance.categoryAll(slug, max: 400));
  tracks.sort((a, b) {
    if (a.track != null && b.track != null) return a.track!.compareTo(b.track!);
    if (a.track != null) return -1;
    if (b.track != null) return 1;
    return a.title.compareTo(b.title);
  });
  return tracks;
}

class MusicScreen extends StatelessWidget {
  const MusicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final hymns = musicCollections.first;
    final others = musicCollections.skip(1).toList();
    return Scaffold(
      body: CustomScrollView(slivers: [
        const SliverAppBar(
          floating: true,
          titleSpacing: 20,
          toolbarHeight: 64,
          title: Text('Music', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
          actions: [DownloadsButton(), SizedBox(width: 8)],
        ),
        SliverToBoxAdapter(child: _FeaturedAlbum(collection: hymns)),
        const SliverToBoxAdapter(child: SectionHeader('Albums', subtitle: 'Psalms, choirs and the FWBC collection')),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 18,
              crossAxisSpacing: 14,
              childAspectRatio: 0.82,
            ),
            itemCount: others.length,
            itemBuilder: (context, i) {
              final c = others[i];
              return LayoutBuilder(
                builder: (context, box) => AlbumCard(
                  title: c.title,
                  seed: c.slug,
                  subtitle: c.subtitle,
                  width: box.maxWidth,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlbumScreen(collection: c))),
                ),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SectionHeader('Quick picks', subtitle: 'Hymns to start with')),
        SliverToBoxAdapter(
          child: AsyncBuilder<List<Video>>(
            future: () => loadAlbum(hymns.slug),
            loading: const ListSkeleton(count: 5),
            builder: (context, tracks) {
              // A different handful each day.
              final day = DateTime.now().difference(DateTime(2024)).inDays;
              final picks = <Video>{
                for (var i = 0; i < 8 && tracks.isNotEmpty; i++) tracks[(day * 7 + i * 23) % tracks.length]
              }.toList();
              return Column(children: [
                for (final t in picks)
                  TrackTile(
                    video: t,
                    number: t.track ?? 0,
                    onTap: () => AudioController.instance.playQueue(
                      picks,
                      start: picks.indexOf(t),
                      title: 'Quick picks',
                      seed: hymns.slug,
                    ),
                  ),
              ]);
            },
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: bottom + 24)),
      ]),
    );
  }
}

class _FeaturedAlbum extends StatelessWidget {
  const _FeaturedAlbum({required this.collection});
  final Collection collection;

  @override
  Widget build(BuildContext context) {
    final c = collection;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Pressable(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlbumScreen(collection: c))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          // Grows with the text size instead of using a fixed height.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 200),
            child: Stack(children: [
              Positioned.fill(child: GeneratedArt(seed: c.slug, style: ArtStyle.album)),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FEATURED', style: AppText.eyebrow()),
                    const SizedBox(height: 40),
                    Text(c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1)),
                    FutureBuilder<Catalog>(
                      future: Catalog.load(),
                      builder: (_, s) => Text(
                        joinMeta([c.subtitle, if ((s.data?.countOf(c.slug) ?? 0) > 0) plural(s.data!.countOf(c.slug), 'song')]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _PlayShuffleRow(collection: c),
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

class _PlayShuffleRow extends StatelessWidget {
  const _PlayShuffleRow({required this.collection, this.tracks});
  final Collection collection;
  final List<Video>? tracks;

  Future<List<Video>> _tracks() async => tracks ?? await loadAlbum(collection.slug);

  @override
  Widget build(BuildContext context) {
    final audio = AudioController.instance;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: PillButton(
          icon: Icons.play_arrow_rounded,
          label: 'Play',
          onPressed: () async {
            final t = await _tracks();
            audio.playQueue(t, title: collection.title, seed: collection.slug);
          },
        ),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: PillButton(
          icon: Icons.shuffle_rounded,
          label: 'Shuffle',
          primary: false,
          onPressed: () async {
            final t = await _tracks();
            audio.shuffle(t, title: collection.title, seed: collection.slug);
          },
        ),
      ),
      if (tracks != null) ...[
        const SizedBox(width: 10),
        AlbumDownloadButton(tracks: tracks!, title: collection.title),
      ],
    ]);
  }
}

class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key, required this.collection});
  final Collection collection;

  @override
  Widget build(BuildContext context) {
    final c = collection;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final tint = accentFor(c.slug);
    return Scaffold(
      body: AsyncBuilder<List<Video>>(
        future: () => loadAlbum(c.slug),
        compactError: false,
        loading: const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        builder: (context, tracks) => CustomScrollView(slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.bg,
            title: Text(c.title),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [tint.withValues(alpha: 0.28), AppColors.bg],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(children: [
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: tint.withValues(alpha: 0.4), blurRadius: 40, offset: const Offset(0, 18))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: GeneratedArt(seed: c.slug, style: ArtStyle.album, title: c.title, icon: Icons.music_note_rounded),
                  ),
                ),
                const SizedBox(height: 20),
                Text(c.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text(joinMeta([c.subtitle, plural(tracks.length, 'song')]), style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 18),
                Center(child: _PlayShuffleRow(collection: c, tracks: tracks)),
              ]),
            ),
          ),
          SliverList.builder(
            itemCount: tracks.length,
            itemBuilder: (context, i) => TrackTile(
              video: tracks[i],
              number: tracks[i].track ?? i + 1,
              onTap: () => AudioController.instance.playQueue(tracks, start: i, title: c.title, seed: c.slug),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: bottom + 24)),
        ]),
      ),
    );
  }
}
