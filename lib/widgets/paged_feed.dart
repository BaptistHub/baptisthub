import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';
import 'cards.dart';
import 'common.dart';

/// Infinite-scrolling list of videos backed by a paged endpoint.
///
/// Works standalone or as the body of a [NestedScrollView] (it listens to
/// scroll notifications rather than owning a controller).
class PagedFeed extends StatefulWidget {
  const PagedFeed({
    super.key,
    required this.fetch,
    this.header,
    this.showByline = true,
    this.emptyTitle = 'Nothing here yet',
    this.itemBuilder,
  });

  final Future<VideoPage> Function(int page) fetch;
  final Widget? header;
  final bool showByline;
  final String emptyTitle;

  /// Custom row builder; receives the full loaded list for queueing.
  final Widget Function(BuildContext context, Video video, int index, List<Video> all)? itemBuilder;

  @override
  State<PagedFeed> createState() => _PagedFeedState();
}

class _PagedFeedState extends State<PagedFeed> {
  final List<Video> _items = [];
  final Set<int> _ids = {};
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  int _total = 0;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final next = await widget.fetch(_page + 1);
      if (!mounted) return;
      setState(() {
        _page = next.page;
        _total = next.total;
        _hasMore = next.hasMore && next.videos.isNotEmpty;
        for (final v in next.videos) {
          if (_ids.add(v.id)) _items.add(v);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _ids.clear();
      _page = 0;
      _hasMore = true;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final showInitialError = _error != null && _items.isEmpty;
    final showInitialLoading = _loading && _items.isEmpty;

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 600) _loadMore();
        return false;
      },
      child: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.surfaceHigh,
        onRefresh: _refresh,
        child: ListView.builder(
          padding: EdgeInsets.only(top: 4, bottom: bottom + 24),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: (widget.header != null ? 1 : 0) + _items.length + 1,
          itemBuilder: (context, i) {
            if (widget.header != null) {
              if (i == 0) return widget.header!;
              i -= 1;
            }
            if (i < _items.length) {
              final v = _items[i];
              return widget.itemBuilder?.call(context, v, i, _items) ??
                  VideoTile(video: v, queue: _items, showByline: widget.showByline);
            }
            // Footer.
            if (showInitialLoading) return const ListSkeleton();
            if (showInitialError) return ErrorRetry(message: '$_error', onRetry: _loadMore);
            if (_error != null) return ErrorRetry(message: '$_error', onRetry: _loadMore, compact: true);
            if (_items.isEmpty) return EmptyState(icon: Icons.video_library_outlined, title: widget.emptyTitle);
            if (_hasMore) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('${_total > 0 ? _total : _items.length} items',
                    style: const TextStyle(color: AppColors.faint, fontSize: 12)),
              ),
            );
          },
        ),
      ),
    );
  }
}
