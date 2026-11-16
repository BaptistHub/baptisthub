import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/catalog.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../widgets/art.dart';
import '../widgets/collapsing_header.dart';
import '../widgets/paged_feed.dart';

/// Generic listing for any category (podcast, series, conference…) or any
/// paged feed.
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key, required String this.slug, required this.title, this.subtitle})
      : fetch = null;

  const CategoryScreen.feed({super.key, required this.title, required Future<VideoPage> Function(int) this.fetch, this.subtitle})
      : slug = null;

  final String? slug;
  final String title;
  final String? subtitle;
  final Future<VideoPage> Function(int page)? fetch;

  @override
  Widget build(BuildContext context) {
    final seed = slug ?? title;
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          FutureBuilder<Catalog>(
            future: slug == null ? null : Catalog.load(),
            builder: (context, snap) {
              final n = slug == null ? 0 : (snap.data?.countOf(slug!) ?? 0);
              final line = joinMeta([subtitle, if (n > 0) plural(n, 'video')]);
              return CollapsingHeader(
                title: title,
                subtitle: line.isEmpty ? null : line,
                expandedHeight: 200,
                background: GeneratedArt(seed: seed, style: ArtStyle.wide),
              );
            },
          ),
        ],
        body: PagedFeed(
          fetch: fetch ?? (p) => Api.instance.category(slug!, page: p),
        ),
      ),
    );
  }
}
