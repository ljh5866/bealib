import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bealib/pages/home/home_page.dart';
import 'package:bealib/pages/settings/settings_hub_page.dart';
import 'package:bealib/utils/theme.dart';

/// Bealib 主导航壳。
///
/// 需求：「app 底部导航栏只有首页/设置」。视觉参照 `design/ui-reference.jpg`
/// 的悬浮胶囊导航：白色半透明胶囊 + 选中态内嵌胶囊。
///
/// 规范说明（AGENTS.md 偏离记录）：
/// - Material 3 R2.1 要求 NavigationBar 承载 3–5 个目的地，本应用按要求仅 2 个，
///   因此不使用 M3 NavigationBar，改为自绘胶囊导航；
/// - 自绘实现仍保证：标签常显（R2.2 意图）、选中态可辨识（R2.3 意图）、
///   单项触控高度 ≥48dp（R6.5）。
class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;

  static const _destinations = <_NavDestination>[
    _NavDestination(
      label: '首页',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavDestination(
      label: '设置',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool isDark = brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // 明暗主题下分别使用深/浅色系统栏图标，保证状态栏在渐变背景上可辨识
      // （WCAG 2.2 SC 1.4.11 非文本对比度 ≥ 3:1）。
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: DecoratedBox(
          decoration: BealibTokens.ambientBackground(brightness),
          child: Stack(
            children: [
              Positioned.fill(
                child: IndexedStack(
                  index: _index,
                  children: const [HomePage(), SettingsHubPage()],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _CapsuleNavBar(
                  destinations: _destinations,
                  selectedIndex: _index,
                  onSelected: (int index) {
                    if (index == _index) return;
                    setState(() => _index = index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _CapsuleNavBar extends StatelessWidget {
  const _CapsuleNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        BealibTokens.pagePadding,
        0,
        BealibTokens.pagePadding,
        bottomInset > 0 ? bottomInset + 8 : BealibTokens.navBarBottomInset,
      ),
      child: Container(
        height: BealibTokens.navBarHeight,
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (int i = 0; i < destinations.length; i++)
              Expanded(
                child: _NavBarItem(
                  destination: destinations[i],
                  selected: selectedIndex == i,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Color foreground =
        selected ? scheme.onSurface : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: onTap,
            child: AnimatedContainer(
              duration: BealibTokens.motionFast,
              curve: Curves.easeOutCubic,
              height: BealibTokens.minTouchTarget,
              decoration: BoxDecoration(
                color: selected ? scheme.surfaceContainerHigh : Colors.transparent,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    size: 22,
                    color: foreground,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    destination.label,
                    style: text.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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
