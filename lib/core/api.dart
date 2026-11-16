import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class _CacheEntry {
  _CacheEntry(this.at, this.data);
  final DateTime at;
  final Object? data;
}

/// Client for the public JSON API behind allthepreaching.com.
///
/// Responses are cached in memory for [_ttl] and identical in-flight requests
/// are shared, so widgets can call these freely from `build`-adjacent code.
class Api {
  Api._();
  static final Api instance = Api._();

  static const base = 'https://api.allthepreaching.com';
  static const _ttl = Duration(minutes: 10);

  /// Swappable so tests can serve recorded responses.
  http.Client client = http.Client();
  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Future<Object?>> _inflight = {};

  Future<Object?> _get(String path, [Map<String, String>? params]) {
    var uri = Uri.parse('$base$path');
    if (params != null && params.isNotEmpty) {
      uri = uri.replace(queryParameters: params);
    }
    final key = uri.toString();
    final hit = _cache[key];
    if (hit != null && DateTime.now().difference(hit.at) < _ttl) {
      return Future.value(hit.data);
    }
    return _inflight[key] ??= () async {
      try {
        final res = await client.get(uri, headers: const {
          'Accept': 'application/json'
        }).timeout(const Duration(seconds: 20));
        if (res.statusCode == 404) throw ApiException('Not found');
        if (res.statusCode != 200) {
          throw ApiException('Server error (${res.statusCode})');
        }
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        _cache[key] = _CacheEntry(DateTime.now(), data);
        return data;
      } on TimeoutException {
        throw ApiException('The server took too long to respond');
      } on ApiException {
        rethrow;
      } catch (_) {
        throw ApiException('Could not reach ALLthePREACHING');
      } finally {
        _inflight.remove(key);
      }
    }();
  }

  Future<List<Category>> categories() async {
    final data = await _get('/api/categories') as List;
    return [
      for (final c in data) Category.fromJson((c as Map).cast<String, dynamic>())
    ];
  }

  /// Videos in a single category (preacher, documentary set, album…).
  Future<VideoPage> category(String slug, {int page = 1, int limit = 30}) async {
    final data = await _get(
      '/api/categories/${Uri.encodeComponent(slug)}',
      {'page': '$page', 'limit': '$limit'},
    ) as Map;
    return VideoPage.fromJson(data.cast<String, dynamic>());
  }

  /// Fetches every item in a small category (albums, documentaries).
  Future<List<Video>> categoryAll(String slug, {int max = 300}) async {
    final first = await category(slug, limit: max > 200 ? 200 : max);
    if (!first.hasMore || first.videos.length >= max) return first.videos;
    final second = await category(slug, page: 2, limit: 200);
    return [...first.videos, ...second.videos];
  }

  /// The global feed, newest first. `sort: 'views'` gives all-time popular.
  /// The API serves 24 per page.
  Future<VideoPage> videos({
    int page = 1,
    String? sort,
    String? category,
    String? preacher,
  }) async {
    final data = await _get('/api/videos', {
      'page': '$page',
      if (sort != null) 'sort': sort,
      if (category != null) 'category': category,
      if (preacher != null) 'preacher': preacher,
    }) as Map;
    return VideoPage.fromJson(data.cast<String, dynamic>());
  }

  Future<Video> video(int id) async {
    final data = await _get('/api/videos/$id') as Map;
    return Video.fromJson(data.cast<String, dynamic>());
  }

  Future<List<Video>> recommendations(int id, {int limit = 12}) async {
    final data =
        await _get('/api/videos/$id/recommendations', {'limit': '$limit'});
    if (data is! List) return const [];
    return parseVideos(data);
  }

  Future<SearchResult> search(String q, {int limit = 30, int offset = 0}) async {
    final data = await _get('/api/search', {
      'q': q,
      'limit': '$limit',
      'offset': '$offset',
    }) as Map;
    final list = data['results'] as List? ?? const [];
    return SearchResult(
      total: int.tryParse('${data['total']}') ?? list.length,
      videos: parseVideos(list),
    );
  }
}

class SearchResult {
  const SearchResult({required this.total, required this.videos});
  final int total;
  final List<Video> videos;
}
