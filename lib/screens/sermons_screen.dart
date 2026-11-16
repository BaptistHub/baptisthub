import 'package:flutter/material.dart';

import '../core/catalog.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/art.dart';
import '../widgets/cards.dart';
import '../widgets/common.dart';
import '../widgets/download_ui.dart';
import 'category_screen.dart';
import 'church_screen.dart';

/// Browse preaching by preacher, church, or conference.
class SermonsScreen extends StatelessWidget {
  const SermonsScreen({super.key, this.initialTab = 0});

  /// 0 = Preachers, 1 = Churches, 2 = Conferences.
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 20,
          title: const Text('Sermons', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
          toolbarHeight: 64,
          actions: const [DownloadsButton(), SizedBox(width: 8)],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(48),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: EdgeInsets.symmetric(horizontal: 8),
                indicatorSize: TabBarIndicatorSize.label,
                tabs: [Tab(text: 'Preachers'), Tab(text: 'Churches'), Tab(text: 'Conferences')],
              ),
            ),
          ),
        ),
        body: AsyncBuilder<Catalog>(
          future: Catalog.load,
          compactError: false,
          loading: const Center(child: CircularProgressIndicator(color: AppColors.gold)),
          builder: (context, cat) => TabBarView(children: [
            _PreachersTab(catalog: cat),
            const _ChurchesTab(),
            _ConferencesTab(catalog: cat),
          ]),
        ),
      ),
    );
  }
}

/// Avatar size for the 3-column Featured grid, shrinking on narrow phones.
double _featuredSize(BuildContext context) {
  final cell = (MediaQuery.sizeOf(context).width - 28 - 12) / 3;
  return (cell - 18).clamp(56.0, 84.0);
}

class _PreachersTab extends StatefulWidget {
  const _PreachersTab({required this.catalog});
  final Catalog catalog;

  @override
  State<_PreachersTab> createState() => _PreachersTabState();
}

class _PreachersTabState extends State<_PreachersTab> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final all = widget.catalog.preachers;
    final featured = all.take(6).toList();
    final filtered = _q.isEmpty ? all : all.where((p) => p.name.toLowerCase().contains(_q.toLowerCase())).toList();
    final bottom = MediaQuery.paddingOf(context).bottom;

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: TextField(
            onChanged: (v) => setState(() => _q = v.trim()),
            decoration: InputDecoration(
              hintText: 'Find a preacher',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.faint),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ),
      ),
      if (_q.isEmpty) ...[
        const SliverToBoxAdapter(child: SectionHeader('Featured', padding: EdgeInsets.fromLTRB(20, 20, 12, 12))),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 6,
              // Cell height comes from the content, not the width.
              mainAxisExtent: PreacherChip.heightFor(context, _featuredSize(context)),
            ),
            delegate: SliverChildListDelegate([
              for (final p in featured)
                Align(alignment: Alignment.topCenter, child: PreacherChip(preacher: p, size: _featuredSize(context))),
            ]),
          ),
        ),
        const SliverToBoxAdapter(child: SectionHeader('All preachers', padding: EdgeInsets.fromLTRB(20, 20, 12, 4))),
      ],
      SliverList.builder(
        itemCount: filtered.length,
        itemBuilder: (context, i) {
          final p = filtered[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            leading: PreacherAvatar(preacher: p, size: 44, ring: false),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(plural(p.count, 'sermon'), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
            onTap: () => AppNav.openPreacher(context, p),
          );
        },
      ),
      SliverToBoxAdapter(child: SizedBox(height: bottom + 24)),
    ]);
  }
}

class _ChurchesTab extends StatelessWidget {
  const _ChurchesTab();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 16 / 10,
      ),
      itemCount: churches.length,
      itemBuilder: (context, i) => ChurchCard(
        church: churches[i],
        width: double.infinity,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChurchScreen(church: churches[i]))),
      ),
    );
  }
}

class _ConferencesTab extends StatelessWidget {
  const _ConferencesTab({required this.catalog});
  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    final list = catalog.conferences;
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (list.isEmpty) return const EmptyState(icon: Icons.event_outlined, title: 'No conferences found');
    return ListView.builder(
      padding: EdgeInsets.only(top: 8, bottom: bottom + 24),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final c = list[i];
        final newYear = i == 0 || list[i - 1].year != c.year;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (newYear)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text('${c.year}', style: AppText.display(26, color: AppColors.gold)),
            ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox.square(
                dimension: 48,
                child: GeneratedArt(seed: c.name, style: ArtStyle.album, icon: Icons.event_rounded),
              ),
            ),
            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(plural(c.count, 'message'), style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CategoryScreen(slug: c.slug, title: '${c.name} ${c.year}'),
            )),
          ),
        ]);
      },
    );
  }
}
