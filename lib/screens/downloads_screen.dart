import 'package:flutter/material.dart';

import '../core/audio_controller.dart';
import '../core/downloads.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/download_ui.dart';

/// Full-screen Downloads page (pushed from Home or a download toast).
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: const DownloadsView(),
    );
  }
}

enum _Filter { all, video, audio }

/// The downloads list; also used as a tab inside My Library.
class DownloadsView extends StatefulWidget {
  const DownloadsView({super.key});

  @override
  State<DownloadsView> createState() => _DownloadsViewState();
}

class _DownloadsViewState extends State<DownloadsView> {
  _Filter _filter = _Filter.all;
  final _dl = DownloadManager.instance;

  @override
  Widget build(BuildContext context) {
    if (!DownloadManager.supported) {
      return const EmptyState(
        icon: Icons.phone_android_rounded,
        title: 'Downloads are available in the mobile app',
        message: 'Install BaptistHub on Android or iPhone to save sermons, films and songs for offline use.',
      );
    }
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListenableBuilder(
      listenable: _dl,
      builder: (context, _) {
        final active = _dl.active;
        final failed = _dl.failed;
        final done = _dl.completed.where((i) {
          return switch (_filter) {
            _Filter.all => true,
            _Filter.video => i.kind == DownloadKind.video,
            _Filter.audio => i.kind == DownloadKind.audio,
          };
        }).toList();

        if (active.isEmpty && failed.isEmpty && _dl.completed.isEmpty) {
          return const EmptyState(
            icon: Icons.download_for_offline_outlined,
            title: 'No downloads yet',
            message: 'Tap Download on a sermon, film or song to watch and listen offline, '
                'even with no signal.',
          );
        }

        return ListView(
          padding: EdgeInsets.only(top: 8, bottom: bottom + 24),
          children: [
            _StorageCard(
              bytes: _dl.totalBytes,
              count: _dl.completed.length,
              onDeleteAll: _dl.completed.isEmpty
                  ? null
                  : () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surfaceHigh,
                          title: const Text('Delete all downloads?'),
                          content: Text('This frees ${formatBytes(_dl.totalBytes)} on your device.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete all')),
                          ],
                        ),
                      );
                      if (ok == true) await _dl.deleteAll();
                    },
            ),
            if (active.isNotEmpty) ...[
              SectionHeader('Downloading', subtitle: 'Continues in the background',
                  padding: const EdgeInsets.fromLTRB(20, 24, 12, 8)),
              for (final i in active) _ActiveTile(item: i),
            ],
            if (failed.isNotEmpty) ...[
              const SectionHeader('Failed', padding: EdgeInsets.fromLTRB(20, 24, 12, 8)),
              for (final i in failed) _FailedTile(item: i),
            ],
            if (_dl.completed.isNotEmpty) ...[
              const SectionHeader('On this device', padding: EdgeInsets.fromLTRB(20, 24, 12, 4)),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(children: [
                  for (final f in _Filter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(switch (f) {
                          _Filter.all => 'All',
                          _Filter.video => 'Video',
                          _Filter.audio => 'Audio',
                        }),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                        showCheckmark: false,
                        selectedColor: AppColors.gold,
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.stroke),
                        labelStyle: TextStyle(
                          color: _filter == f ? Colors.black : AppColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: const StadiumBorder(),
                      ),
                    ),
                ]),
              ),
              if (done.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Nothing in this filter', style: TextStyle(color: AppColors.muted))),
                ),
              for (final i in done) _DoneTile(item: i, all: done),
            ],
          ],
        );
      },
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.bytes, required this.count, required this.onDeleteAll});
  final int bytes;
  final int count;
  final VoidCallback? onDeleteAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.sd_storage_rounded, color: AppColors.gold, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(bytes > 0 ? formatBytes(bytes) : '0 MB',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              Text('${plural(count, 'item')} saved on this device',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ]),
          ),
          if (onDeleteAll != null)
            TextButton(
              onPressed: onDeleteAll,
              child: const Text('Delete all', style: TextStyle(color: AppColors.muted)),
            ),
        ]),
      ),
    );
  }
}

