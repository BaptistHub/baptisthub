import 'package:flutter/material.dart';

import '../core/downloads.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../screens/downloads_screen.dart';
import 'art.dart';
import 'common.dart';

final _dl = DownloadManager.instance;

String _kindLabel(DownloadKind k) => k == DownloadKind.video ? 'Video' : 'Audio only';
IconData _kindIcon(DownloadKind k) => k == DownloadKind.video ? Icons.movie_outlined : Icons.headphones_rounded;

/// One-tap download when there's a single sensible choice; otherwise opens
/// the options sheet (e.g. sermons: video or audio only).
Future<void> quickDownload(BuildContext context, Video v) async {
  if (!DownloadManager.supported) {
    showToast(context, 'Downloads are available in the mobile app', icon: Icons.phone_android_rounded);
    return;
  }
  final kinds = _dl.kindsFor(v);
  final anyState = kinds.any((k) => _dl.item(v.id, k) != null);
  if (kinds.length == 1 && !anyState) {
    _start(context, v, kinds.first);
  } else {
    await showDownloadSheet(context, v);
  }
}

void _start(BuildContext context, Video v, DownloadKind kind) {
  _dl.download(v, kind);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(children: [
        const Icon(Icons.downloading_rounded, color: AppColors.gold, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text('Downloading ${kind == DownloadKind.audio ? 'audio' : 'video'}…')),
      ]),
      action: SnackBarAction(
        label: 'VIEW',
        textColor: AppColors.gold,
        onPressed: () => openDownloads(context),
      ),
    ));
}

void openDownloads(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DownloadsScreen()));

/// Bottom sheet with every download option and its live state.
Future<void> showDownloadSheet(BuildContext context, Video v) {
  if (!DownloadManager.supported) {
    showToast(context, 'Downloads are available in the mobile app', icon: Icons.phone_android_rounded);
    return Future.value();
  }
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (sheetContext) => SafeArea(
      child: ListenableBuilder(
        listenable: _dl,
        builder: (sheetContext, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 14),
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: AppColors.stroke, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 44,
                    child: SmartImage(
                      url: v.thumbUrl,
                      cacheWidth: 80,
                      fallback: GeneratedArt(seed: v.categorySlug + v.title, style: ArtStyle.album),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(v.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.25)),
                    const SizedBox(height: 2),
                    Text(v.byline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  ]),
                ),
              ]),
            ),
            const Divider(height: 1),
            for (final k in _dl.kindsFor(v)) _KindRow(video: v, kind: k, onStart: () {
              Navigator.pop(sheetContext);
              _start(context, v, k);
            }),
            if (_dl.kindsFor(v).isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('This item has no downloadable file.', style: TextStyle(color: AppColors.muted)),
              ),
            const Divider(height: 1),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const Icon(Icons.download_for_offline_outlined, color: AppColors.muted),
              title: const Text('Manage downloads'),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
              onTap: () {
                Navigator.pop(sheetContext);
                openDownloads(context);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _KindRow extends StatelessWidget {
  const _KindRow({required this.video, required this.kind, required this.onStart});
  final Video video;
  final DownloadKind kind;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final item = _dl.item(video.id, kind);
    final label = _kindLabel(kind);

    Widget sizeText(String prefix) => FutureBuilder<int?>(
          future: _dl.remoteSize(video, kind),
          builder: (_, s) => Text(
            joinMeta([prefix, if (s.data != null) formatBytes(s.data!)]),
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
        );

    if (item == null) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Icon(_kindIcon(kind), color: AppColors.text),
        title: Text('Download ${label.toLowerCase()}', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: sizeText(kind == DownloadKind.video ? 'MP4' : 'MP3 · smaller, for listening'),
        trailing: const Icon(Icons.download_rounded, color: AppColors.gold),
        onTap: onStart,
      );
    }

    switch (item.state) {
      case DownloadState.done:
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: const Icon(Icons.download_done_rounded, color: AppColors.gold),
          title: Text('$label saved', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(joinMeta(['Plays offline', formatBytes(item.bytes)]),
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          trailing: TextButton(
            onPressed: () => _dl.delete(item.key),
            child: const Text('Remove', style: TextStyle(color: Color(0xFFFF8A80))),
          ),
        );
      case DownloadState.failed:
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: const Icon(Icons.error_outline_rounded, color: Color(0xFFFF8A80)),
          title: Text('$label download failed', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(item.error ?? '', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          trailing: TextButton(onPressed: () => _dl.retry(item.key), child: const Text('Retry')),
        );
      case DownloadState.queued:
      case DownloadState.downloading:
      case DownloadState.paused:
        final paused = item.state == DownloadState.paused;
        return ListTile(
          contentPadding: const EdgeInsets.only(left: 20, right: 8, top: 4, bottom: 4),
          leading: DownloadProgressRing(progress: item.state == DownloadState.queued ? null : item.progress, size: 26),
          title: Text(
            paused ? '$label paused' : item.state == DownloadState.queued ? 'Waiting to download…' : 'Downloading $label',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            joinMeta(['${(item.progress * 100).round()}%', if (item.bytes > 0) 'of ${formatBytes(item.bytes)}']),
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: paused ? 'Resume' : 'Pause',
              onPressed: () => paused ? _dl.resume(item.key) : _dl.pause(item.key),
              icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            ),
            IconButton(
              tooltip: 'Cancel',
              onPressed: () => _dl.cancel(item.key),
              icon: const Icon(Icons.close_rounded),
            ),
          ]),
        );
    }
  }
}

