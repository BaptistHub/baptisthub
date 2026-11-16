/// Data models for the ALLthePREACHING catalogue.
library;

String? _str(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty || s.toLowerCase() == 'null' ? null : s;
}

/// Newer uploads (whose thumbnail sits beside the video under `/video/`)
/// also have an .mp3 next to the .mp4. Category feeds omit
/// `audio_stream_url`, so infer it; playback falls back to the .mp4's audio
/// if the .mp3 is missing.
String? _inferAudio(String? media, String? thumb) {
  if (media == null || thumb == null) return null;
  if (!media.toLowerCase().endsWith('.mp4') || !thumb.contains('/video/')) return null;
  return '${media.substring(0, media.length - 4)}.mp3';
}

int _int(Object? v) => int.tryParse('${v ?? ''}') ?? 0;

/// Parses the API's `2026-11-09 00:00:00` / ISO strings; `0000-00-00` → null.
DateTime? parseApiDate(Object? v) {
  final s = _str(v);
  if (s == null || s.startsWith('0000')) return null;
  final d = DateTime.tryParse(s.replaceFirst(' ', 'T'));
  if (d == null || d.year < 1990) return null;
  return d;
}

/// Builds a safe [Uri] from the site's media URLs, which may contain spaces,
/// accented characters, or `&`.
Uri? safeUri(String? url) {
  if (url == null || url.isEmpty) return null;
  try {
    return Uri.parse(url.contains('%') ? url : Uri.encodeFull(url));
  } catch (_) {
    return null;
  }
}

class CleanTitle {
  const CleanTitle(this.title, {this.track, this.season, this.episode});
  final String title;
  final int? track;
  final int? season;
  final int? episode;
}

final _lsCode = RegExp(
  r'^LS(\d{2})E(\d{2})\s+(?:Season\s+\d+\s*)?(?:Episode\s+\d+\s*)?',
  caseSensitive: false,
);
final _muCode = RegExp(r'^MU[A-Z0-9]+\s+');
final _leadingNumber = RegExp(r'^(\d+)\s+(.+)$');
final _trailingDigits = RegExp(r'(\d+)$');

/// The site stores catalogue codes in titles (e.g. `MUHYMNS098 98 The Name Of
/// Jesus`, `LS03E07 Season 3 Episode 7 ...`). This pulls them out into
/// structured track / season / episode numbers.
CleanTitle cleanTitle(String raw) {
  var t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  int? track, season, episode;

  final ls = _lsCode.firstMatch(t);
  if (ls != null) {
    season = int.parse(ls[1]!);
    episode = int.parse(ls[2]!);
    t = t.substring(ls.end).trim();
  }

  final mu = _muCode.firstMatch(t);
  if (mu != null) {
    final code = mu[0]!.trim();
    t = t.substring(mu.end);
    final n = _leadingNumber.firstMatch(t);
    if (n != null) {
      track = int.parse(n[1]!);
      t = n[2]!;
    } else {
      final d = _trailingDigits.firstMatch(code);
      if (d != null) track = int.parse(d[1]!);
    }
  }

  if (t.isEmpty) t = raw.trim();
  return CleanTitle(t, track: track, season: season, episode: episode);
}

class Video {
  Video({
    required this.id,
    required this.title,
    required this.categorySlug,
    this.categoryName = '',
    this.preacher = '',
    this.date,
    this.mediaUrl,
    this.audioUrl,
    this.rawThumbUrl,
    this.runtimeMinutes,
    this.views = 0,
    this.language = 'en',
    this.track,
    this.season,
    this.episode,
  });

  factory Video.fromJson(Map<String, dynamic> j) {
    final cleaned =
        cleanTitle(_str(j['name']) ?? _str(j['vid_title']) ?? 'Untitled');
    final media = _str(j['stream_url']) ?? _str(j['vid_url']);
    final thumb = _str(j['thumbnail_stream_url']) ?? _str(j['thumb_url']);
    return Video(
      id: _int(j['id']),
      title: cleaned.title,
      track: cleaned.track,
      season: cleaned.season,
      episode: cleaned.episode,
      categorySlug: _str(j['vid_category']) ?? '',
      categoryName: _str(j['main_category']) ?? _str(j['search_category']) ?? '',
      preacher: _str(j['vid_preacher']) ?? '',
      date: parseApiDate(j['date']) ?? parseApiDate(j['published_at']),
      mediaUrl: media,
      audioUrl: _str(j['audio_stream_url']) ?? _inferAudio(media, thumb),
      rawThumbUrl: thumb,
      runtimeMinutes: double.tryParse('${j['runtime_minutes']}'),
      views: _int(j['clicks']),
      language: _str(j['language']) ?? 'en',
    );
  }

