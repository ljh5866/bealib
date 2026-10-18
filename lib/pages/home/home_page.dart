import 'dart:async';
import 'dart:math';

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
  static const Duration _receiveTimeout = Duration(seconds: 8);
  static const double _loadMoreThreshold = 480;

  final List<BangumiItem> _items = <BangumiItem>[];
  final Set<int> _itemIds = <int>{};
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();

  /// 下拉刷新时在 0–7 页范围内随机换一页，让推荐内容变化。
  static const int _refreshPageSpan = 8;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _loadMoreFailed = false;
  int _offset = 0;
  int _generation = 0;

  // 下一页预取缓存：首屏加载后顺手取下一页，下滑加载基本秒出。
  int? _prefetchedOffset;
  List<BangumiItem> _prefetchedItems = const <BangumiItem>[];
  bool _prefetching = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 推荐数据源：镜像服务在国内网络下延迟抖动较大（实测 3s–45s）。
  /// 这里让首选源与备选源并发竞速：首选源 0.9s 内没结果就同时跑备选源，
  /// 谁先返回非空列表就用谁，避免串行重试把首屏拖到几十秒。
  Future<List<BangumiItem>> _fetch({
    required int limit,
    required int offset,
  }) async {
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

    final Stopwatch stopwatch = Stopwatch()..start();
    final Future<List<BangumiItem>> preferred =
        useMirror ? queryMirror() : queryDirect();
    final Future<List<BangumiItem>> backup = Future<void>.delayed(
      const Duration(milliseconds: 900),
    ).then((_) => useMirror ? queryDirect() : queryMirror());

    final List<BangumiItem> result =
        await _firstNonEmpty(<Future<List<BangumiItem>>>[preferred, backup]);
    if (result.isNotEmpty) return result;

    // 两个源都失败且耗时很短（多为瞬时错误），再并发重试一次；耗时已长就不再拖。
    if (stopwatch.elapsed < const Duration(seconds: 4)) {
      return _firstNonEmpty(<Future<List<BangumiItem>>>[
        queryMirror(),
        queryDirect(),
      ]);
    }
    return const <BangumiItem>[];
  }

  /// 返回第一个非空结果；全部为空/失败时返回空列表。
  static Future<List<BangumiItem>> _firstNonEmpty(
    List<Future<List<BangumiItem>>> futures,
  ) {
    final Completer<List<BangumiItem>> completer =
        Completer<List<BangumiItem>>();
    int pending = futures.length;
    bool settled = false;

    void finish(List<BangumiItem> value) {
      if (settled) return;
      settled = true;
      completer.complete(value);
    }

    for (final Future<List<BangumiItem>> future in futures) {
      future.then((List<BangumiItem> list) {
        if (settled) return;
        if (list.isNotEmpty) {
          finish(list);
          return;
        }
        pending--;
        if (pending == 0) finish(const <BangumiItem>[]);
      }).catchError((Object _) {
        if (settled) return;
        pending--;
        if (pending == 0) finish(const <BangumiItem>[]);
      });
    }
    return completer.future;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final ScrollPosition position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      _loadMore();
    }
  }

  void _replaceItems(List<BangumiItem> items) {
    _items.clear();
    _itemIds.clear();
    for (final BangumiItem item in items) {
      if (_itemIds.add(item.id)) {
        _items.add(item);
      }
    }
  }

  bool _sameIds(List<BangumiItem> items, Set<int> ids) {
    if (items.length != ids.length) return false;
    for (final BangumiItem item in items) {
      if (!ids.contains(item.id)) return false;
    }
    return true;
  }

  int _currentStartOffset() {
    final int start = _offset - _pageSize;
    return start < 0 ? 0 : start;
  }

  int _nextRefreshOffset() {
    final int span = _refreshPageSpan * _pageSize;
    final int current = _currentStartOffset();
    int next = current;
    for (int i = 0; i < 6 && next == current; i++) {
      next = _random.nextInt(_refreshPageSpan) * _pageSize;
    }
    if (next == current) {
      next = (current + _pageSize) % span;
    }
    return next;
  }

  /// [startOffset] 为 0 表示首屏/回到第一页；下拉刷新会随机换一个起始页。
  Future<void> _load({int startOffset = 0}) async {
    final int generation = ++_generation;
    _prefetchedOffset = null;
    _prefetchedItems = const <BangumiItem>[];
    final Set<int>? previousIds =
        _items.isEmpty ? null : _items.map((item) => item.id).toSet();
    if (mounted) {
      setState(() {
        _loading = true;
        _loadingMore = false;
        _loadMoreFailed = false;
        _hasMore = true;
      });
    }

    // 首屏先用上次成功的缓存秒开，再走网络刷新（镜像延迟抖动大）。
    if (_items.isEmpty && startOffset == 0) {
      final cached = await BangumiApi.getBangumiMirrorPopularSubjects(
        limit: _pageSize,
        offset: 0,
        allowStale: true,
      );
      if (cached.isNotEmpty && mounted && generation == _generation) {
        setState(() {
          _replaceItems(cached);
          _offset = _pageSize;
          _hasMore = cached.length >= _pageSize;
          _loading = false;
        });
      }
    }

    List<BangumiItem> result = const <BangumiItem>[];
    int effectiveOffset = startOffset;
    try {
      result = await _fetch(limit: _pageSize, offset: startOffset);
      // 刷新到了靠后的页但内容不足（或空），退回第一页，避免刷新后列表变少。
      if (startOffset != 0 && result.length < _pageSize) {
        final List<BangumiItem> firstPage =
            await _fetch(limit: _pageSize, offset: 0);
        if (firstPage.isNotEmpty) {
          result = firstPage;
          effectiveOffset = 0;
        }
      }
    } catch (_) {
      // 网络失败时保留已有内容（缓存或上一次列表）。
    }

    // 下拉刷新时如果拿到的还是同一批内容，换几个起始页再试，确保推荐有变化。
    if (startOffset != 0 && previousIds != null && result.length >= _pageSize) {
      for (int attempt = 0;
          attempt < 3 && _sameIds(result, previousIds);
          attempt++) {
        final int alt = _random.nextInt(_refreshPageSpan) * _pageSize;
        if (alt == effectiveOffset) continue;
        try {
          final List<BangumiItem> altResult =
              await _fetch(limit: _pageSize, offset: alt);
          if (altResult.length >= _pageSize) {
            result = altResult;
            effectiveOffset = alt;
          }
        } catch (_) {
          // 忽略单次换页失败。
        }
      }
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      if (result.isNotEmpty) {
        _replaceItems(result);
        _offset = effectiveOffset + _pageSize;
        _hasMore = result.length >= _pageSize;
      }
      _loading = false;
    });
    if (result.isNotEmpty) {
      unawaited(_prefetchNextPage());
    }
  }

  /// 下拉刷新：随机换一页推荐内容。
  Future<void> _refresh() => _load(startOffset: _nextRefreshOffset());

  Future<void> _prefetchNextPage() async {
    if (_prefetching || !_hasMore) return;
    final int nextOffset = _offset;
    final int generation = _generation;
    _prefetching = true;
    try {
      final List<BangumiItem> items =
          await _fetch(limit: _pageSize, offset: nextOffset);
      if (generation != _generation) return;
      _prefetchedOffset = nextOffset;
      _prefetchedItems = items;
    } catch (_) {
      // 预取失败不影响正常加载。
    } finally {
      _prefetching = false;
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final int generation = _generation;
    final int nextOffset = _offset;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    List<BangumiItem> result;
    if (_prefetchedOffset == nextOffset && _prefetchedItems.isNotEmpty) {
      result = _prefetchedItems;
      _prefetchedOffset = null;
      _prefetchedItems = const <BangumiItem>[];
    } else {
      try {
        result = await _fetch(limit: _pageSize, offset: nextOffset);
      } catch (_) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _loadingMore = false;
          _loadMoreFailed = true;
        });
        return;
      }
    }
    if (!mounted || generation != _generation) return;

    final List<BangumiItem> fresh = <BangumiItem>[];
    for (final BangumiItem item in result) {
      if (_itemIds.add(item.id)) {
        fresh.add(item);
      }
    }
    setState(() {
      _items.addAll(fresh);
      _offset = nextOffset + _pageSize;
      _hasMore = result.length >= _pageSize && fresh.isNotEmpty;
      _loadingMore = false;
    });
    if (_hasMore) {
      unawaited(_prefetchNextPage());
    }
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
      onRefresh: _refresh,
      color: scheme.primary,
      child: CustomScrollView(
        controller: _scrollController,
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
          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
              ),
            ),
          if (_loadMoreFailed)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _loadMore,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('加载更多失败，点击重试'),
                  ),
                ),
              ),
            ),
          if (!_hasMore && _items.length > _pageSize)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    '已经到底了',
                    style: text.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
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
