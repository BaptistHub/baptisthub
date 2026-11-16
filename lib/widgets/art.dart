import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/catalog.dart';
import '../core/theme.dart';

/// Curated cinematic duotones for generated artwork.
const _palettes = <List<Color>>[
  [Color(0xFF071318), Color(0xFF16404A), Color(0xFF3FA7A0)], // deep teal
  [Color(0xFF160707), Color(0xFF5A1712), Color(0xFFE0582F)], // ember
  [Color(0xFF0A0A1C), Color(0xFF29205E), Color(0xFF8A6BE0)], // violet night
  [Color(0xFF0C140B), Color(0xFF2B3B1B), Color(0xFFD4A63F)], // olive gold
  [Color(0xFF130C06), Color(0xFF4D2C10), Color(0xFFF0A93C)], // amber
  [Color(0xFF060F1C), Color(0xFF12365C), Color(0xFF4E95D9)], // ocean
  [Color(0xFF170812), Color(0xFF581A3F), Color(0xFFDB5A86)], // wine
  [Color(0xFF0E0E10), Color(0xFF2E2E34), Color(0xFFB9B9C2)], // silver
  [Color(0xFF051410), Color(0xFF0E4434), Color(0xFF39C48D)], // emerald
  [Color(0xFF1A0E05), Color(0xFF6B3410), Color(0xFFFFC46B)], // sunrise
];

int _hash(String s) {
  var h = 0x811C9DC5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0x7FFFFFFF;
  }
  return h;
}

List<Color> paletteFor(String seed) => _palettes[_hash(seed) % _palettes.length];

Color accentFor(String seed) => paletteFor(seed)[2];

enum ArtStyle { poster, wide, album, avatar }

/// Deterministic generated artwork used wherever the site has no image —
/// documentary posters, album covers, church cards and preacher avatars.
class GeneratedArt extends StatelessWidget {
  const GeneratedArt({
    super.key,
    required this.seed,
    this.style = ArtStyle.wide,
    this.title,
    this.label,
    this.icon,
    this.initials,
  });

  final String seed;
  final ArtStyle style;
  final String? title;
  final String? label;
  final IconData? icon;
  final String? initials;

  @override
  Widget build(BuildContext context) {
    final colors = paletteFor(seed);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ArtPainter(colors, _hash(seed), style),
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth.isFinite ? c.maxWidth : 200.0;
          switch (style) {
            case ArtStyle.avatar:
              return Center(
                child: Text(
                  initials ?? '',
                  style: AppFonts.inter(TextStyle(
                    fontSize: w * 0.34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.92),
                    letterSpacing: -0.5,
                  )),
                ),
              );
            case ArtStyle.album:
              return Padding(
                padding: EdgeInsets.all(w * 0.09),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null)
                      Icon(icon, size: w * 0.14, color: Colors.white.withValues(alpha: 0.9)),
                    const Spacer(),
                    if (title != null)
                      Text(
                        title!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.inter(TextStyle(
                          fontSize: (w * 0.12).clamp(11, 30),
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          letterSpacing: -0.4,
                          color: Colors.white,
                        )),
                      ),
                    if (label != null) ...[
                      SizedBox(height: w * 0.02),
                      Text(
                        label!.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.eyebrow(color: Colors.white70)
                            .copyWith(fontSize: (w * 0.05).clamp(8, 12)),
                      ),
                    ],
                  ],
                ),
              );
            case ArtStyle.poster:
            case ArtStyle.wide:
              final poster = style == ArtStyle.poster;
              return Padding(
                padding: EdgeInsets.fromLTRB(w * 0.08, w * 0.08, w * 0.08, w * (poster ? 0.1 : 0.06)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (icon != null && !poster) ...[
                      Icon(icon, color: Colors.white70, size: w * 0.09),
                      const Spacer(),
                    ],
                    if (label != null)
                      Row(children: [
                        Container(width: 3, height: 10, color: AppColors.gold),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(label!.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.eyebrow(color: Colors.white70)
                                  .copyWith(fontSize: (w * (poster ? 0.065 : 0.04)).clamp(7, 11))),
                        ),
                      ]),
                    if (title != null) ...[
                      SizedBox(height: w * 0.03),
                      Text(
                        title!.toUpperCase(),
                        maxLines: poster ? 4 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.display(
                          (w * (poster ? 0.17 : 0.085)).clamp(12, 64),
                        ).copyWith(shadows: const [
                          Shadow(blurRadius: 12, color: Colors.black54),
                        ]),
                      ),
                    ],
                  ],
                ),
              );
          }
        }),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.colors, this.seed, this.style);
  final List<Color> colors;
  final int seed;
  final ArtStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.clipRect(rect);
    final rnd = math.Random(seed);
    final maxDim = math.max(size.width, size.height);

    // Base gradient.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors[1], colors[0]],
        ).createShader(rect),
    );

    // Soft glow.
    final glow = Offset(
      size.width * (0.2 + rnd.nextDouble() * 0.6),
      size.height * (0.1 + rnd.nextDouble() * 0.4),
    );
    canvas.drawCircle(
      glow,
      maxDim * 0.75,
      Paint()
        ..shader = RadialGradient(colors: [
          colors[2].withValues(alpha: 0.55),
          colors[2].withValues(alpha: 0.0),
        ]).createShader(Rect.fromCircle(center: glow, radius: maxDim * 0.75)),
    );

    if (style == ArtStyle.album) {
      // Vinyl-like rings.
      final c = Offset(size.width * 0.95, size.height * 0.15);
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.08);
      for (var r = maxDim * 0.15; r < maxDim * 1.1; r += maxDim * 0.07) {
        canvas.drawCircle(c, r, ring);
      }
    } else if (style != ArtStyle.avatar) {
      // Light beams falling from above.
      canvas.save();
      canvas.translate(size.width * (0.3 + rnd.nextDouble() * 0.5), -size.height * 0.1);
      canvas.rotate(0.35 + rnd.nextDouble() * 0.3);
      for (var i = 0; i < 3; i++) {
        final w = maxDim * (0.06 + rnd.nextDouble() * 0.12);
        final x = (i - 1) * maxDim * 0.18;
        final beam = Rect.fromLTWH(x, 0, w, maxDim * 1.6);
        canvas.drawRect(
          beam,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.10 + rnd.nextDouble() * 0.06),
                Colors.white.withValues(alpha: 0.0),
              ],
            ).createShader(beam),
        );
      }
      canvas.restore();
    }

    // Film grain.
    final grain = Paint()..color = Colors.white.withValues(alpha: 0.035);
    final dots = (size.width * size.height / 120).clamp(60, 900).toInt();
    for (var i = 0; i < dots; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        rnd.nextDouble() * 0.9 + 0.2,
        grain,
      );
    }

    // Bottom scrim for title legibility.
    if (style == ArtStyle.poster || style == ArtStyle.wide || style == ArtStyle.album) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.35, 1],
            colors: [Color(0x00000000), Color(0xB3000000)],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_ArtPainter old) =>
      old.seed != seed || old.style != style || old.colors != colors;
}

