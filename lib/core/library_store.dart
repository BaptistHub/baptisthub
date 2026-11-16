import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// On-device library: My List, watch history and resume positions.
class LibraryStore extends ChangeNotifier {
  LibraryStore._();
  static final LibraryStore instance = LibraryStore._();

  static const _kList = 'my_list_v1';
  static const _kHistory = 'history_v1';
  static const _kPositions = 'positions_v1';
  static const _maxHistory = 60;

  SharedPreferences? _prefs;
  final Map<int, Video> _myList = {};
  final List<Video> _history = [];

  /// id → [positionSeconds, durationSeconds]
  final Map<int, List<int>> _positions = {};

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      for (final raw in _prefs!.getStringList(_kList) ?? const <String>[]) {
        final v = Video.fromStore(jsonDecode(raw) as Map<String, dynamic>);
        _myList[v.id] = v;
      }
      for (final raw in _prefs!.getStringList(_kHistory) ?? const <String>[]) {
        _history.add(Video.fromStore(jsonDecode(raw) as Map<String, dynamic>));
      }
      final pos = _prefs!.getString(_kPositions);
      if (pos != null) {
        (jsonDecode(pos) as Map<String, dynamic>).forEach((k, v) {
          _positions[int.parse(k)] = (v as List).cast<int>();
        });
      }
    } catch (e) {
      debugPrint('Library load failed: $e');
    }
  }

  List<Video> get myList => _myList.values.toList().reversed.toList();
  List<Video> get history => List.unmodifiable(_history);

  bool inMyList(int id) => _myList.containsKey(id);

  /// Returns true if the video is now in the list.
  bool toggleMyList(Video v) {
    final added = !_myList.containsKey(v.id);
    if (added) {
      _myList[v.id] = v;
    } else {
      _myList.remove(v.id);
    }
    _prefs?.setStringList(
        _kList, [for (final x in _myList.values) jsonEncode(x.toStore())]);
    notifyListeners();
    return added;
  }

  void recordPlay(Video v) {
    _history.removeWhere((x) => x.id == v.id);
    _history.insert(0, v);
    if (_history.length > _maxHistory) _history.removeLast();
    _persistHistory();
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    _positions.clear();
    _persistHistory();
    _prefs?.remove(_kPositions);
    notifyListeners();
  }

  void _persistHistory() => _prefs?.setStringList(
      _kHistory, [for (final x in _history) jsonEncode(x.toStore())]);

  /// Saves without notifying; call [flush] when playback screen closes.
  void savePosition(int id, Duration position, Duration duration) {
    if (duration.inSeconds <= 0) return;
    _positions[id] = [position.inSeconds, duration.inSeconds];
    _prefs?.setString(_kPositions,
        jsonEncode(_positions.map((k, v) => MapEntry('$k', v))));
  }

  void flush() => notifyListeners();

  /// Where to resume, if the user stopped meaningfully part-way through.
  Duration? resumePosition(int id) {
    final p = _positions[id];
    if (p == null) return null;
    final pos = p[0], dur = p[1];
    if (pos < 20 || pos > dur - 30) return null;
    return Duration(seconds: pos);
  }

  /// 0..1 progress for progress bars, or null if never started.
  double? progress(int id) {
    final p = _positions[id];
    if (p == null || p[1] <= 0) return null;
    return (p[0] / p[1]).clamp(0.0, 1.0);
  }

  List<Video> get continueWatching => [
        for (final v in _history)
          if (!v.isAudioOnly && resumePosition(v.id) != null) v,
      ];
}