/// Top-bar Downloads button shown on every tab. While anything is
/// downloading it turns into a progress ring (overall progress) with a badge
/// counting active downloads, so progress is visible from anywhere.
class DownloadsButton extends StatelessWidget {
  const DownloadsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _dl,
      builder: (context, _) {
        final active = _dl.active;
        final n = active.length;
        final downloading = active.where((i) => i.state != DownloadState.queued).toList();
        final progress = downloading.isEmpty
            ? null
            : downloading.fold<double>(0, (sum, i) => sum + i.progress) / downloading.length;

        final Widget icon = n == 0
            ? const Icon(Icons.download_for_offline_outlined)
            : SizedBox.square(
                dimension: 24,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 2.2,
                      color: AppColors.gold,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  const Icon(Icons.arrow_downward_rounded, size: 13, color: AppColors.gold),
                ]),
              );

        return IconButton(
          tooltip: n > 0 ? 'Downloads: ${plural(n, 'item')} in progress' : 'Downloads',
          onPressed: () => openDownloads(context),
          icon: Badge(
            isLabelVisible: n > 0,
            label: Text('$n'),
            backgroundColor: AppColors.gold,
            textColor: Colors.black,
            child: icon,
          ),
        );
      },
    );
  }
}

/// Circular progress with a stop square, like app-store downloads.
class DownloadProgressRing extends StatelessWidget {
  const DownloadProgressRing({super.key, required this.progress, this.size = 22, this.color = AppColors.gold});
  final double? progress;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.square(
          dimension: size,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 2.2,
            color: color,
            backgroundColor: Colors.white12,
          ),
        ),
        Container(
          width: size * 0.3,
          height: size * 0.3,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1.5)),
        ),
      ]),
    );
  }
}

/// Aggregate state across both kinds, for compact buttons.
({DownloadState? state, double progress}) _summary(Video v) {
  final items = [for (final k in DownloadKind.values) _dl.item(v.id, k)].whereType<DownloadItem>().toList();
  if (items.any((i) => i.state == DownloadState.done)) return (state: DownloadState.done, progress: 1);
  final active = items.where((i) => i.isActive).toList();
  if (active.isNotEmpty) {
    final a = active.first;
    return (state: a.state, progress: a.progress);
  }
  if (items.any((i) => i.state == DownloadState.failed)) return (state: DownloadState.failed, progress: 0);
  return (state: null, progress: 0);
}