Widget _thumb(DownloadItem i) => ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 96,
        height: 54,
        child: Stack(fit: StackFit.expand, children: [
          SmartImage(
            url: i.video.thumbUrl,
            cacheWidth: 100,
            fallback: GeneratedArt(
              seed: i.video.isAudioOnly ? i.video.categorySlug : i.video.categorySlug + i.video.title,
              style: i.video.isAudioOnly ? ArtStyle.album : ArtStyle.wide,
            ),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(color: Color(0xCC000000), shape: BoxShape.circle),
              child: Icon(i.kind == DownloadKind.video ? Icons.movie_rounded : Icons.headphones_rounded,
                  size: 11, color: Colors.white),
            ),
          ),
        ]),
      ),
    );

class _ActiveTile extends StatelessWidget {
  const _ActiveTile({required this.item});
  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final dl = DownloadManager.instance;
    final paused = item.state == DownloadState.paused;
    final queued = item.state == DownloadState.queued;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      child: Row(children: [
        _thumb(item),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.video.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: queued ? null : item.progress,
                minHeight: 4,
                color: paused ? AppColors.faint : AppColors.gold,
                backgroundColor: Colors.white12,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              queued
                  ? 'Waiting…'
                  : joinMeta([
                      paused ? 'Paused' : '${(item.progress * 100).round()}%',
                      if (item.bytes > 0) formatBytes(item.bytes),
                    ]),
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ]),
        ),
        IconButton(
          tooltip: paused ? 'Resume' : 'Pause',
          onPressed: queued ? null : () => paused ? dl.resume(item.key) : dl.pause(item.key),
          icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
        ),
        IconButton(
          tooltip: 'Cancel',
          onPressed: () => dl.cancel(item.key),
          icon: const Icon(Icons.close_rounded, color: AppColors.muted),
        ),
      ]),
    );
  }
}

class _FailedTile extends StatelessWidget {
  const _FailedTile({required this.item});
  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final dl = DownloadManager.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      child: Row(children: [
        _thumb(item),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.video.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 3),
            Text(item.error ?? 'Download failed',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12)),
          ]),
        ),
        IconButton(tooltip: 'Retry', onPressed: () => dl.retry(item.key), icon: const Icon(Icons.refresh_rounded)),
        IconButton(
          tooltip: 'Remove',
          onPressed: () => dl.cancel(item.key),
          icon: const Icon(Icons.close_rounded, color: AppColors.muted),
        ),
      ]),
    );
  }
}

class _DoneTile extends StatelessWidget {
  const _DoneTile({required this.item, required this.all});
  final DownloadItem item;
  final List<DownloadItem> all;

  void _play(BuildContext context) {
    final v = item.video;
    if (item.kind == DownloadKind.audio) {
      // Queue every downloaded audio item so playback continues offline.
      final audio = [for (final i in all) if (i.kind == DownloadKind.audio) i.video];
      AudioController.instance.playQueue(
        audio,
        start: audio.indexOf(v).clamp(0, audio.length - 1),
        title: 'Downloads',
        seed: v.categorySlug,
      );
    } else {
      AppNav.play(context, v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dl = DownloadManager.instance;
    final v = item.video;
    return Dismissible(
      key: ValueKey('dl_${item.key}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: const Color(0xFF3A1212),
        child: const Icon(Icons.delete_outline_rounded),
      ),
      onDismissed: (_) {
        dl.delete(item.key);
        showToast(context, 'Download removed', icon: Icons.delete_outline_rounded);
      },
      child: InkWell(
        onTap: () => _play(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
          child: Row(children: [
            _thumb(item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.25)),
                const SizedBox(height: 3),
                Text(
                  joinMeta([
                    item.kind == DownloadKind.video ? 'Video' : 'Audio',
                    formatBytes(item.bytes),
                    v.byline,
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ]),
            ),
            IconButton(
              tooltip: 'Options',
              onPressed: () => showDownloadSheet(context, v),
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.faint),
            ),
          ]),
        ),
      ),
    );
  }
}
