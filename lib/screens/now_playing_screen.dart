import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../core/audio_controller.dart';
import '../core/downloads.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/art.dart';
import '../widgets/cards.dart';
import '../widgets/download_ui.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = AudioController.instance;
    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        final v = audio.current;
        if (v == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
          return const Scaffold();
        }
        final seed = audio.artSeed ?? v.categorySlug;
        final tint = accentFor(seed);

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tint.withValues(alpha: 0.45), AppColors.bg, AppColors.bg],
                stops: const [0, 0.6, 1],
              ),
            ),
            child: SafeArea(
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                    ),
                    Expanded(
                      child: Column(children: [
                        Text('PLAYING FROM', style: AppText.eyebrow(color: Colors.white60)),
                        const SizedBox(height: 2),
                        Text(audio.queueTitle ?? v.byline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ]),
                    ),
                    ListenableBuilder(
                      listenable: DownloadManager.instance,
                      builder: (context, _) {
                        final saved = DownloadManager.instance.hasAnyDownload(v.id);
                        return IconButton(
                          tooltip: saved ? 'Downloaded' : 'Download',
                          onPressed: () => saved ? showDownloadSheet(context, v) : quickDownload(context, v),
                          icon: Icon(saved ? Icons.download_done_rounded : Icons.download_rounded,
                              color: saved ? AppColors.gold : null),
                        );
                      },
                    ),
                    IconButton(
                      onPressed: () => _showQueue(context),
                      icon: const Icon(Icons.queue_music_rounded),
                    ),
                  ]),
                ),
                // Artwork takes whatever height is left, so the controls
                // always fit on short screens and with large text.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 380),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: AnimatedScale(
                            scale: audio.isPlaying ? 1 : 0.88,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutBack,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40, offset: const Offset(0, 20))],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: SmartImage(
                                  url: v.thumbUrl,
                                  cacheWidth: 400,
                                  fallback: GeneratedArt(seed: seed, style: ArtStyle.album, title: audio.queueTitle, icon: Icons.music_note_rounded),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(v.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                    const SizedBox(height: 4),
                    Text(audio.error ?? (v.isAudioOnly ? (audio.queueTitle ?? v.byline) : v.byline),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: audio.error != null ? const Color(0xFFFF8A80) : AppColors.muted)),
                    const SizedBox(height: 14),
                    _SeekBar(player: audio.player),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      StreamBuilder<bool>(
                        stream: audio.player.shuffleModeEnabledStream,
                        builder: (_, s) => IconButton(
                          onPressed: () => audio.player.setShuffleModeEnabled(!(s.data ?? false)),
                          icon: Icon(Icons.shuffle_rounded, color: (s.data ?? false) ? AppColors.gold : AppColors.muted),
                        ),
                      ),
                      IconButton(
                        iconSize: 40,
                        onPressed: audio.previous,
                        icon: const Icon(Icons.skip_previous_rounded),
                      ),
                      _BigPlayButton(audio: audio),
                      IconButton(
                        iconSize: 40,
                        onPressed: audio.hasNext ? audio.next : null,
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                      StreamBuilder<LoopMode>(
                        stream: audio.player.loopModeStream,
                        builder: (_, s) {
                          final mode = s.data ?? LoopMode.off;
                          return IconButton(
                            onPressed: () => audio.player.setLoopMode(
                              mode == LoopMode.off ? LoopMode.all : mode == LoopMode.all ? LoopMode.one : LoopMode.off,
                            ),
                            icon: Icon(
                              mode == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                              color: mode == LoopMode.off ? AppColors.muted : AppColors.gold,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  void _showQueue(BuildContext context) {
    final audio = AudioController.instance;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (ctx, scroll) => ListenableBuilder(
          listenable: audio,
          builder: (ctx, _) => ListView.builder(
            controller: scroll,
            itemCount: audio.queue.length + 1,
            itemBuilder: (ctx, i) {
              if (i == 0) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text('Up next', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                );
              }
              final v = audio.queue[i - 1];
              return TrackTile(video: v, number: i, onTap: () => audio.jumpTo(i - 1));
            },
          ),
        ),
      ),
    );
  }
}

class _BigPlayButton extends StatelessWidget {
  const _BigPlayButton({required this.audio});
  final AudioController audio;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 74,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: audio.toggle,
          child: Center(
            child: audio.isLoading
                ? const SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                : Icon(audio.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.black, size: 42),
          ),
        ),
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.player});
  final AudioPlayer player;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    return StreamBuilder<Duration>(
      stream: p.positionStream,
      builder: (context, snap) {
        final dur = p.duration ?? Duration.zero;
        final pos = snap.data ?? Duration.zero;
        final max = dur.inMilliseconds.toDouble();
        final value = (_drag ?? pos.inMilliseconds.toDouble()).clamp(0.0, max <= 0 ? 1.0 : max);
        return Column(children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              trackShape: const RoundedRectSliderTrackShape(),
              activeTrackColor: Colors.white,
              thumbColor: Colors.white,
            ),
            child: Slider(
              min: 0,
              max: max <= 0 ? 1 : max,
              value: value,
              onChanged: max <= 0 ? null : (v) => setState(() => _drag = v),
              onChangeEnd: (v) {
                p.seek(Duration(milliseconds: v.round()));
                setState(() => _drag = null);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(children: [
              Text(formatClock(Duration(milliseconds: value.round())), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              const Spacer(),
              Text(formatClock(dur), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
          ),
        ]);
      },
    );
  }
}
