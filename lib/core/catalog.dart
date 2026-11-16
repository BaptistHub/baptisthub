import 'package:flutter/foundation.dart' show visibleForTesting;

import 'api.dart';
import 'models.dart';

/// Organises the API's flat category list into preachers, churches,
/// conferences, music albums, podcasts and documentary collections.
class Preacher {
  const Preacher({
    required this.slug,
    required this.name,
    required this.count,
    this.clipsSlug,
  });

  final String slug;
  final String name;
  final int count;
  final String? clipsSlug;

  String get initials {
    final words = name
        .replaceAll(RegExp(r'^(Pastor|Bro\.?|Brother|Deacon|Evangelist)\s+'), '')
        .split(' ')
        .where((w) => w.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(w[0]))
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words.first[0] + words.last[0]).toUpperCase();
  }
}

class Church {
  const Church({
    required this.name,
    required this.shortName,
    required this.keywords,
    required this.image,
    this.pastorSlug,
    this.website,
    this.location,
    this.imageCredit,
  });

  final String name;
  final String shortName;

  /// Bundled photo/logo (assets/churches/), sourced from the church's own
  /// website or uploads. See README "Image credits".
  final String image;
  final String? website;
  final String? location;

  /// Attribution, where the image licence requires one.
  final String? imageCredit;

  /// Lower-case fragments matched against category slugs and names.
  final List<String> keywords;

  /// Category slug of the lead pastor's sermons, when known.
  final String? pastorSlug;
}

class Collection {
  const Collection(this.slug, this.title, this.subtitle);
  final String slug;
  final String title;
  final String subtitle;
}

/// The churches the site highlights. Congregation uploads are found by
/// keyword; the pastor link is a curated mapping.
const churches = <Church>[
  Church(
    name: 'Faithful Word Baptist Church',
    shortName: 'Faithful Word',
    keywords: ['faithful_word', 'faithful word'],
    pastorSlug: 'fsanderson',
    image: 'assets/churches/faithful_word.jpg',
    website: 'https://www.faithfulwordbaptist.org',
    location: 'Phoenix, Arizona',
    imageCredit: 'Photo: Steven L. Anderson (Faithful Word Baptist Church), CC BY 3.0, via Wikimedia Commons',
  ),
  Church(
    name: 'Stedfast Baptist Church',
    shortName: 'Stedfast',
    keywords: ['stedfast'],
    pastorSlug: 'fsshelley',
    image: 'assets/churches/stedfast.jpg',
    website: 'https://stedfastkjv.com',
    location: 'Cedar Hill, Texas',
  ),
  Church(
    name: 'First Works Baptist Church',
    shortName: 'First Works',
    keywords: ['first_works', 'first works', 'firstworks'],
    pastorSlug: 'fsmejia',
    image: 'assets/churches/first_works.jpg',
    website: 'https://www.fwbcla.org',
    location: 'Los Angeles, California',
  ),
  Church(
    name: 'Sure Foundation Baptist Church',
    shortName: 'Sure Foundation',
    keywords: ['sfbc'],
    pastorSlug: 'fsthompson',
    image: 'assets/churches/sure_foundation.jpg',
    website: 'https://www.surefoundationbaptist.com',
    location: 'Vancouver, Washington',
  ),
  Church(
    name: 'Anchor Baptist Church',
    shortName: 'Anchor',
    keywords: ['anchor'],
    image: 'assets/churches/anchor.jpg',
  ),
  Church(
    name: 'Soulwinning Baptist Church Melbourne',
    shortName: 'SWBC Melbourne',
    keywords: ['soulwinningbc'],
    image: 'assets/churches/swbc_melbourne.jpg',
    website: 'https://www.soulwinningbaptist.au',
    location: 'Melbourne, Australia',
  ),
];

const musicCollections = <Collection>[
  Collection('muhymns', 'Hymns', 'Classic hymns of the faith'),
  Collection('mupsalms', 'Psalms', 'Sung from the King James Bible'),
  Collection('mufwbcvol1', 'FWBC Collection Vol. 1', 'Faithful Word Baptist Church'),
  Collection('mufwbcvol2', 'FWBC Collection Vol. 2', 'Faithful Word Baptist Church'),
  Collection('mufwbcvol3', 'FWBC Collection Vol. 3', 'Faithful Word Baptist Church'),
  Collection('mufwbcvol4', 'FWBC Collection Vol. 4', 'Faithful Word Baptist Church'),
  Collection('mufwbcvol5', 'FWBC Collection Vol. 5', 'Faithful Word Baptist Church'),
  Collection('mufwbcvol6', 'FWBC Collection Vol. 6', 'Faithful Word Baptist Church'),
  Collection('muother', 'Specials & Choirs', 'Christmas, choirs and more'),
];

