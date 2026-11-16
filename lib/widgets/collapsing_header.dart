import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Image header that collapses into a toolbar.
///
/// Expanded: a large title block aligned to the page's 20px content margin.
/// Collapsed: a compact title beside the back button. (FlexibleSpaceBar's
/// built-in title shifts sideways as it scales, which misaligns it with the
/// content below.)
class CollapsingHeader extends StatelessWidget {
  const CollapsingHeader({
    super.key,
    required this.title,
    required this.background,
    this.collapsedTitle,
    this.subtitle,
    this.icon,
    this.expandedHeight = 250,
    this.bottom,
  });

  final String title;
  final String? collapsedTitle;
  final String? subtitle;
  final IconData? icon;
  final Widget background;
  final double expandedHeight;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      backgroundColor: AppColors.bg,
      bottom: bottom,
      flexibleSpace: LayoutBuilder(builder: (context, box) {
        final top = MediaQuery.paddingOf(context).top;
        final minH = kToolbarHeight + top + bottomHeight;
        final maxH = expandedHeight + top;
        // 1 = fully expanded, 0 = collapsed.
        final t = ((box.maxHeight - minH) / (maxH - minH)).clamp(0.0, 1.0);
        final expandedOpacity = Curves.easeIn.transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));
        final collapsedOpacity = (1 - t / 0.35).clamp(0.0, 1.0);

        return Stack(fit: StackFit.expand, children: [
          Opacity(opacity: t, child: background),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.4, 1],
                colors: [Color(0x80000000), Color(0x1A000000), AppColors.bg],
              ),
            ),
          ),
          // Expanded title block, on the same 20px margin as the content.
          Positioned(
            left: 20,
            right: 20,
            bottom: 16 + bottomHeight,
            child: IgnorePointer(
              child: Opacity(
                opacity: expandedOpacity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          if (icon != null) ...[
                            Icon(icon, size: 15, color: AppColors.gold),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ]),
                      ),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -0.6,
                        shadows: [Shadow(blurRadius: 12, color: Colors.black54)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Collapsed toolbar title, next to the back button.
          Positioned(
            top: top,
            left: 56,
            right: 16,
            height: kToolbarHeight,
            child: IgnorePointer(
              child: Opacity(
                opacity: collapsedOpacity,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    collapsedTitle ?? title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}
