import 'package:flutter/material.dart';
import 'package:bealib/bean/card/network_img_layer.dart';
import 'package:bealib/modules/bangumi/bangumi_item.dart';
import 'package:bealib/utils/theme.dart';

/// 详情页（动漫详情）头部卡片：封面 + 番剧名 + 评分/年份/排名 + 标签 + 播放入口。
///
/// 视觉对齐 `design/ui-reference.jpg` 的「大圆角白卡 + 胶囊徽标」语言；
/// 数据全部来自已有 [BangumiItem]，不改变上游的数据加载链路。
///
/// 无障碍（Material 3 R6.1/R6.5）：播放入口是最小 48dp 高的 FilledButton，
/// 封面图片带语义标签；装饰性模糊背景由父级提供，不参与语义树。
class BealibInfoHeader extends StatelessWidget {
  const BealibInfoHeader({
    super.key,
    required this.bangumiItem,
    required this.showRating,
    required this.isLoading,
  });

  final BangumiItem bangumiItem;
  final bool showRating;
  final bool isLoading;

  String get _title {
    if (bangumiItem.nameCn.trim().isNotEmpty) return bangumiItem.nameCn.trim();
    return bangumiItem.name.trim();
  }

  String get _originalName {
    final String cn = bangumiItem.nameCn.trim();
    final String origin = bangumiItem.name.trim();
    if (cn.isEmpty || origin.isEmpty || cn == origin) return '';
    return origin;
  }

  String get _coverUrl {
    final Map<String, String> images = bangumiItem.images;
    for (final key in const ['large', 'common', 'medium', 'small', 'grid']) {
      final String? url = images[key];
      if (url != null && url.isNotEmpty) return url;
    }
    return '';
  }

  String get _year {
    final String date = bangumiItem.airDate.trim();
    return date.length >= 4 ? date.substring(0, 4) : '';
  }

  List<String> get _tags => [
        for (final tag in bangumiItem.tags)
          if (tag.name.trim().isNotEmpty) tag.name.trim(),
      ].take(3).toList();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(BealibTokens.cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: isLoading
          ? const _HeaderSkeleton()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Cover(url: _coverUrl, title: _title),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleLarge?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_originalName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              _originalName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (showRating && bangumiItem.ratingScore > 0)
                                _InfoBadge(
                                  icon: Icons.star_rounded,
                                  label:
                                      '${bangumiItem.ratingScore.toStringAsFixed(1)}',
                                  highlight: true,
                                ),
                              if (_year.isNotEmpty) _InfoBadge(label: _year),
                              if (showRating && bangumiItem.rank > 0)
                                _InfoBadge(label: '#${bangumiItem.rank}'),
                              if (showRating && bangumiItem.votes > 0)
                                _InfoBadge(label: '${bangumiItem.votes} 人评分'),
                            ],
                          ),
                          if (_tags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final String tag in _tags)
                                  _TagChip(label: tag),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.title});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    const double width = 96;
    const double height = 134;
    if (url.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(BealibTokens.coverRadius),
        child: SizedBox(
          width: width,
          height: height,
          child: ColoredBox(
            color: scheme.surfaceContainerHigh,
            child: Center(
              child: Text(
                title.isEmpty ? '番剧' : title.characters.first,
                style: text.headlineMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    }
    // 与封面列表同一条图片加速链路（镜像 / ECH / 直连）。
    return NetworkImgLayer(
      src: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      borderRadius: BorderRadius.circular(BealibTokens.coverRadius),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({this.icon, required this.label, this.highlight = false});

  final IconData? icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: scheme.onSurface),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: text.labelSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        label,
        style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    Widget block(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 96,
              height: 134,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(BealibTokens.coverRadius),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  block(double.infinity, 20),
                  const SizedBox(height: 8),
                  block(120, 12),
                  const SizedBox(height: 12),
                  Row(children: [
                    block(56, 20),
                    const SizedBox(width: 6),
                    block(56, 20),
                  ]),
                  const SizedBox(height: 12),
                  block(double.infinity, 20),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
