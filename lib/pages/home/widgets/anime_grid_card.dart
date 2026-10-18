import 'package:flutter/material.dart';
import 'package:bealib/bean/card/network_img_layer.dart';
import 'package:bealib/modules/bangumi/bangumi_item.dart';
import 'package:bealib/utils/theme.dart';

/// 番剧网格卡片（视觉对齐 `design/ui-reference.jpg`）。
///
/// 结构：白卡（圆角 20）→ 3:4 封面（圆角 14）+ 角标 → 标题 2 行 → 元信息 1 行。
/// 角标沿用参考图的「胶囊 + 半透明黑底白字」，左上放评分、右上放首个标签。
class AnimeGridCard extends StatelessWidget {
  const AnimeGridCard({super.key, required this.item, required this.onTap});

  final BangumiItem item;
  final VoidCallback onTap;

  String get _coverUrl {
    final Map<String, String> images = item.images;
    for (final key in const ['large', 'common', 'medium', 'small', 'grid']) {
      final String? url = images[key];
      if (url != null && url.isNotEmpty) return url;
    }
    return '';
  }

  String get _title {
    if (item.nameCn.trim().isNotEmpty) return item.nameCn.trim();
    return item.name.trim();
  }

  String get _year {
    final String date = item.airDate.trim();
    if (date.length >= 4) return date.substring(0, 4);
    return '';
  }

  String? get _tag {
    if (item.tags.isEmpty) return null;
    final String name = item.tags.first.name.trim();
    return name.isEmpty ? null : name;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    // 角标左侧已有星形 icon，文本只保留数值，避免出现两个星号。
    final String rating =
        item.ratingScore > 0 ? item.ratingScore.toStringAsFixed(1) : '';
    final String meta = [
      if (_year.isNotEmpty) _year,
      if (rating.isEmpty) '暂无评分' else '$rating 分',
    ].join(' · ');
    final String tag = _tag ?? '番剧';

    return Semantics(
      button: true,
      label: '$_title，$meta，标签 $tag',
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(BealibTokens.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(BealibTokens.coverRadius),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _CoverImage(url: _coverUrl, title: _title),
                        Positioned(
                          left: 8,
                          top: 8,
                          child: _Badge(
                            icon: Icons.star_rounded,
                            text: rating.isEmpty ? '暂无评分' : rating,
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: _Badge(text: tag),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(
                    color: scheme.onSurface,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url, required this.title});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _CoverFallback(title: title);
    }
    // 走 NetworkImgLayer：内部用 CachedNetworkImage + 代理感知缓存管理器，
    // 在「镜像 / ECH / 直连」三种图片加速模式下都能正常加载（上游同款链路）。
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width / 2;
        final double height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : width * 4 / 3;
        return NetworkImgLayer(
          src: url,
          width: width,
          height: height,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          borderRadius: BorderRadius.circular(BealibTokens.coverRadius),
        );
      },
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: Center(
        child: Text(
          title.isEmpty ? '番剧' : title.characters.first,
          style: text.displayMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({this.icon, required this.text});

  final IconData? icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
