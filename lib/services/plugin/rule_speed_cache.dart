import 'package:bealib/plugins/plugins.dart';

/// 规则测速结果（单个规则对某个关键词的一次检索）。
class RuleSpeedResult {
  const RuleSpeedResult({
    required this.pluginName,
    required this.elapsedMs,
    required this.resultCount,
    required this.finishedAt,
  });

  final String pluginName;
  final int elapsedMs;
  final int resultCount;
  final DateTime finishedAt;

  bool get hasResults => resultCount > 0;
}

/// 规则测速缓存。
///
/// 说明：不放进 MobX Store，避免为了一个跨页面只读缓存而触发代码生成。
/// 生命周期跟进程一致，按「关键词」缓存 [ttl] 时间，用于：
/// 1) 详情页规则列表按「有结果 + 更快」排序；
/// 2) 自动播放时选中最快规则（需求：自动使用速度最快规则，且不做自动切换）。
class RuleSpeedCache {
  RuleSpeedCache._();

  static final RuleSpeedCache instance = RuleSpeedCache._();

  static const Duration ttl = Duration(minutes: 10);

  final Map<String, Map<String, RuleSpeedResult>> _byKeyword = {};

  String _normalize(String keyword) => keyword.trim().toLowerCase();

  /// 记录一次检索耗时。
  void record({
    required String keyword,
    required Plugin plugin,
    required int elapsedMs,
    required int resultCount,
  }) {
    final String key = _normalize(keyword);
    if (key.isEmpty) return;
    final Map<String, RuleSpeedResult> bucket =
        _byKeyword.putIfAbsent(key, () => {});
    bucket[plugin.name] = RuleSpeedResult(
      pluginName: plugin.name,
      elapsedMs: elapsedMs,
      resultCount: resultCount,
      finishedAt: DateTime.now(),
    );
  }

  /// 取得某关键词下仍有效的测速结果，按「有结果优先、耗时升序」排序。
  List<RuleSpeedResult> ranked(String keyword) {
    final Map<String, RuleSpeedResult>? bucket =
        _byKeyword[_normalize(keyword)];
    if (bucket == null) return const [];
    final DateTime deadline = DateTime.now().subtract(ttl);
    bucket.removeWhere((_, result) => result.finishedAt.isBefore(deadline));
    final List<RuleSpeedResult> results = bucket.values.toList()
      ..sort((a, b) {
        if (a.hasResults != b.hasResults) return a.hasResults ? -1 : 1;
        return a.elapsedMs.compareTo(b.elapsedMs);
      });
    return results;
  }

  /// 最快且确有结果的规则名；没有可用结果时返回 null。
  String? fastest(String keyword) {
    for (final RuleSpeedResult result in ranked(keyword)) {
      if (result.hasResults) return result.pluginName;
    }
    return null;
  }

  int? elapsedFor(String keyword, String pluginName) =>
      _byKeyword[_normalize(keyword)]?[pluginName]?.elapsedMs;

  void clear() => _byKeyword.clear();
}