const podcasts = <Collection>[
  Collection('pcbias', 'The Baptist Bias', 'Podcast'),
  Collection('pcsword', 'The Sword of the Spirit', 'Podcast'),
  Collection('pcrod', 'The Rod of Iron', 'Podcast'),
  Collection('pctrue', 'The True Born Sons', 'Podcast'),
  Collection('pcolive', 'The Olive Crown', 'Podcast'),
  Collection('pcuncensored', 'The Uncensored', 'Podcast'),
  Collection('pcfwbc', 'FWBC Podcast', 'Podcast'),
];

/// Short-form teaching series shown as "Series" on the documentaries tab.
const docSeries = <Collection>[
  Collection('landmarks', 'Landmarks', 'A series in seasons'),
  Collection('mdummies', 'Topics for Dummies', 'Bible basics, explained'),
  Collection('misrael', 'Israel Moments', 'Short teaching series'),
  Collection('mposttrib', 'Post-Trib Moments', 'Bible prophecy'),
  Collection('mtrinity', 'Trinity Moments', 'Short teaching series'),
  Collection('mkjv', 'KJV Minutes', 'The preserved word of God'),
  Collection('mcreation', 'Creation Moments', 'Science & Scripture'),
  Collection('mthess', 'Thessalonian Moments', 'Short teaching series'),
  Collection('mmormon', 'Mormon Moments', 'Short teaching series'),
  Collection('mhindu', 'Hindu Moments', 'Short teaching series'),
  Collection('mdotd', 'Day of the Dead Moments', 'Short teaching series'),
];

const soulwinning = <Collection>[
  Collection('swtips', 'Soulwinning Tips', 'Practical door-to-door help'),
  Collection('swmotivation', 'Soulwinning Motivation', 'Get out and preach the gospel'),
];

/// Display names for the main preachers (the API's names are folder labels).
const _preacherNames = {
  'fsanderson': 'Pastor Steven L. Anderson',
  'fsmejia': 'Pastor Bruce Mejia',
  'fsshelley': 'Pastor Jonathan Shelley',
  'fsthompson': 'Pastor Aaron Thompson',
  'fsressl': 'Deacon Corbin Ressl',
  'fsawes': 'Pastor Dillon Awes',
  'fsreyes': 'Pastor Enrique Reyes',
  'fszhong': 'Justin Zhong',
  'fsremythompson': 'Remy Thompson',
  'fsnaim': 'Bro. Ben Naim',
  'fsorozco': 'Bro. Diego Orozco',
  'fssegura': 'Bro. Chris Segura',
  'fsadrianbalic': 'Bro. Adrian Balic',
  'fsmatthewstucky': 'Pastor Matthew Stucky',
  'fscooper': 'Bro. Raymond Cooper',
};

const _clipsFor = {
  'fsanderson': 'scanderson',
  'fsmejia': 'scmejia',
  'fsshelley': 'scshelley',
  'fsthompson': 'scthompson',
  'fsressl': 'scressl',
  'fsawes': 'scawes',
  'fssegura': 'scsegura',
  'fsmatthewstucky': 'scstucky',
};

final _conference = RegExp(
  r'^(rhpc|fbbf|kjc|fbc|fwbcmc|fwbcpc|ptbpc|masa|hlc|ngyr|mtzc|prophcon)\d{4}$',
  caseSensitive: false,
);

class Conference {
  const Conference({required this.slug, required this.name, required this.year, required this.count});
  final String slug;
  final String name;
  final int year;
  final int count;
}

class Catalog {
  Catalog._(this.categories);

  final List<Category> categories;

  static Future<Catalog>? _future;

  /// Drops the cached catalogue. Tests call this between cases: a future
  /// created in one test's fake-async zone never completes in the next.
  @visibleForTesting
  static void reset() => _future = null;

  static Future<Catalog> load() {
    return _future ??= Api.instance.categories().then(Catalog._).catchError(
      (Object e) {
        _future = null;
        throw e;
      },
    );
  }

  Category? find(String slug) {
    for (final c in categories) {
      if (c.slug == slug) return c;
    }
    return null;
  }

  int countOf(String slug) => find(slug)?.count ?? 0;

  bool _isChurch(Category c) {
    final hay = '${c.slug} ${c.name}'.toLowerCase();
    return churches.any((ch) => ch.keywords.any(hay.contains));
  }

