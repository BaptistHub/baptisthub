import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/catalog.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/art.dart';
import '../widgets/cards.dart';
import '../widgets/collapsing_header.dart';
import '../widgets/common.dart';

class ChurchScreen extends StatefulWidget {
  const ChurchScreen({super.key, required this.church});
  final Church church;

  @override
  State<ChurchScreen> createState() => _ChurchScreenState();
}

class _ChurchData {
  _ChurchData(this.pastor, this.congregation);
  final Preacher? pastor;
  final List<Video> congregation;
}

class _ChurchScreenState extends State<ChurchScreen> {
  Future<_ChurchData> _load() async {
    final cat = await Catalog.load();
    final ch = widget.church;
    final pastor = ch.pastorSlug == null ? null : cat.preacher(ch.pastorSlug!);
    final cats = cat.churchCategories(ch);
    final pages = await Future.wait(cats.map((c) => Api.instance.category(c.slug, limit: 100)
        .then((p) => p.videos)
        .catchError((Object _) => <Video>[])));
    final all = dedupe(pages.expand((x) => x))
      ..sort((a, b) => (b.date ?? DateTime(1900)).compareTo(a.date ?? DateTime(1900)));
    return _ChurchData(pastor, all);
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.church;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: CustomScrollView(slivers: [
        CollapsingHeader(
          title: ch.name,
          collapsedTitle: ch.shortName,
          subtitle: ch.location ?? 'Baptist Church',
          icon: Icons.church_rounded,
          background: ChurchImage(church: ch, cacheWidth: 600),
        ),
        SliverToBoxAdapter(
          child: AsyncBuilder<_ChurchData>(
            future: _load,
            compactError: false,
            loading: const ListSkeleton(),
            builder: (context, data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ch.website != null) _WebsiteRow(url: ch.website!),
                if (data.pastor != null) ...[
                  const SectionHeader('Pastor', padding: EdgeInsets.fromLTRB(20, 16, 12, 10)),
                  _PastorCard(preacher: data.pastor!),
                ],
                if (data.congregation.isNotEmpty) ...[
                  SectionHeader('From the congregation', subtitle: plural(data.congregation.length, 'video')),
                  for (final v in data.congregation) VideoTile(video: v, queue: data.congregation),
                ],
                if (data.pastor == null && data.congregation.isEmpty)
                  const EmptyState(icon: Icons.church_outlined, title: 'No uploads yet'),
                if (ch.imageCredit != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Text(ch.imageCredit!, style: const TextStyle(color: AppColors.faint, fontSize: 11)),
                  ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: bottom + 24)),
      ]),
    );
  }
}

class _WebsiteRow extends StatelessWidget {
  const _WebsiteRow({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final host = Uri.parse(url).host.replaceFirst('www.', '');
    // Icon and text sit on the same 20px margin as the rest of the page.
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: url));
        showToast(context, 'Website link copied', icon: Icons.link_rounded);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
        child: Row(children: [
          const Icon(Icons.language_rounded, color: AppColors.gold, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 2),
              const Text('Church website · tap to copy', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
          ),
          const Icon(Icons.copy_rounded, size: 18, color: AppColors.faint),
        ]),
      ),
    );
  }
}

class _PastorCard extends StatelessWidget {
  const _PastorCard({required this.preacher});
  final Preacher preacher;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => AppNav.openPreacher(context, preacher),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              PreacherAvatar(preacher: preacher, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(preacher.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 3),
                  Text(plural(preacher.count, 'sermon'), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
            ]),
          ),
        ),
      ),
    );
  }
}
