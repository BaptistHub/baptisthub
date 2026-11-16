import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../core/theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.onSeeAll, this.padding});

  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 28, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleLarge?.copyWith(fontSize: 19)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: t.bodySmall?.copyWith(color: AppColors.muted)),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.muted,
                visualDensity: VisualDensity.compact,
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('See all', style: TextStyle(fontWeight: FontWeight.w600)),
                Icon(Icons.chevron_right_rounded, size: 18),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Horizontally scrolling shelf.
class Shelf extends StatelessWidget {
  const Shelf({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 12,
  });

  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, __) => SizedBox(width: spacing),
        itemBuilder: itemBuilder,
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height, this.radius = 12, this.circle = false});

  final double? width;
  final double? height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

class Shimmering extends StatelessWidget {
  const Shimmering({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: AppColors.surfaceHigh,
        highlightColor: const Color(0xFF2A2A33),
        period: const Duration(milliseconds: 1400),
        child: child,
      );
}

/// A loading shelf of placeholder cards.
class ShelfSkeleton extends StatelessWidget {
  const ShelfSkeleton({super.key, required this.width, required this.height, this.circle = false, this.textLines = 2});

  final double width;
  final double height;
  final bool circle;
  final int textLines;

  @override
  Widget build(BuildContext context) {
    return Shimmering(
      child: SizedBox(
        height: height + textLines * 18 + 8,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) => Column(
            crossAxisAlignment: circle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: width, height: height, circle: circle),
              for (var i = 0; i < textLines; i++) ...[
                const SizedBox(height: 8),
                SkeletonBox(width: width * (i == 0 ? 0.85 : 0.5), height: 10, radius: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 8});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmering(
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(children: [
                SkeletonBox(width: 136, height: 77),
                SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SkeletonBox(height: 12, radius: 4),
                    SizedBox(height: 8),
                    SkeletonBox(width: 140, height: 12, radius: 4),
                    SizedBox(height: 14),
                    SkeletonBox(width: 90, height: 10, radius: 4),
                  ]),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry, this.compact = false});

  final String message;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact) ...[
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: AppColors.surfaceHigh, shape: BoxShape.circle),
            child: const Icon(Icons.wifi_off_rounded, color: AppColors.muted, size: 28),
          ),
          const SizedBox(height: 16),
        ],
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Try again'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.text,
            side: const BorderSide(color: AppColors.stroke),
            shape: const StadiumBorder(),
          ),
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: compact ? 16 : 48),
      child: Center(child: content),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AppColors.faint),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

/// Builds async content with consistent loading and error states and a
/// retry that re-runs [future].
class AsyncBuilder<T> extends StatefulWidget {
  const AsyncBuilder({
    super.key,
    required this.future,
    required this.builder,
    required this.loading,
    this.compactError = true,
    this.hideOnError = false,
  });

  final Future<T> Function() future;
  final Widget Function(BuildContext context, T data) builder;
  final Widget loading;
  final bool compactError;
  final bool hideOnError;

  @override
  State<AsyncBuilder<T>> createState() => _AsyncBuilderState<T>();
}

class _AsyncBuilderState<T> extends State<AsyncBuilder<T>> {
  late Future<T> _f = widget.future();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _f,
      builder: (context, snap) {
        if (snap.hasError) {
          if (widget.hideOnError) return const SizedBox.shrink();
          return ErrorRetry(
            message: '${snap.error}',
            compact: widget.compactError,
            onRetry: () => setState(() => _f = widget.future()),
          );
        }
        if (!snap.hasData) return widget.loading;
        return widget.builder(context, snap.data as T);
      },
    );
  }
}

/// Pill-shaped primary/secondary buttons used on hero sections.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = true,
    this.expand = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      backgroundColor: primary ? Colors.white : Colors.white.withValues(alpha: 0.16),
      foregroundColor: primary ? Colors.black : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: AppFonts.inter(const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      minimumSize: expand ? const Size.fromHeight(46) : null,
    );
    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: 22),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false),
    );
  }
}

class Badge2 extends StatelessWidget {
  const Badge2(this.text, {super.key, this.color = const Color(0xCC000000), this.textColor = Colors.white});

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
        child: Text(text,
            style: TextStyle(
                color: textColor, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
      );
}

void showToast(BuildContext context, String message, {IconData? icon}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(children: [
        if (icon != null) ...[Icon(icon, color: AppColors.gold, size: 20), const SizedBox(width: 10)],
        Expanded(child: Text(message)),
      ]),
    ));
}
