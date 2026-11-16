import 'package:flutter/material.dart';

import '../core/library_store.dart';
import '../core/theme.dart';
import '../widgets/cards.dart';
import '../widgets/common.dart';
import 'downloads_screen.dart';

/// My List (saved items), Downloads and watch history.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, this.initialTab = 0});

  /// 0 = My List, 1 = Downloads, 2 = History.
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final lib = LibraryStore.instance;
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Library'),
          bottom: const TabBar(
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [Tab(text: 'My List'), Tab(text: 'Downloads'), Tab(text: 'History')],
          ),
        ),
        body: ListenableBuilder(
          listenable: lib,
          builder: (context, _) {
            final bottom = MediaQuery.paddingOf(context).bottom;
            final saved = lib.myList;
            final history = lib.history;
            return TabBarView(children: [
              saved.isEmpty
                  ? const EmptyState(
                      icon: Icons.bookmark_border_rounded,
                      title: 'Nothing saved yet',
                      message: 'Tap Save or + My List on any sermon or documentary to keep it here.',
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(top: 8, bottom: bottom + 24),
                      itemCount: saved.length,
                      itemBuilder: (_, i) => Dismissible(
                        key: ValueKey(saved[i].id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          color: const Color(0xFF3A1212),
                          child: const Icon(Icons.delete_outline_rounded),
                        ),
                        onDismissed: (_) => lib.toggleMyList(saved[i]),
                        child: VideoTile(video: saved[i], queue: saved),
                      ),
                    ),
              const DownloadsView(),
              history.isEmpty
                  ? const EmptyState(
                      icon: Icons.history_rounded,
                      title: 'No history yet',
                      message: 'Sermons, films and songs you play will show up here.',
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(top: 8, bottom: bottom + 24),
                      itemCount: history.length + 1,
                      itemBuilder: (context, i) {
                        if (i == history.length) {
                          return Center(
                            child: TextButton.icon(
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: AppColors.surfaceHigh,
                                    title: const Text('Clear history?'),
                                    content: const Text('This also resets resume positions.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                                    ],
                                  ),
                                );
                                if (ok == true) lib.clearHistory();
                              },
                              icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.muted),
                              label: const Text('Clear history', style: TextStyle(color: AppColors.muted)),
                            ),
                          );
                        }
                        return VideoTile(video: history[i]);
                      },
                    ),
            ]);
          },
        ),
      ),
    );
  }
}