/// Renders the album-style generated artwork to PNG bytes, for places that
/// need an image file (the lock screen / media notification).
Future<Uint8List> renderArtPng(String seed, {String? title, String? label, int size = 512}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = Size(size.toDouble(), size.toDouble());
  _ArtPainter(paletteFor(seed), _hash(seed), ArtStyle.album).paint(canvas, s);

  final pad = size * 0.09;
  var bottom = size - pad;
  if (label != null) {
    final lp = TextPainter(
      text: TextSpan(
        text: label.toUpperCase(),
        style: AppFonts.inter(TextStyle(
          fontSize: size * 0.045,
          fontWeight: FontWeight.w700,
          letterSpacing: size * 0.006,
          color: Colors.white70,
        )),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: size - pad * 2);
    bottom -= lp.height;
    lp.paint(canvas, Offset(pad, bottom));
    bottom -= size * 0.02;
  }
  if (title != null) {
    final tp = TextPainter(
      text: TextSpan(
        text: title,
        style: AppFonts.inter(TextStyle(
          fontSize: size * 0.11,
          fontWeight: FontWeight.w800,
          height: 1.05,
          letterSpacing: -size * 0.002,
          color: Colors.white,
        )),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: size - pad * 2);
    bottom -= tp.height;
    tp.paint(canvas, Offset(pad, bottom));
  }

  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Network image that falls back to [fallback] while loading or on error.
class SmartImage extends StatelessWidget {
  const SmartImage({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth,
  });

  final String? url;
  final Widget fallback;
  final BoxFit fit;
  final Alignment alignment;
  final int? cacheWidth;

  /// Tests turn this off to avoid the image cache's platform plugins.
  static bool enabled = true;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (!enabled || u == null || u.isEmpty) return fallback;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return CachedNetworkImage(
      imageUrl: u,
      fit: fit,
      alignment: alignment,
      memCacheWidth: cacheWidth == null ? null : (cacheWidth! * dpr).round(),
      fadeInDuration: const Duration(milliseconds: 250),
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

/// Circular preacher avatar: a monogram on the preacher's own gradient.
/// (The site has no preacher portraits, and sermon stills are often title
/// graphics, so a consistent monogram reads better.)
class PreacherAvatar extends StatelessWidget {
  const PreacherAvatar({super.key, required this.preacher, this.size = 72, this.ring = true});

  final Preacher preacher;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final p = preacher;
    final avatar = ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: GeneratedArt(seed: p.slug, style: ArtStyle.avatar, initials: p.initials),
      ),
    );
    if (!ring) return avatar;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [
          AppColors.gold,
          Color(0xFFFFE2A1),
          AppColors.goldDeep,
          AppColors.gold,
        ]),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.bg),
        child: avatar,
      ),
    );
  }
}
