import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'art_cache.dart';
import 'downloads.dart';
import 'library_store.dart';
import 'models.dart';

/// App-wide audio player: music albums, podcasts and "listen" mode for
/// sermons. Drives the mini player and the Now Playing screen.
class AudioController extends ChangeNotifier {
  AudioController._() {
    _subs.add(player.currentIndexStream.listen((i) {
      if (i == null || i == _index || i >= _queue.length) return;
      _index = i;
      LibraryStore.instance.recordPlay(_queue[i]);
      notifyListeners();
    }));
    _subs.add(player.playerStateStream.listen((s) {
      final playing = s.playing && s.processingState != ProcessingState.completed;
      if (playing != _wasPlaying ||
          s.processingState != _lastState) {
        _wasPlaying = playing;
        _lastState = s.processingState;
        notifyListeners();
      }
    }, onError: (Object e) {
      error = 'Playback failed';
      notifyListeners();
    }));
  }

  static final AudioController instance = AudioController._();

  final AudioPlayer player = AudioPlayer();
  final List<StreamSubscription<Object?>> _subs = [];

  List<Video> _queue = const [];
  int _index = 0;
  bool _wasPlaying = false;
  ProcessingState _lastState = ProcessingState.idle;

  /// Title of the album / playlist the queue came from.
  String? queueTitle;

  /// Seed for generated artwork (album slug), so art matches the album.
  String? artSeed;
  String? error;

  List<Video> get queue => _queue;
  int get index => _index;
  Video? get current => _queue.isEmpty ? null : _queue[_index.clamp(0, _queue.length - 1)];
  bool get isPlaying => player.playing && player.processingState != ProcessingState.completed;
  bool get isLoading =>
      player.processingState == ProcessingState.loading ||
      player.processingState == ProcessingState.buffering;
  bool get hasNext => player.hasNext;
  bool get hasPrevious => player.hasPrevious;

  Future<void> playQueue(
    List<Video> items, {
    int start = 0,
    String? title,
    String? seed,
    Duration? position,
  }) async {
    final dl = DownloadManager.instance;
    final playable = [for (final v in items) if (dl.localAudio(v) != null || safeUri(v.listenUrl) != null) v];
    if (playable.isEmpty) return;
    final startVideo = items[start.clamp(0, items.length - 1)];
    final startIndex = playable.indexOf(startVideo).clamp(0, playable.length - 1);

    _queue = playable;
    _index = startIndex;
    queueTitle = title;
    artSeed = seed;
    error = null;
    LibraryStore.instance.recordPlay(_queue[_index]);
    notifyListeners();

    try {
      final sources = await Future.wait(playable.map(_sourceFor));
      await player.setAudioSources(
        sources,
        initialIndex: startIndex,
        initialPosition: position,
      );
      unawaited(player.play());
    } catch (e) {
      // A sermon's .mp3 may be missing; fall back to the audio in the .mp4.
      final v = _queue[_index];
      final fallback = safeUri(v.mediaUrl);
      if (playable.length == 1 && v.audioUrl != null && fallback != null) {
        try {
          await player.setAudioSource(AudioSource.uri(fallback, tag: await _mediaItem(v)),
              initialPosition: position);
          unawaited(player.play());
          return;
        } catch (_) {}
      }
      error = 'This recording is unavailable right now';
      notifyListeners();
    }
  }

  /// Plays from the downloaded file when there is one (works offline).
  Future<AudioSource> _sourceFor(Video v) async {
    final local = DownloadManager.instance.localAudio(v);
    final uri = local != null ? Uri.file(local) : safeUri(v.listenUrl)!;
    return AudioSource.uri(uri, tag: await _mediaItem(v));
  }

  /// Lock screen / notification metadata. Uses the sermon still when there
  /// is one, otherwise the same generated album art the app shows.
  Future<MediaItem> _mediaItem(Video v) async {
    final album = queueTitle ?? v.categoryName;
    final art = safeUri(v.thumbUrl) ??
        await ArtCache.uriFor(artSeed ?? v.categorySlug, title: album, label: 'BaptistHub');
    final minutes = v.runtimeMinutes;
    return MediaItem(
      id: '${v.id}',
      title: v.title,
      artist: v.isAudioOnly ? album : v.byline,
      album: album,
      artUri: art,
      duration: minutes == null ? null : Duration(seconds: (minutes * 60).round()),
    );
  }

  Future<void> playSingle(Video v, {Duration? position}) =>
      playQueue([v], title: v.byline, position: position);

  Future<void> shuffle(List<Video> items, {String? title, String? seed}) {
    final copy = [...items]..shuffle();
    return playQueue(copy, title: title, seed: seed);
  }

  void toggle() => isPlaying ? player.pause() : player.play();
  Future<void> pause() => player.pause();
  Future<void> next() => player.seekToNext();

  Future<void> previous() async {
    if (player.position > const Duration(seconds: 4) || !player.hasPrevious) {
      await player.seek(Duration.zero);
    } else {
      await player.seekToPrevious();
    }
  }

  Future<void> jumpTo(int i) => player.seek(Duration.zero, index: i);

  Future<void> stop() async {
    await player.stop();
    _queue = const [];
    _index = 0;
    queueTitle = null;
    notifyListeners();
  }

  bool isCurrent(Video v) => current?.id == v.id;
}
