import 'package:bealib/modules/bangumi/bangumi_item.dart';
import 'package:bealib/modules/roads/road_module.dart';
import 'package:bealib/modules/search/plugin_search_module.dart';
import 'package:bealib/plugins/plugins.dart';
import 'package:bealib/services/logging/logger.dart';
import 'package:bealib/services/plugin/rule_engine_models.dart';
import 'package:bealib/services/plugin/search_result_matcher.dart';
import 'package:bealib/services/plugin/rule_speed_cache.dart';

/// 一次规则检索的结果（含耗时，用于「默认选中速度最优规则」）。
class RuleProbe {
  RuleProbe(this.plugin);

  final Plugin plugin;
  SearchItem? item;

  /// 该规则返回的全部搜索结果（用于手动选择片源）。
  List<SearchItem> items = const <SearchItem>[];
  int elapsedMs = 0;
  bool noResult = false;
  String? error;

  bool get hasResult => item != null;
  bool get finished => hasResult || noResult || error != null;

  RuleProbe clone() {
    return RuleProbe(plugin)
      ..item = item
      ..items = items
      ..elapsedMs = elapsedMs
      ..noResult = noResult
      ..error = error;
  }
}

class _ProbeCache {
  _ProbeCache({required this.storedAt, required this.probes});

  final DateTime storedAt;
  final List<RuleProbe> probes;
}

class _RoadCache {
  _RoadCache({required this.storedAt, required this.roads});

  final DateTime storedAt;
  final List<Road> roads;
}

/// 规则解析器：并发检索全部规则、按「有结果 + 耗时升序」排序，
/// 并负责按需获取某条规则的播放线路。
///
/// 只在这一层做「自动选最快」；没有自动切换逻辑，规则切换必须由用户触发。
class RuleResolver {
  RuleResolver._();

  static const Duration probeTimeout = Duration(seconds: 15);

  /// 最近一次检索的探针列表（按最快在前排序，供规则下拉使用）。
  static final List<RuleProbe> lastProbes = <RuleProbe>[];
  static String lastKeyword = '';

  /// 最近一次检索对应的番剧（用于在搜索结果里挑出匹配项）。
  static BangumiItem? lastTarget;

  /// 关键词 -> 规则检索结果缓存（10 分钟内重复进入同一部番剧不再重新检索）。
  static final Map<String, _ProbeCache> _probeCache = <String, _ProbeCache>{};

  /// 规则 + 源地址 -> 播放线路缓存（10 分钟）。
  static final Map<String, _RoadCache> _roadCache = <String, _RoadCache>{};

  static const Duration _cacheTtl = Duration(minutes: 10);

  static RuleProbe? get fastest {
    for (final probe in lastProbes) {
      if (probe.hasResult) return probe;
    }
    return null;
  }

  static String resolveKeyword(String nameCn, String name) {
    final String cn = nameCn.trim();
    if (cn.isNotEmpty) return cn;
    return name.trim();
  }

  /// 并发检索全部规则并排序，返回最快的一条（无结果时返回 null）。
  ///
  /// 同一关键词 10 分钟内直接复用上次结果，避免每次进入番剧都全量测速。
  static Future<RuleProbe?> probeAll(
    List<Plugin> plugins,
    String keyword, {
    BangumiItem? target,
  }) async {
    lastKeyword = keyword;
    lastTarget = target;
    final String cacheKey = '${target?.id ?? 0}|$keyword';
    final cached = _probeCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.storedAt) <= _cacheTtl &&
        cached.probes.length == plugins.length &&
        cached.probes.every(
            (probe) => plugins.any((plugin) => plugin.name == probe.plugin.name))) {
      lastProbes
        ..clear()
        ..addAll(cached.probes.map((probe) => probe.clone()));
      _rank();
      return fastest;
    }
    lastProbes
      ..clear()
      ..addAll(plugins.map(RuleProbe.new));
    await Future.wait(lastProbes.map(_probeOne));
    _rank();
    _probeCache[cacheKey] = _ProbeCache(
      storedAt: DateTime.now(),
      probes: lastProbes.map((probe) => probe.clone()).toList(),
    );
    return fastest;
  }

  static Future<void> _probeOne(RuleProbe probe) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final response = await probe.plugin
          .queryBangumi(lastKeyword, shouldRethrow: true)
          .timeout(probeTimeout);
      probe.elapsedMs = stopwatch.elapsedMilliseconds;
      probe.items = response.data;
      probe.item = SearchResultMatcher.pickBest(
        response.data,
        keyword: lastKeyword,
        target: lastTarget,
      );
      probe.noResult = probe.item == null;
      if (probe.item != null) {
        RuleSpeedCache.instance.record(
          keyword: lastKeyword,
          plugin: probe.plugin,
          elapsedMs: probe.elapsedMs,
          resultCount: response.data.length,
        );
      }
    } on NoResultException {
      probe.elapsedMs = stopwatch.elapsedMilliseconds;
      probe.noResult = true;
    } on CaptchaRequiredException {
      probe.elapsedMs = stopwatch.elapsedMilliseconds;
      probe.error = '需要验证';
    } catch (error) {
      probe.elapsedMs = stopwatch.elapsedMilliseconds;
      probe.error = '检索失败';
      BealibLogger().w(
        'RuleResolver: probe failed (${probe.plugin.name})',
        error: error,
      );
    }
  }

  static void _rank() {
    lastProbes.sort((a, b) {
      if (a.hasResult != b.hasResult) return a.hasResult ? -1 : 1;
      return a.elapsedMs.compareTo(b.elapsedMs);
    });
  }

  /// 若该规则尚未成功检索过（例如用户切换到一个无结果的规则），补一次检索。
  static Future<void> ensureProbe(RuleProbe probe) async {
    if (probe.finished) return;
    await _probeOne(probe);
    _rank();
  }

  /// 获取某条规则的播放线路（10 分钟内缓存）。
  static Future<List<Road>> loadRoads(RuleProbe probe) async {
    final SearchItem? item = probe.item;
    if (item == null) return const <Road>[];
    final String key = '${probe.plugin.name}|${item.src}';
    final cached = _roadCache[key];
    if (cached != null &&
        DateTime.now().difference(cached.storedAt) <= _cacheTtl) {
      return cached.roads;
    }
    final roads = await probe.plugin.queryChapterRoads(item.src);
    _roadCache[key] = _RoadCache(storedAt: DateTime.now(), roads: roads);
    return roads;
  }
}
