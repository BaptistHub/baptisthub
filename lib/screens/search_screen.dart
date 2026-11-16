import 'dart:async';

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
import '../widgets/download_ui.dart';
import 'category_screen.dart';
import 'music_screen.dart';
import 'series_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';
  final List<Video> _results = [];
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(text.trim()));
    setState(() {});
  }

  Future<void> _search(String q) async {
    final id = ++_requestId;
    setState(() {
      _query = q;
      _error = null;
      _results.clear();
      _total = 0;
      _loading = q.length >= 2;
    });
    if (q.length < 2) return;
    try {
      final r = await Api.instance.search(q, limit: 30);
      if (id != _requestId || !mounted) return;
      setState(() {
        _results.addAll(r.videos);
        _total = r.total;
      });
    } catch (e) {
      if (id == _requestId && mounted) setState(() => _error = '$e');
    } finally {
      if (id == _requestId && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _results.length >= _total || _query.length < 2) return;
    final id = _requestId;
    setState(() => _loadingMore = true);
    try {
      final r = await Api.instance.search(_query, limit: 30, offset: _results.length);
      if (id != _requestId || !mounted) return;
      final ids = _results.map((v) => v.id).toSet();
      setState(() {
        _results.addAll(r.videos.where((v) => ids.add(v.id)));
        if (r.videos.isEmpty) _total = _results.length;
      });
    } catch (_) {
      // Keep existing results; user can scroll again to retry.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _submit(String q) {
    _debounce?.cancel();
    _search(q.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        toolbarHeight: 64,
        title: const Text('Search', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
        actions: const [DownloadsButton(), SizedBox(width: 8)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              onChanged: _onChanged,
              onSubmitted: _submit,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Sermons, preachers, topics, hymns…',
                hintStyle: const TextStyle(color: AppColors.faint),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                        onPressed: () {
                          _controller.clear();
                          _submit('');
                        },
                      ),
                filled: true,
                fillColor: AppColors.surfaceHigh,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.gold, width: 1.2),
                ),
              ),
            ),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => _focus.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: _query.length < 2 ? const _Browse() : _resultsView(),
      ),
    );
  }

  Widget _resultsView() {
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (_loading) return const SingleChildScrollView(child: ListSkeleton());
    if (_error != null) return ErrorRetry(message: _error!, onRetry: () => _search(_query), compact: false);
    if (_results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results for "$_query"',
        message: 'Try a book of the Bible, a preacher\'s name, or a topic like "soulwinning".',
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 500) _loadMore();
        return false;
      },
      child: ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(bottom: bottom + 24),
        itemCount: _results.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text('${formatCount(_total)} results',
                  style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
            );
          }
          if (i == _results.length + 1) {
            return _loadingMore
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)),
                  )
                : const SizedBox(height: 8);
          }
          return VideoTile(video: _results[i - 1], queue: _results);
        },
      ),
    );
  }
}

class _BrowseItem {
  const _BrowseItem(this.title, this.icon, this.open);
  final String title;
  final IconData icon;
  final void Function(BuildContext) open;
}

void _push(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

final _browse = <_BrowseItem>[
  _BrowseItem('Preachers', Icons.mic_rounded, (_) => AppNav.goTab(AppNav.sermons)),
  _BrowseItem('Documentaries', Icons.movie_rounded, (_) => AppNav.goTab(AppNav.docs)),
  _BrowseItem('Salvation', Icons.favorite_rounded, (c) => _push(c, const CategoryScreen(slug: 'salvation', title: 'Salvation'))),
  _BrowseItem('Hymns', Icons.music_note_rounded, (c) => _push(c, AlbumScreen(collection: musicCollections[0]))),
  _BrowseItem('Psalms', Icons.auto_stories_rounded, (c) => _push(c, AlbumScreen(collection: musicCollections[1]))),
  _BrowseItem('Soulwinning Tips', Icons.directions_walk_rounded,
      (c) => _push(c, const CategoryScreen(slug: 'swtips', title: 'Soulwinning Tips'))),
  _BrowseItem('Bible Series', Icons.video_library_rounded, (c) => _push(c, const SeriesIndexScreen())),
  _BrowseItem('Interviews', Icons.forum_rounded, (c) => _push(c, const CategoryScreen(slug: 'interviews', title: 'Interviews'))),
  _BrowseItem('The Baptist Bias', Icons.podcasts_rounded,
      (c) => _push(c, const CategoryScreen(slug: 'pcbias', title: 'The Baptist Bias'))),
  _BrowseItem('Topics for Dummies', Icons.lightbulb_rounded,
      (c) => _push(c, const CategoryScreen(slug: 'mdummies', title: 'Topics for Dummies'))),
];

const _suggestions = ['Romans', 'Soulwinning', 'Salvation', 'Proverbs', 'Revelation', 'Marriage', 'King James Bible', 'Baptism'];

class _Browse extends StatelessWidget {
  const _Browse();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final state = context.findAncestorStateOfType<_SearchScreenState>();
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        const SliverToBoxAdapter(child: SectionHeader('Try searching', padding: EdgeInsets.fromLTRB(20, 8, 12, 10))),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in _suggestions)
                ActionChip(
                  label: Text(s),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.stroke),
                  shape: const StadiumBorder(),
                  onPressed: () {
                    state?._controller.text = s;
                    state?._submit(s);
                  },
                ),
            ]),
          ),
        ),
        const SliverToBoxAdapter(child: SectionHeader('Browse all')),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.75,
            ),
            itemCount: _browse.length,
            itemBuilder: (context, i) {
              final b = _browse[i];
              final colors = paletteFor('browse${b.title}');
              return Pressable(
                onTap: () => b.open(context),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colors[2].withValues(alpha: 0.85), colors[1]],
                    ),
                  ),
                  child: Stack(children: [
                    Text(b.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, height: 1.15)),
                    Positioned(
                      right: -6,
                      bottom: -10,
                      child: Transform.rotate(
                        angle: 0.3,
                        child: Icon(b.icon, size: 52, color: Colors.white.withValues(alpha: 0.35)),
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: bottom + 24)),
      ],
    );
  }
}
