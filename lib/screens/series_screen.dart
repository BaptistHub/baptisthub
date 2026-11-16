import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/catalog.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/art.dart';
import '../widgets/cards.dart';
import '../widgets/common.dart';

/// Grid of every short-form series.
class SeriesIndexScreen extends StatelessWidget {
  const SeriesIndexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: const Text('Bible Series')),
      body: GridView.builder(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 16 / 10,
        ),
        itemCount: docSeries.length,
        itemBuilder: (context, i) {
          final s = docSeries[i];
          return Pressable(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SeriesScreen(collection: s))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: GeneratedArt(seed: s.slug, style: ArtStyle.wide, title: s.title, label: s.subtitle),
            ),
          );
        },
      ),
    );
  }
}

class _Episode {
  _Episode(this.video, this.season, this.number, this.title);
  final Video video;
  final int season;
  final int? number;
  final String title;
}

final _leadingNum = RegExp(r'^(\d+)\.?\s+(.+)$');

List<_Episode> _toEpisodes(List<Video> videos) {
  final eps = <_Episode>[];
  for (final v in videos) {
    if (v.season != null) {
      eps.add(_Episode(v, v.season!, v.episode, v.title));
      continue;
    }
    final m = _leadingNum.firstMatch(v.title);
    eps.add(m != null ? _Episode(v, 1, int.parse(m[1]!), m[2]!) : _Episode(v, 1, null, v.title));
  }
  eps.sort((a, b) {
    if (a.season != b.season) return a.season.compareTo(b.season);
    if (a.number != null && b.number != null) return a.number!.compareTo(b.number!);
    if (a.number != null) return -1;
    if (b.number != null) return 1;
    return (a.video.date ?? DateTime(1900)).compareTo(b.video.date ?? DateTime(1900));
  });
  return eps;
}

/// Netflix-style show page with a season picker and episode list.
class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key, required this.collection});
  final Collection collection;

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  int? _season;

  @override
  Widget build(BuildContext context) {
    final c = widget.collection;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      body: AsyncBuilder<List<_Episode>>(
        future: () async => _toEpisodes(dedupe(await Api.instance.categoryAll(c.slug))),
        compactError: false,
        loading: const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        builder: (context, eps) {
          final seasons = eps.map((e) => e.season).toSet().toList()..sort();
          final season = _season ?? (seasons.isEmpty ? 1 : seasons.first);
          final visible = eps.where((e) => e.season == season).toList();
          // Start at episode 1, not a "behind the scenes" episode 0.
          final first = visible.where((e) => (e.number ?? 1) >= 1).firstOrNull ?? visible.firstOrNull;
          return CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.black,
              expandedHeight: MediaQuery.sizeOf(context).width * 9 / 16,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  GeneratedArt(seed: c.slug, style: ArtStyle.wide),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.4, 1],
                        colors: [Colors.transparent, Colors.black],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 16, height: 3, color: AppColors.crimson),
                    const SizedBox(width: 8),
                    Text('SERIES', style: AppText.eyebrow(color: Colors.white70)),
                  ]),
                  const SizedBox(height: 8),
                  Text(c.title.toUpperCase(), style: AppText.display(46)),
                  const SizedBox(height: 8),
                  Text(
                    joinMeta([
                      if (seasons.length > 1) plural(seasons.length, 'Season'),
                      plural(eps.length, 'episode'),
                      c.subtitle,
                    ]),
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (first != null)
                    PillButton(
                      icon: Icons.play_arrow_rounded,
                      label: first.number != null
                          ? (seasons.length > 1 ? 'Play S$season:E${first.number}' : 'Play Episode ${first.number}')
                          : 'Play',
                      expand: true,
                      onPressed: () => AppNav.play(context, first.video),
                    ),
                  const SizedBox(height: 20),
                  if (seasons.length > 1)
                    _SeasonPicker(
                      seasons: seasons,
                      value: season,
                      onChanged: (s) => setState(() => _season = s),
                    )
                  else
                    const Text('Episodes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
            SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (_, i) => _EpisodeRow(episode: visible[i], index: i),
            ),
            SliverToBoxAdapter(child: SizedBox(height: bottom + 24)),
          ]);
        },
      ),
    );
  }
}

class _SeasonPicker extends StatelessWidget {
  const _SeasonPicker({required this.seasons, required this.value, required this.onChanged});
  final List<int> seasons;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final picked = await showModalBottomSheet<int>(
            context: context,
            backgroundColor: Colors.black.withValues(alpha: 0.92),
            builder: (ctx) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 16),
                for (final s in seasons)
                  ListTile(
                    title: Text(
                      'Season $s',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: s == value ? 20 : 17,
                        fontWeight: s == value ? FontWeight.w800 : FontWeight.w500,
                        color: s == value ? Colors.white : AppColors.muted,
                      ),
                    ),
                    onTap: () => Navigator.pop(ctx, s),
                  ),
                const SizedBox(height: 16),
              ]),
            ),
          );
          if (picked != null) onChanged(picked);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Season $value', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ]),
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.episode, required this.index});
  final _Episode episode;
  final int index;

  @override
  Widget build(BuildContext context) {
    final v = episode.video;
    final n = episode.number;
    return InkWell(
      onTap: () => AppNav.play(context, v),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          SizedBox(
            width: 132,
            child: Stack(alignment: Alignment.center, children: [
              VideoThumb(video: v, radius: 6, showTitleArt: false, cacheWidth: 140),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black45,
                  border: Border.all(color: Colors.white70, width: 1.5),
                ),
                child: const Icon(Icons.play_arrow_rounded, size: 22),
              ),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                n != null && n > 0 ? '$n. ${episode.title}' : episode.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.25),
              ),
              const SizedBox(height: 4),
              Text(
                joinMeta([formatRuntime(v.runtimeMinutes), if (v.views > 0) plural(v.views, 'view')]),
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