/// Pill chip for the player's action row.
class DownloadChip extends StatelessWidget {
  const DownloadChip({super.key, required this.video});
  final Video video;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _dl,
      builder: (context, _) {
        final s = _summary(video);
        final done = s.state == DownloadState.done;
        final active = s.state != null && !done && s.state != DownloadState.failed;
        final Widget icon = active
            ? DownloadProgressRing(progress: s.state == DownloadState.queued ? null : s.progress, size: 17)
            : Icon(done ? Icons.download_done_rounded : Icons.download_rounded,
                size: 18, color: done ? AppColors.gold : AppColors.text);
        final label = done
            ? 'Downloaded'
            : active
                ? '${(s.progress * 100).round()}%'
                : 'Download';
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Material(
            color: done ? AppColors.gold.withValues(alpha: 0.16) : AppColors.surfaceHigh,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => s.state == null ? quickDownload(context, video) : showDownloadSheet(context, video),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  icon,
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13, color: done ? AppColors.gold : AppColors.text)),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Icon + label button for the film detail page's action row.
class DownloadActionButton extends StatelessWidget {
  const DownloadActionButton({super.key, required this.video});
  final Video video;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _dl,
      builder: (context, _) {
        final s = _summary(video);
        final done = s.state == DownloadState.done;
        final active = s.state != null && !done && s.state != DownloadState.failed;
        return InkResponse(
          onTap: () => s.state == null ? quickDownload(context, video) : showDownloadSheet(context, video),
          radius: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox.square(
                dimension: 28,
                child: Center(
                  child: active
                      ? DownloadProgressRing(progress: s.state == DownloadState.queued ? null : s.progress, size: 24)
                      : Icon(done ? Icons.download_done_rounded : Icons.download_rounded,
                          size: 28, color: done ? AppColors.gold : AppColors.text),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                done ? 'Downloaded' : active ? '${(s.progress * 100).round()}%' : 'Download',
                style: TextStyle(color: done ? AppColors.gold : AppColors.muted, fontSize: 12),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// Small corner badge for thumbnails of saved items.
class DownloadedBadge extends StatelessWidget {
  const DownloadedBadge({super.key, required this.videoId});
  final int videoId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _dl,
      builder: (context, _) {
        if (!_dl.hasAnyDownload(videoId)) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(color: Color(0xCC000000), shape: BoxShape.circle),
          child: const Icon(Icons.download_done_rounded, size: 14, color: AppColors.gold),
        );
      },
    );
  }
}

/// Round button for album headers: download every track.
class AlbumDownloadButton extends StatelessWidget {
  const AlbumDownloadButton({super.key, required this.tracks, required this.title});
  final List<Video> tracks;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _dl,
      builder: (context, _) {
        const kind = DownloadKind.audio;
        final downloadable = tracks.where((t) => _dl.kindsFor(t).contains(kind)).toList();
        final items = [for (final t in downloadable) _dl.item(t.id, kind)];
        final done = items.where((i) => i?.state == DownloadState.done).length;
        final active = items.whereType<DownloadItem>().where((i) => i.isActive).toList();
        final allDone = downloadable.isNotEmpty && done == downloadable.length;

        Widget child;
        String tooltip;
        if (allDone) {
          child = const Icon(Icons.download_done_rounded, color: AppColors.gold);
          tooltip = 'Album downloaded';
        } else if (active.isNotEmpty) {
          child = DownloadProgressRing(progress: downloadable.isEmpty ? 0 : done / downloadable.length, size: 22);
          tooltip = 'Downloading $done of ${downloadable.length}';
        } else {
          child = const Icon(Icons.download_rounded);
          tooltip = 'Download album';
        }

        return Tooltip(
          message: tooltip,
          child: SizedBox.square(
            dimension: 46,
            child: Material(
              color: Colors.white.withValues(alpha: 0.12),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () async {
                  if (!DownloadManager.supported) {
                    showToast(context, 'Downloads are available in the mobile app', icon: Icons.phone_android_rounded);
                    return;
                  }
                  if (allDone) {
                    final ok = await _confirm(context, 'Remove downloads?',
                        'Delete all ${downloadable.length} downloaded songs from "$title"?', 'Remove');
                    if (ok) {
                      for (final i in items.whereType<DownloadItem>()) {
                        await _dl.delete(i.key);
                      }
                    }
                  } else if (active.isNotEmpty) {
                    final ok = await _confirm(context, 'Stop downloading?',
                        '$done of ${downloadable.length} songs are saved. Cancel the rest?', 'Cancel downloads');
                    if (ok) await _dl.cancelAll(active.map((i) => i.key));
                  } else {
                    _dl.downloadAll(downloadable, kind);
                    if (context.mounted) {
                      showToast(context, 'Downloading ${downloadable.length - done} songs', icon: Icons.downloading_rounded);
                    }
                  }
                },
                child: Center(child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<bool> _confirm(BuildContext context, String title, String message, String action) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceHigh,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
      ],
    ),
  );
  return ok == true;
}
