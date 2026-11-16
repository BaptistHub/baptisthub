import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// What to save: the video file (.mp4) or audio only (.mp3).
enum DownloadKind { video, audio }

enum DownloadState { queued, downloading, paused, done, failed }

class DownloadItem {
  DownloadItem({
    required this.video,
    required this.kind,
    required this.filename,
    this.state = DownloadState.queued,
    this.progress = 0,
    this.bytes = 0,
    this.error,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  factory DownloadItem.fromJson(Map<String, dynamic> j) => DownloadItem(
        video: Video.fromStore((j['video'] as Map).cast<String, dynamic>()),
        kind: DownloadKind.values.byName(j['kind'] as String),
        filename: j['file'] as String,
        // Anything unfinished is re-synced from the downloader on start.
        state: j['done'] == true ? DownloadState.done : DownloadState.queued,
        bytes: (j['bytes'] as num?)?.toInt() ?? 0,
        addedAt: DateTime.tryParse('${j['added']}'),
      );

  Map<String, dynamic> toJson() => {
        'video': video.toStore(),
        'kind': kind.name,
        'file': filename,
        'done': state == DownloadState.done,
        'bytes': bytes,
        'added': addedAt.toIso8601String(),
      };

  final Video video;
  final DownloadKind kind;
  final String filename;
  final DateTime addedAt;
  DownloadState state;

  /// 0..1 while downloading.
  double progress;

  /// File size (expected while downloading, actual once done).
  int bytes;
  String? error;

  String get key => DownloadManager.keyFor(video.id, kind);
  bool get isActive =>
      state == DownloadState.queued || state == DownloadState.downloading || state == DownloadState.paused;
}

/// Saves sermons, films and songs to the device for offline playback.
///
/// Uses background_downloader so large files keep downloading (with a
/// progress notification) when the app is in the background or closed, and
/// resume after interruptions.
class DownloadManager extends ChangeNotifier {
  DownloadManager._();
  static final DownloadManager instance = DownloadManager._();

  static const _prefsKey = 'downloads_v1';
  static const _dir = 'downloads';

  /// Downloads need a real file system; the web build is preview-only.
  static bool get supported => !kIsWeb;

  final Map<String, DownloadItem> _items = {};
  final Map<String, int> _sizeCache = {};
  SharedPreferences? _prefs;
  String? _basePath;
  bool _askedNotificationPermission = false;

  static String keyFor(int id, DownloadKind kind) => '${id}_${kind.name}';

  Future<void> init() async {
    if (!supported) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _basePath = '${(await getApplicationSupportDirectory()).path}/$_dir';
      for (final raw in _prefs!.getStringList(_prefsKey) ?? const <String>[]) {
        final item = DownloadItem.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        // Drop finished downloads whose file the OS has since removed.
        if (item.state == DownloadState.done && !File(_pathOf(item)).existsSync()) continue;
        _items[item.key] = item;
      }

      FileDownloader().configureNotification(
        running: const TaskNotification('Downloading', '{displayName}'),
        complete: const TaskNotification('Download complete', '{displayName}'),
        error: const TaskNotification('Download failed', '{displayName}'),
        paused: const TaskNotification('Download paused', '{displayName}'),
        progressBar: true,
      );
      FileDownloader().updates.listen(_onUpdate);
      // Re-attaches to downloads that ran while the app was closed.
      await FileDownloader().start();
      notifyListeners();
    } catch (e) {
      debugPrint('Downloads init failed: $e');
    }
  }

  // ---- Queries ---------------------------------------------------------------

  List<DownloadItem> get items => _items.values.toList().reversed.toList();
  List<DownloadItem> get active => items.where((i) => i.isActive).toList();
  List<DownloadItem> get completed => items.where((i) => i.state == DownloadState.done).toList();
  List<DownloadItem> get failed => items.where((i) => i.state == DownloadState.failed).toList();

  int get totalBytes => completed.fold(0, (sum, i) => sum + i.bytes);

  DownloadItem? item(int id, DownloadKind kind) => _items[keyFor(id, kind)];

  bool isDownloaded(int id, DownloadKind kind) => item(id, kind)?.state == DownloadState.done;

  bool hasAnyDownload(int id) => isDownloaded(id, DownloadKind.video) || isDownloaded(id, DownloadKind.audio);

  /// Which kinds can be saved for this item.
  List<DownloadKind> kindsFor(Video v) => [
        if (!v.isAudioOnly && v.mediaUrl != null) DownloadKind.video,
        if (_urlFor(v, DownloadKind.audio) != null) DownloadKind.audio,
      ];

  /// The natural download for one tap: audio for songs, video otherwise.
  DownloadKind defaultKind(Video v) => v.isAudioOnly ? DownloadKind.audio : DownloadKind.video;

  /// Local file for playing [v] as video, if downloaded.
  String? localVideo(Video v) => _localPath(v.id, DownloadKind.video);

  /// Local file for listening to [v]: the .mp3 if saved, else the saved
  /// video (players can play an .mp4's audio track).
  String? localAudio(Video v) => _localPath(v.id, DownloadKind.audio) ?? _localPath(v.id, DownloadKind.video);

  String? _localPath(int id, DownloadKind kind) {
    final i = item(id, kind);
    if (i == null || i.state != DownloadState.done || _basePath == null) return null;
    final p = _pathOf(i);
    return File(p).existsSync() ? p : null;
  }

  String _pathOf(DownloadItem i) => '$_basePath/${i.filename}';

  String? _urlFor(Video v, DownloadKind kind) {
    if (kind == DownloadKind.video) return v.isAudioOnly ? null : v.mediaUrl;
    return v.isAudioOnly ? v.mediaUrl : v.audioUrl;
  }

  /// File size from the server (HEAD request), cached. Null if unknown.
  Future<int?> remoteSize(Video v, DownloadKind kind) async {
    final key = keyFor(v.id, kind);
    if (_sizeCache.containsKey(key)) return _sizeCache[key];
    final uri = safeUri(_urlFor(v, kind));
    if (uri == null) return null;
    try {
      final res = await http.head(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final len = int.tryParse(res.headers['content-length'] ?? '');
      if (len != null && len > 0) _sizeCache[key] = len;
      return len;
    } catch (_) {
      return null;
    }
  }

  // ---- Actions ---------------------------------------------------------------

  Future<bool> download(Video v, DownloadKind kind) async {
    if (!supported) return false;
    final key = keyFor(v.id, kind);
    final existing = _items[key];
    if (existing != null && (existing.isActive || existing.state == DownloadState.done)) return true;

    final uri = safeUri(_urlFor(v, kind));
    if (uri == null) return false;
    await _ensureNotificationPermission();

    final filename = '$key.${kind == DownloadKind.video ? 'mp4' : 'mp3'}';
    final item = DownloadItem(video: v, kind: kind, filename: filename);
    _items[key] = item;
    _persist();
    notifyListeners();

    final ok = await FileDownloader().enqueue(DownloadTask(
      taskId: key,
      url: uri.toString(),
      filename: filename,
      directory: _dir,
      baseDirectory: BaseDirectory.applicationSupport,
      updates: Updates.statusAndProgress,
      allowPause: true,
      retries: 3,
      displayName: v.title,
      metaData: kind.name,
    ));
    if (!ok) {
      item
        ..state = DownloadState.failed
        ..error = 'Could not start the download';
      notifyListeners();
    }
    return ok;
  }

  /// Queues several items (e.g. a whole album), skipping saved ones.
  Future<void> downloadAll(Iterable<Video> videos, DownloadKind kind) async {
    for (final v in videos) {
      if (!kindsFor(v).contains(kind)) continue;
      await download(v, kind);
    }
  }

  Future<void> cancel(String key) async {
    _items.remove(key);
    _persist();
    notifyListeners();
    if (supported) await FileDownloader().cancelTaskWithId(key);
  }

  Future<void> cancelAll(Iterable<String> keys) async {
    final list = keys.toList();
    for (final k in list) {
      _items.remove(k);
    }
    _persist();
    notifyListeners();
    if (supported) await FileDownloader().cancelTasksWithIds(list);
  }

  Future<void> pause(String key) async {
    final record = await FileDownloader().database.recordForId(key);
    final task = record?.task;
    if (task is DownloadTask) await FileDownloader().pause(task);
  }

  Future<void> resume(String key) async {
    final record = await FileDownloader().database.recordForId(key);
    final task = record?.task;
    if (task is DownloadTask) await FileDownloader().resume(task);
  }

  Future<void> retry(String key) async {
    final i = _items.remove(key);
    if (i == null) return;
    await download(i.video, i.kind);
  }

  /// Deletes a finished download's file.
  Future<void> delete(String key) async {
    final i = _items.remove(key);
    _persist();
    notifyListeners();
    if (i == null || _basePath == null) return;
    try {
      final f = File(_pathOf(i));
      if (f.existsSync()) await f.delete();
    } catch (_) {}
    await FileDownloader().database.deleteRecordWithId(key);
  }

  Future<void> deleteAll() async {
    for (final k in completed.map((i) => i.key).toList()) {
      await delete(k);
    }
  }

  /// Seeds items for layout tests (no files or platform calls involved).
  @visibleForTesting
  void debugSetItems(List<DownloadItem> items) {
    _items
      ..clear()
      ..addEntries(items.map((i) => MapEntry(i.key, i)));
    notifyListeners();
  }

  // ---- Internals -------------------------------------------------------------

  Future<void> _ensureNotificationPermission() async {
    if (_askedNotificationPermission) return;
    _askedNotificationPermission = true;
    try {
      final p = FileDownloader().permissions;
      if (await p.status(PermissionType.notifications) != PermissionStatus.granted) {
        await p.request(PermissionType.notifications);
      }
    } catch (_) {
      // Downloads still work without the progress notification.
    }
  }

  void _onUpdate(TaskUpdate update) {
    final item = _items[update.task.taskId];
    if (item == null) return;
    switch (update) {
      case TaskStatusUpdate(:final status):
        switch (status) {
          case TaskStatus.enqueued:
          case TaskStatus.waitingToRetry:
            item.state = DownloadState.queued;
          case TaskStatus.running:
            item.state = DownloadState.downloading;
          case TaskStatus.paused:
            item.state = DownloadState.paused;
          case TaskStatus.complete:
            item
              ..state = DownloadState.done
              ..progress = 1;
            try {
              item.bytes = File(_pathOf(item)).lengthSync();
            } catch (_) {}
            _persist();
          case TaskStatus.notFound:
            item
              ..state = DownloadState.failed
              ..error = item.kind == DownloadKind.audio
                  ? 'No audio file on the server. Try the video instead.'
                  : 'File not found on the server';
          case TaskStatus.failed:
            item
              ..state = DownloadState.failed
              ..error = 'Download failed. Check your connection and retry.';
          case TaskStatus.canceled:
            _items.remove(item.key);
            _persist();
        }
      case TaskProgressUpdate(:final progress, :final expectedFileSize):
        if (progress >= 0 && progress <= 1) {
          item.progress = progress;
          if (item.state == DownloadState.queued) item.state = DownloadState.downloading;
        }
        if (expectedFileSize > 0) item.bytes = expectedFileSize;
    }
    notifyListeners();
  }

  void _persist() => _prefs?.setStringList(
        _prefsKey,
        [for (final i in _items.values) if (i.state != DownloadState.failed) jsonEncode(i.toJson())],
      );
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var u = 0;
  while (size >= 1024 && u < units.length - 1) {
    size /= 1024;
    u++;
  }
  return '${size < 10 && u > 0 ? size.toStringAsFixed(1) : size.round()} ${units[u]}';
}
