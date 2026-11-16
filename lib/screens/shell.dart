import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/mini_player.dart';
import 'docs_screen.dart';
import 'home_screen.dart';
import 'music_screen.dart';
import 'search_screen.dart';
import 'sermons_screen.dart';

class _TabSpec {
  const _TabSpec(this.label, this.icon, this.activeIcon, this.root);
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget root;
}

const _tabs = [
  _TabSpec('Home', Icons.home_outlined, Icons.home_rounded, HomeScreen()),
  _TabSpec('Sermons', Icons.mic_none_rounded, Icons.mic_rounded, SermonsScreen()),
  _TabSpec('Films', Icons.movie_outlined, Icons.movie_rounded, DocsScreen()),
  _TabSpec('Music', Icons.library_music_outlined, Icons.library_music_rounded, MusicScreen()),
  _TabSpec('Search', Icons.search_rounded, Icons.search_rounded, SearchScreen()),
];

/// App frame: one nested navigator per tab (so each tab keeps its own
/// history), the floating mini player, and a frosted bottom bar.
class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppNav.tab,
      builder: (context, index, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            final nav = AppNav.keys[index].currentState;
            if (nav != null && nav.canPop()) {
              nav.pop();
            } else if (index != AppNav.home) {
              AppNav.tab.value = AppNav.home;
            } else {
              SystemNavigator.pop();
            }
          },
          child: Scaffold(
            extendBody: true,
            body: IndexedStack(
              index: index,
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  HeroControllerScope.none(
                    child: Navigator(
                      key: AppNav.keys[i],
                      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => _tabs[i].root),
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayer(),
                _NavBar(index: index),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bg.withValues(alpha: 0.82),
            border: const Border(top: BorderSide(color: Color(0x14FFFFFF))),
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 62),
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: _NavItem(
                        spec: _tabs[i],
                        selected: i == index,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          AppNav.goTab(i);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.spec, required this.selected, required this.onTap});

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.text : AppColors.faint;
    return InkResponse(
      onTap: onTap,
      radius: 36,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? AppColors.gold.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(selected ? spec.activeIcon : spec.icon,
                color: selected ? AppColors.gold : color, size: 24),
          ),
          const SizedBox(height: 4),
          // One line, shrinking to fit narrow phones and large text sizes.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              spec.label,
              maxLines: 1,
              softWrap: false,
              textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