  /// Compact form for local persistence (My List, history).
  factory Video.fromStore(Map<String, dynamic> j) => Video(
        id: _int(j['id']),
        title: _str(j['title']) ?? 'Untitled',
        categorySlug: _str(j['cat']) ?? '',
        categoryName: _str(j['catName']) ?? '',
        preacher: _str(j['preacher']) ?? '',
        date: parseApiDate(j['date']),
        mediaUrl: _str(j['media']),
        audioUrl: _str(j['audio']),
        rawThumbUrl: _str(j['thumb']),
        runtimeMinutes: double.tryParse('${j['runtime']}'),
        views: _int(j['views']),
        language: _str(j['lang']) ?? 'en',
        track: j['track'] as int?,
        season: j['season'] as int?,
        episode: j['episode'] as int?,
      );

  Map<String, dynamic> toStore() => {
        'id': id,
        'title': title,
        'cat': categorySlug,
        'catName': categoryName,
        'preacher': preacher,
        'date': date?.toIso8601String(),
        'media': mediaUrl,
        'audio': audioUrl,
        'thumb': rawThumbUrl,
        'runtime': runtimeMinutes,
        'views': views,
        'lang': language,
        'track': track,
        'season': season,
        'episode': episode,
      };

  final int id;
  final String title;
  final String categorySlug;
  final String categoryName;
  final String preacher;
  final DateTime? date;
  final String? mediaUrl;
  final String? audioUrl;
  final String? rawThumbUrl;
  final double? runtimeMinutes;
  final int views;
  final String language;
  final int? track;
  final int? season;
  final int? episode;

  /// Thumbnails under the legacy `/images/thumbs|pics|headers/` folders no
  /// longer exist on the media host, so we skip the request entirely and
  /// render generated artwork instead.
  String? get thumbUrl {
    final u = rawThumbUrl;
    if (u == null) return null;
    if (u.contains('/images/thumbs/') ||
        u.contains('/images/pics/') ||
        u.contains('/images/headers/')) {
      return null;
    }
    return safeUri(u)?.toString();
  }

  bool get isAudioOnly => (mediaUrl ?? '').toLowerCase().endsWith('.mp3');

  /// Best URL for audio-only listening.
  String? get listenUrl => audioUrl ?? mediaUrl;

  String get webUrl => 'https://allthepreaching.com/video/$id';

  /// The speaker line shown under titles.
  String get byline {
    if (preacher.isNotEmpty && !preacher.toLowerCase().startsWith('music')) {
      return preacher;
    }
    return categoryName;
  }

  String get dedupeKey =>
      title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  @override
  bool operator ==(Object other) => other is Video && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Parses a list of API videos, dropping placeholder rows (some endpoints
/// return entries with every field blank).
List<Video> parseVideos(List<Object?> list) => [
      for (final v in list)
        if (v is Map) Video.fromJson(v.cast<String, dynamic>()),
    ].where((v) => v.mediaUrl != null).toList();

class Category {
  const Category({required this.slug, required this.name, required this.count});

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        slug: _str(j['slug']) ?? '',
        name: (_str(j['name']) ?? '').replaceAll(RegExp(r'\s+'), ' '),
        count: _int(j['videoCount']),
      );

  final String slug;
  final String name;
  final int count;
}

class VideoPage {
  const VideoPage({
    required this.videos,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  factory VideoPage.fromJson(Map<String, dynamic> j) {
    final p = (j['pagination'] as Map?)?.cast<String, dynamic>() ?? const {};
    final list = (j['videos'] ?? j['results']) as List? ?? const [];
    return VideoPage(
      videos: parseVideos(list),
      page: _int(p['page']).clamp(1, 1 << 30),
      totalPages: _int(p['totalPages']),
      total: _int(p['total'] ?? j['total']),
    );
  }

  final List<Video> videos;
  final int page;
  final int totalPages;
  final int total;

  bool get hasMore => page < totalPages;
}
