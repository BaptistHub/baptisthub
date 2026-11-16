import 'package:flutter/material.dart';

import '../core/audio_controller.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import 'art.dart';

/// Floating "now playing" bar shown above the bottom navigation.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = AudioController.instance;
    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        final v = audio.current;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, a) => SizeTransition(
            sizeFactor: a,
            axisAlignment: 1,
            child: FadeTransition(opacity: a, child: child),
          ),
          child: v == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  key: const ValueKey('mini'),
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                  child: Material(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => AppNav.openNowPlaying(context),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 4, 6),
                            child: Row(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox.square(
                                  dimension: 42,
                                  child: SmartImage(
                                    url: v.thumbUrl,
                                    cacheWidth: 84,
                                    fallback: GeneratedArt(
                                      seed: audio.artSeed ?? v.categorySlug,
                                      style: ArtStyle.album,
                                      icon: Icons.music_note_rounded,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(v.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(
                                      audio.error ?? audio.queueTitle ?? v.byline,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: audio.error != null ? const Color(0xFFFF8A80) : AppColors.muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (audio.isLoading)
                                const Padding(
                                  padding: EdgeInsets.all(13),
                                  child: SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.text),
                                  ),
                                )
                              else
                                IconButton(
                                  onPressed: audio.toggle,
                                  icon: Icon(audio.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30),
                                ),
                              IconButton(
                                onPressed: audio.hasNext ? audio.next : audio.stop,
                                icon: Icon(audio.hasNext ? Icons.skip_next_rounded : Icons.close_rounded,
                                    color: AppColors.muted),
                              ),
                            ]),
                          ),
                          StreamBuilder<Duration>(
                            stream: audio.player.positionStream,
                            builder: (_, snap) {
                              final dur = audio.player.duration ?? Duration.zero;
                              final pos = snap.data ?? Duration.zero;
                              final p = dur.inMilliseconds <= 0
                                  ? 0.0
                                  : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
                              return LinearProgressIndicator(
                                value: p,
                                minHeight: 2,
                                backgroundColor: Colors.white10,
                                color: AppColors.gold,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