  late final List<Preacher> preachers = () {
    final list = <Preacher>[];
    for (final c in categories) {
      final slug = c.slug;
      if (!slug.startsWith('fs') || c.count < 5) continue;
      if (slug == 'fslastname' || c.name.contains('|') || _isChurch(c)) continue;
      final name = _preacherNames[slug] ??
          c.name
              .replaceFirst(RegExp(r'^Sermons\s+'), '')
              .replaceAll('_', ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
      list.add(Preacher(
        slug: slug,
        name: name,
        count: c.count,
        clipsSlug: _clipsFor[slug],
      ));
    }
    list.sort((a, b) => b.count.compareTo(a.count));
    return list;
  }();

  Preacher? preacher(String slug) {
    for (final p in preachers) {
      if (p.slug == slug) return p;
    }
    final c = find(slug);
    if (c == null) return null;
    return Preacher(slug: slug, name: _preacherNames[slug] ?? c.name, count: c.count, clipsSlug: _clipsFor[slug]);
  }

  /// Congregation categories (members' sermons, livestreams) for a church.
  List<Category> churchCategories(Church church) => [
        for (final c in categories)
          if (!c.slug.startsWith('pro') &&
              c.slug != church.pastorSlug &&
              church.keywords
                  .any('${c.slug} ${c.name}'.toLowerCase().contains))
            c,
      ];

  late final List<Conference> conferences = () {
    final list = <Conference>[
      for (final c in categories)
        if (_conference.hasMatch(c.slug))
          Conference(
            slug: c.slug,
            name: c.name.replaceFirst(RegExp(r'\s*\d{4}$'), ''),
            year: int.parse(c.slug.substring(c.slug.length - 4)),
            count: c.count,
          ),
    ];
    list.sort((a, b) => b.year != a.year ? b.year.compareTo(a.year) : a.name.compareTo(b.name));
    return list;
  }();
}

/// Removes duplicate uploads of the same title, keeping the richest copy
/// (has a thumbnail / runtime / is newer) and the highest view count.
List<Video> dedupe(Iterable<Video> videos) {
  final byKey = <String, Video>{};
  for (final v in videos) {
    final existing = byKey[v.dedupeKey];
    if (existing == null) {
      byKey[v.dedupeKey] = v;
      continue;
    }
    int score(Video x) =>
        (x.thumbUrl != null ? 2 : 0) + (x.runtimeMinutes != null ? 1 : 0);
    final keep = score(v) > score(existing) ? v : existing;
    final views = v.views > existing.views ? v.views : existing.views;
    byKey[v.dedupeKey] = Video(
      id: keep.id,
      title: keep.title,
      categorySlug: keep.categorySlug,
      categoryName: keep.categoryName,
      preacher: keep.preacher,
      date: keep.date ?? existing.date ?? v.date,
      mediaUrl: keep.mediaUrl,
      audioUrl: keep.audioUrl,
      rawThumbUrl: keep.rawThumbUrl,
      runtimeMinutes: keep.runtimeMinutes,
      views: views,
      language: keep.language,
      track: keep.track,
      season: keep.season,
      episode: keep.episode,
    );
  }
  return byKey.values.toList();
}

/// Genre shelves for the documentaries screen, matched on title keywords.
class DocGenre {
  const DocGenre(this.title, this.keywords);
  final String title;
  final List<String> keywords;

  bool matches(Video v) {
    final t = v.title.toLowerCase();
    return keywords.any(t.contains);
  }
}

const docGenres = <DocGenre>[
  DocGenre('Bible Prophecy & End Times', [
    'tribulation', 'antichrist', 'beast', 'new world order', 'transhumanism',
    'protocols', 'six pointed', 'israel',
  ]),
  DocGenre('Sound Doctrine', [
    'repent', 'faith alone', 'dispensation', 'scofield', 'calvinism',
    'preserved bible', 'greek', 'sacred name', 'eternal or not', 'oneness',
    'being baptist', 'thou shalt teach', 'failure to obey', 'science falsely',
  ]),
  DocGenre('Soulwinning & Missions', [
    'soulwinning', 'road trip', 'deported', 'man of god', 'sunlight',
  ]),
  DocGenre('False Religions Exposed', [
    'buddhism', 'hinduism', 'peyote', 'mormon', 'jehovah', 'athiest',
    'atheist', 'muertos', 'pope', 'halal', 'religion',
  ]),
  DocGenre('History & Nations', [
    'soviet', 'america', 'founding fathers', 'japan', 'france', 'iceland',
    'jfk', 'patriotism', 'holocaust', 'columbine', 'elberton', 'plaasmoorde',
    'fascism', 'giants',
  ]),
  DocGenre('Culture & Society', [
    'lgbt', 'sodomite', 'reprobate', 'birth control', 'censored', 'hate preacher',
    'spraying', 'covidland', 'water', 'gardening', 'lust', 'aids', 'sicko',
    'shadow ring', 'marxist', 'eviction', 'psychopath',
  ]),
];
