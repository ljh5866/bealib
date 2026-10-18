import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:bealib/modules/bangumi/bangumi_item.dart';
import 'package:bealib/pages/home/widgets/anime_grid_card.dart';
import 'package:bealib/request/apis/bangumi_api.dart';
import 'package:bealib/services/network/bangumi_acceleration.dart';
import 'package:bealib/utils/theme.dart';

/// 首页：软件名 + 搜索栏 + 推荐番剧。
///
/// 数据：Bangumi 趋势榜（镜像/直连按用户「网络设置」自动选择，失败自动换源一次）。
/// 视觉：`design/ui-reference.jpg` —— 大字标题、圆角搜索框、2 列白色卡片网格。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const int _pageSize = 12;

  final List<BangumiItem> _items = <BangumiItem>[];
  bool _loading = true;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// 推荐数据源：镜像服务在国内网络下延迟抖动较大（实测 3s–45s），
  /// 因此这里单独放宽接收超时，并在失败时自动重试一次、再换源兜底。
  static const Duration _receiveTimeout = Duration(seconds: 20);

  Future<List<BangumiItem>> _fetch({required int limit, required int offset}) async {
    final bool useMirror =
        BangumiAcceleration.current == BangumiAcceleration.mirror;

    Future<List<BangumiItem>> queryMirror() =>
        BangumiApi.getBangumiMirrorPopularSubjects(
          limit: limit,
          offset: offset,
          receiveTimeout: _receiveTimeout,
        );
    Future<List<BangumiItem>> queryDirect() => BangumiApi.getBangumiTrendsList(
          limit: limit,
          offset: offset,
          receiveTimeout: _receiveTimeout,
        );

    List<BangumiItem> list =
        useMirror ? await queryMirror() : await queryDirect();
    if (list.isNotEmpty) return list;

    // 失败重试一次（抖动多为单次慢响应）。
    await Future<void>.delayed(const Duration(milliseconds: 600));
    list = useMirror ? await queryMirror() : await queryDirect();
    if (list.isNotEmpty) return list;

    // 仍失败则换源兜底。
    return useMirror ? await queryDirect() : await queryMirror();
  }

  Future<void> _load({bool shuffle = false}) async {
    if (mounted) setState(() => _loading = true);
    if (shuffle) {
      _offset = (_offset + _pageSize) % 96;
    }
    // 首屏先用上次成功的缓存秒开，再走网络刷新（镜像延迟抖动大）。
    if (_items.isEmpty) {
      final cached = await BangumiApi.getBangumiMirrorPopularSubjects(
        limit: _pageSize,
        offset: _offset,
        allowStale: true,
      );
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _items
            ..clear()
            ..addAll(cached);
          _loading = false;
        });
      }
    }
    final List<BangumiItem> result = await _fetch(
      limit: _pageSize,
      offset: _offset,
    );
    if (!mounted) return;
    setState(() {
      if (result.isNotEmpty) {
        _items
          ..clear()
          ..addAll(result);
      }
      _loading = false;
    });
  }

  void _openSearch() {
    context.pushNamed('/search/');
  }

  void _openBangumi(BangumiItem item) {
    context.pushNamed('/info/', arguments: item);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextTheme text = theme.textTheme;
    final double width = MediaQuery.sizeOf(context).width;
    final double topInset = MediaQuery.viewPaddingOf(context).top;
    final int columns = width >= 600 ? 3 : 2;
    final double gridItemWidth =
        (width - BealibTokens.pagePadding * 2 - BealibTokens.gridGap * (columns - 1)) /
            columns;
    // 卡片高度 = 3:4 封面 + 标题 2 行 + 元信息（约 76dp）
    final double cardHeight = gridItemWidth * 4 / 3 + 78;
    final double childAspectRatio = gridItemWidth / cardHeight;

    return RefreshIndicator(
      onRefresh: _load,
      color: scheme.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                BealibTokens.pagePadding,
                topInset + 14,
                BealibTokens.pagePadding,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/images/logo/logo_rounded.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bealib',
                          style: text.displayLarge?.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          _loading ? '正在为你挑选番剧…' : '番剧推荐 · 每日更新',
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                BealibTokens.pagePadding,
                18,
                BealibTokens.pagePadding,
                0,
              ),
              child: _SearchEntry(onTap: _openSearch),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                BealibTokens.pagePadding,
                22,
                BealibTokens.pagePadding,
                12,
              ),
              child: Row(
                children: [
                  Text(
                    '推荐番剧',
                    style: text.headlineSmall?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_loading)
                    Text(
                      '${_items.length} 部',
                      style: text.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_loading)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: BealibTokens.pagePadding,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: BealibTokens.gridGap,
                  mainAxisSpacing: 14,
                  childAspectRatio: childAspectRatio,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => const _SkeletonCard(),
                  childCount: columns * 2,
                ),
              ),
            )
          else if (_items.isEmpty)
            SliverToBoxAdapter(child: _EmptyRecommend(onRetry: _load))
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: BealibTokens.pagePadding,
              ),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: BealibTokens.gridGap,
                  mainAxisSpacing: 14,
                  childAspectRatio: childAspectRatio,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final BangumiItem item = _items[index];
                    return AnimeGridCard(
                      item: item,
                      onTap: () => _openBangumi(item),
                    );
                  },
                  childCount: _items.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 128)),
        ],
      ),
    );
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '搜索番剧、角色或标签',
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(BealibTokens.inputRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Text(
                  '搜索番剧、角色或标签',
                  style: text.bodyMedium?.copyWith(
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

class _EmptyRecommend extends StatelessWidget {
  const _EmptyRecommend({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BealibTokens.pagePadding,
        24,
        BealibTokens.pagePadding,
        24,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(BealibTokens.cardRadius),
        ),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              '暂时没有拿到推荐',
              style: text.titleMedium?.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              '请检查网络，或在「设置 → 网络设置」中切换加速方式。',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => onRetry(),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(BealibTokens.cardRadius),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(BealibTokens.coverRadius),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 12,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 8),
          FractionallySizedBox(
            widthFactor: 0.5,
            alignment: Alignment.centerLeft,
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
