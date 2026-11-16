import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/catalog.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/paged_feed.dart';

class PreacherScreen extends StatelessWidget {
  const PreacherScreen({super.key, required this.preacher});
  final Preacher preacher;

  @override
  Widget build(BuildContext context) {
    final p = preacher;
    final hasClips = p.clipsSlug != null;
    final sermons = PagedFeed(
      fetch: (page) => Api.instance.category(p.slug, page: page),
      showByline: false,
    );
    final header = <Widget>[
      SliverAppBar(
        pinned: true,
        expandedHeight: hasClips ? 358 : 310,
        backgroundColor: AppColors.bg,
        title: const SizedBox.shrink(),
        flexibleSpace: FlexibleSpaceBar(
          collapseMode: CollapseMode.parallax,
          background: _PreacherHeader(preacher: p, reserveTabs: hasClips),
        ),
        bottom: hasClips
            ? const TabBar(
                tabs: [Tab(text: 'Sermons'), Tab(text: 'Clips')],
                indicatorSize: TabBarIndicatorSize.label,
              )
            : null,
      ),
    ];
    if (!hasClips) {
      return Scaffold(body: NestedScrollView(headerSliverBuilder: (_, __) => header, body: sermons));
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (_, __) => header,
          body: TabBarView(children: [
            sermons,
            PagedFeed(
              fetch: (page) => Api.instance.category(p.clipsSlug!, page: page),
              showByline: false,
            ),
          ]),
        ),
      ),
    );
  }
}

class _PreacherHeader extends StatelessWidget {
  const _PreacherHeader({required this.preacher, required this.reserveTabs});
  final Preacher preacher;
  final bool reserveTabs;

  @override
  Widget build(BuildContext context) {
    final p = preacher;
    final top = MediaQuery.paddingOf(context).top;
    return FutureBuilder<VideoPage>(
      future: Api.instance.category(p.slug, limit: 30),
      builder: (context, snap) {
        final latest = snap.data?.videos.firstOrNull;
        final backdrop = snap.data?.videos.map((v) => v.thumbUrl).whereType<String>().firstOrNull;
        return Stack(fit: StackFit.expand, children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: SmartImage(url: backdrop, cacheWidth: 300, fallback: GeneratedArt(seed: p.slug)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), AppColors.bg],
                stops: [0, 0.92],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 56, 20, reserveTabs ? 62 : 16),
            // Width is pinned to the screen; if the content is ever taller
            // than the header (large text sizes), it scales down instead of
            // overflowing.
            child: LayoutBuilder(
              builder: (context, box) => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: box.maxWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PreacherAvatar(preacher: p, size: 88),
                      const SizedBox(height: 12),
                      Text(p.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.15)),
                      const SizedBox(height: 4),
                      Text(
                        joinMeta([plural(p.count, 'sermon'), if (latest?.date != null) 'Latest ${formatDate(latest!.date)}']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Flexible(
                          child: PillButton(
                            icon: Icons.play_arrow_rounded,
                            label: 'Latest',
                            onPressed: latest == null ? null : () => AppNav.play(context, latest),
                          ),
                        ),
                        if (latest?.audioUrl != null) ...[
                          const SizedBox(width: 10),
                          Flexible(
                            child: PillButton(
                              icon: Icons.headphones_rounded,
                              label: 'Listen',
                              primary: false,
                              onPressed: () => AppNav.listen(latest!),
                            ),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }
}
