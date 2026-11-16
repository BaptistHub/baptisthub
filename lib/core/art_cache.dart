import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../widgets/art.dart';

/// Writes generated album art to PNG files once per album, so the lock
/// screen / media notification can show the same artwork as the app.
class ArtCache {
  ArtCache._();

  static final Map<String, Future<Uri?>> _files = {};

  static Future<Uri?> uriFor(String seed, {String? title, String? label}) {
    if (kIsWeb) return Future.value(null);
    final key = '$seed|$title|$label';
    return _files[key] ??= () async {
      try {
        final dir = Directory('${(await getTemporaryDirectory()).path}/art');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        final file = File('${dir.path}/${key.hashCode.toUnsigned(32)}.png');
        if (!file.existsSync()) {
          await file.writeAsBytes(await renderArtPng(seed, title: title, label: label));
        }
        return file.uri;
      } catch (e) {
        debugPrint('Art cache failed: $e');
        _files.remove(key);
        return null;
      }
    }();
  }
}
